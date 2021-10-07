// ----------------------------------------------------------------------------
//Copyright 2024 CEA*
//*Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.
//[END OF HEADER]
// ----------------------------------------------------------------------------

class hpdcache_env#(int NREQUESTERS = 1) extends uvm_env;

  `uvm_component_param_utils(hpdcache_env#(NREQUESTERS));

  hpdcache_agent               m_hpdcache[NREQUESTERS];  // Active HPDCACHE agent
  hpdcache_conf_txn            m_hpdcache_conf;

  dram_mon_agent               m_dram_mon; 

  clock_driver_c               clock_driver;
  clock_config_c               clock_cfg;
  watchdog_c                   watchdog;
  reset_driver_c #(1'b1,50,0)  reset_driver;
  pulse_gen_driver             flush_driver; // 1 pulse for flush
  pulse_gen_cfg                m_flush_cfg; // 1 pulse for flush

  hpdcache_sb#(NREQUESTERS)    m_hpdcache_sb;
  
  hwpf_stride_cfg_c            hwpf_stride_cfg;
  // ----------------------------------------------
  // Memory partition 
  // Divides the memory in small partitions 
  // ----------------------------------------------
  memory_partitions_cfg        #(HPDCACHE_PA_WIDTH) m_hpdcache_partitions;

  // ----------------------------------------------
  // SB for the hwpf_stride 
  // This SB is independent of the SB of HPDCACHE 
  // ----------------------------------------------
  hwpf_stride_sb               #( NUM_HW_PREFETCH ) m_hwpf_stride_sb;

  // ----------------------------------------------
  // Memory response model 
  // The model accept the memory requests from the hpdcache
  // and reply to hpdcache 
  // ----------------------------------------------
  memory_response_model        #(HPDCACHE_PA_WIDTH, 
                                 HPDCACHE_MEM_DATA_WIDTH, 
                                 HPDCACHE_MEM_ID_WIDTH) m_mem_rsp_model;

  `ifdef AXI2MEM
    axi2mem #(HPDCACHE_PA_WIDTH, 
              HPDCACHE_MEM_DATA_WIDTH, 
              HPDCACHE_MEM_ID_WIDTH, 1) m_axi2mem_c_req;
 
    axi2mem #(HPDCACHE_PA_WIDTH, 
              HPDCACHE_MEM_DATA_WIDTH, 
              HPDCACHE_MEM_ID_WIDTH, 1) m_axi2mem_uc_req;
  `endif
  // ----------------------------------------------
  // This classe configures the memory response model 
  // Par ex: OUT OF ORDER responses, etc
  // ----------------------------------------------
  memory_rsp_cfg               m_rsp_cfg;

  // ----------------------------------------------
  // This classe configures the top of HPDCACHE
  // Par ex: requeters, etc
  // ----------------------------------------------
  hpdcache_top_cfg             m_top_cfg;

  bp_agent                     m_bp_read_agent;
  bp_virtual_sequence          m_bp_read_vseq; 
  bp_agent                     m_bp_write_req_agent;
  bp_virtual_sequence          m_bp_write_req_vseq; 
  bp_agent                     m_bp_write_data_agent;
  bp_virtual_sequence          m_bp_write_data_vseq; 

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  // -------------------------------------------------------------------------
  // Build phase
  // -------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
   
    for(int agent = 0; agent < NREQUESTERS; agent++) begin
      m_hpdcache[agent] = hpdcache_agent::type_id::create($sformatf("hpdcache_agent_%0d", agent), this);
      
      if ( agent != NREQUESTERS-1 ) m_hpdcache[agent].set_is_active();

      // -----------------------------------------------------------------
    end

    m_hpdcache_partitions  = memory_partitions_cfg#(HPDCACHE_PA_WIDTH)::type_id::create($sformatf("hpdcache_partitions"), this);
    clock_driver           = clock_driver_c::type_id::create("clock_driver", this );
    clock_cfg              = clock_config_c::type_id::create("clock_cfg", this );
    clock_driver.m_clk_cfg = clock_cfg;
    reset_driver           = reset_driver_c#( 1'b1,50,0 )::type_id::create("hpdcache_reset_driver", this );
    flush_driver           = pulse_gen_driver::type_id::create("hpdcache_flush_driver", this );
    m_flush_cfg            = pulse_gen_cfg::type_id::create("hpdcache_flush_cfg", this );
    watchdog               = watchdog_c::type_id::create("watchdog",this);
    m_hpdcache_conf        = hpdcache_conf_txn::type_id::create("hpdcache_conf_txn");
    m_top_cfg              = hpdcache_top_cfg::type_id::create("hpdcache_top_cfg");
    m_hpdcache_sb          = hpdcache_sb#(NREQUESTERS)::type_id::create("m_hpdcache_sb", this);
    m_hwpf_stride_sb       = hwpf_stride_sb#(NUM_HW_PREFETCH)::type_id::create("PREFETCHER_SB", this);
    m_mem_rsp_model        = memory_response_model #(HPDCACHE_PA_WIDTH, 
                                                     HPDCACHE_MEM_DATA_WIDTH, 
                                                     HPDCACHE_MEM_ID_WIDTH)::type_id::create("mem_rsp_model", this);

   `ifdef AXI2MEM
    m_axi2mem_c_req        = axi2mem #(HPDCACHE_PA_WIDTH, 
                                       HPDCACHE_MEM_DATA_WIDTH, 
                                       HPDCACHE_MEM_ID_WIDTH, 1)::type_id::create("axi2mem_c_req", this);

    m_axi2mem_uc_req       = axi2mem #(HPDCACHE_PA_WIDTH, 
                                   HPDCACHE_MEM_DATA_WIDTH, 
                                   HPDCACHE_MEM_ID_WIDTH, 1)::type_id::create("axi2mem_uc_req", this);
    `endif

    // Creating the configuration object
    hwpf_stride_cfg        = hwpf_stride_cfg_c::type_id::create("prefetch_config");
    m_rsp_cfg              = memory_rsp_cfg::type_id::create("memory_rsp_cfg");
    m_dram_mon             = dram_mon_agent::type_id::create("dram_mon_agent", this);
    m_bp_read_agent        = bp_agent::type_id::create("bp_read_agent", this );
    m_bp_read_vseq         = bp_virtual_sequence::type_id::create("bp_read_virtual_sequence", this);
    m_bp_write_data_agent  = bp_agent::type_id::create("bp_write_data_agent", this );
    m_bp_write_data_vseq   = bp_virtual_sequence::type_id::create("bp_write_data_virtual_sequence", this);
    m_bp_write_req_agent   = bp_agent::type_id::create("bp_write_req_agent", this );
    m_bp_write_req_vseq    = bp_virtual_sequence::type_id::create("bp_write_req_virtual_sequence", this);

    `uvm_info(get_full_name(), "Build phase complete", UVM_LOW)
  endfunction: build_phase
  
  // -------------------------------------------------------------------------
  // Connect phase
  // -------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // ---------------------------------
    // Connect Dcache monitor to SB
    // ---------------------------------
    for(int r = 0; r < NREQUESTERS; r ++) begin
      m_hpdcache[r].m_monitor.ap_hpdcache_req.connect(m_hpdcache_sb.af_hpdcache_req[r].analysis_export );
      m_hpdcache[r].m_monitor.ap_hpdcache_rsp.connect(m_hpdcache_sb.af_hpdcache_rsp[r].analysis_export );
    end

    m_hpdcache[NREQUESTERS-1].m_monitor.ap_hpdcache_req.connect(m_hwpf_stride_sb.m_af_hpdcache_req.analysis_export );
    m_hpdcache[NREQUESTERS-1].m_monitor.ap_hpdcache_rsp.connect(m_hwpf_stride_sb.m_af_hpdcache_rsp.analysis_export );

    // ---------------------------------
    // Connect mem monitor to SB
    // ---------------------------------
    m_dram_mon.m_monitor.ap_mem_miss_req.connect(m_hpdcache_sb.af_mem_req.analysis_export );
    m_dram_mon.m_monitor.ap_mem_miss_ext_req.connect(m_hpdcache_sb.af_mem_ext_req.analysis_export );
    m_dram_mon.m_monitor.ap_mem_read_rsp.connect(m_hpdcache_sb.af_mem_read_rsp.analysis_export );
    m_dram_mon.m_monitor.ap_mem_write_rsp.connect(m_hpdcache_sb.af_mem_write_rsp.analysis_export );

    m_mem_rsp_model.m_rsp_cfg     = m_rsp_cfg;
    m_hpdcache_sb.m_mem_rsp_model = m_mem_rsp_model;
    m_hpdcache_sb.m_hpdcache_conf = m_hpdcache_conf; 
    m_hpdcache_sb.m_top_cfg       = m_top_cfg;

    flush_driver.m_pulse_cfg      = m_flush_cfg;
    
    m_bp_read_vseq.set_bp_sequencer(m_bp_read_agent.m_sequencer);
    m_bp_read_vseq.set_bp_type(m_top_cfg.m_read_bp_type);
    m_bp_write_req_vseq.set_bp_sequencer(m_bp_write_req_agent.m_sequencer);
    m_bp_write_req_vseq.set_bp_type(m_top_cfg.m_write_req_bp_type);
    m_bp_write_data_vseq.set_bp_sequencer(m_bp_write_data_agent.m_sequencer);
    m_bp_write_data_vseq.set_bp_type(m_top_cfg.m_write_data_bp_type);

    `uvm_info(get_full_name( ), "Connect phase complete.", UVM_LOW)
  endfunction: connect_phase

  // -------------------------------------------------------------------------
  // End of elaboration phase
  // -------------------------------------------------------------------------
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    // configure clock with a frequency = 1 GHz    
    
    if (!clock_cfg.randomize() with {m_starting_signal_level == 0; m_clock_frequency == 1000; m_duty_cycle == 50;}) begin
      `uvm_error("End of elaboration", "Randomization failed");
    end

    
    `uvm_info(get_full_name( ), "End of elaboration phase complete.", UVM_LOW)
  endfunction: end_of_elaboration_phase

endclass : hpdcache_env

