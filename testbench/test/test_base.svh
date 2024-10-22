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
//  Description : Base test class for the DCACHE
// ----------------------------------------------------------------------------

`ifndef __test_base_SVH__
`define __test_base_SVH__

class test_base extends uvm_test;
  
  `uvm_component_utils(test_base)

  hpdcache_env #(NREQUESTERS)   env ;
  uvm_table_printer           printer ;

  // -------------------------------------------------------------------------
  // Virtual interfaces
  // -------------------------------------------------------------------------
  virtual xrtl_clock_vif      vif ;
  virtual conf_if             conf_vif ;
  virtual perf_if             perf_vif ;
  virtual dram_if             dram_vif ;

  virtual bp_vif  #( 1 )      m_read_bp_vif ; 
  virtual bp_vif  #( 1 )      m_write_req_bp_vif; 
  virtual bp_vif  #( 1 )      m_write_data_bp_vif; 


  virtual hwpf_stride_cfg_if  hwpf_stride_cfg_vif ;

  // --------------------------------------------------
  // This sequence needs to be overwritten in the test 
  // -------------------------------------------------
  hpdcache_base_sequence        base_sequence[NREQUESTERS]; 

  // Variable for the verification of the hwpf_stride
  logic [63:0]  base_addr [NUM_HW_PREFETCH] ;
  int unsigned cycle_before_abort [NUM_HW_PREFETCH];
  
  // -------------------------------------------------------------------------
  // Reset on the fly variables
  // -------------------------------------------------------------------------
  int unsigned  hit_reset     = 0 ;
  int unsigned  hit_reset_cnt = 0 ;
  int unsigned  nb_trans          ;
  int unsigned  reset_delay_ns    ;
  int unsigned  clk_cnt           ;
  int unsigned  num_txn           ;
  bit           start_bp_virtual_seq ;
  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);

    if (!$value$plusargs("NB_TXNS=%d", num_txn )) begin
      num_txn = 5000;
    end // if
    `uvm_info( get_full_name(), $sformatf("NUM_TXN=%0d", num_txn), UVM_HIGH );
    start_bp_virtual_seq = 1; 
  endfunction: new

  // -------------------------------------------------------------------------
  // Build phase
  // -------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    env     = hpdcache_env#(NREQUESTERS)::type_id::create("env", this);
    printer = new;

    printer.knobs.depth = 5;


    if(!uvm_config_db #( virtual perf_if )::get(null, "*", "PERF_IF" , perf_vif )) begin
      `uvm_error("NOVIF", {"Unable to get vif from perfiguration database for: ",
                  get_full_name( ), ".vif"})
    end
    if(!uvm_config_db#(virtual xrtl_clock_vif)::get(this, "", "clock_driver", vif)) begin
      `uvm_error("NOVIF", {"Unable to get vif from configuration database for: ",
                  get_full_name( ), ".vif"})
    end
    if(!uvm_config_db #( virtual conf_if )::get(null, "*", "CONF_IF" , conf_vif )) begin
      `uvm_error("NOVIF", {"Unable to get vif from configuration database for: ",
                  get_full_name( ), ".vif"})
    end
    if(!uvm_config_db #( virtual dram_if )::get(null, "*", "DRAM_IF" , dram_vif )) begin
      `uvm_error("NOVIF", {"Unable to get vif from dramiguration database for: ",
                  get_full_name( ), ".vif"})
    end

    if(!uvm_config_db #( virtual hwpf_stride_cfg_if )::get(null, "*", "PREFETCHER_IF" , hwpf_stride_cfg_vif) ) begin
      `uvm_error("NOVIF", {"Unable to get vif from dramiguration database for: ",
                  get_full_name( ), ".vif"})
    end


    if(!uvm_config_db #( virtual bp_vif #(1))::get(null, "*", "bp_read_agent", m_read_bp_vif)) begin
      `uvm_error("NOVIF", {"Unable to get vif from configuration database for: ",
                  get_full_name( ), ".vif"})
    end

    if(!uvm_config_db #( virtual bp_vif #(1))::get(null, "*", "bp_write_req_agent", m_write_req_bp_vif)) begin
      `uvm_error("NOVIF", {"Unable to get vif from configuration database for: ",
                  get_full_name( ), ".vif"})
    end

    if(!uvm_config_db #( virtual bp_vif #(1))::get(null, "*", "bp_write_data_agent", m_write_data_bp_vif)) begin
      `uvm_error("NOVIF", {"Unable to get vif from configuration database for: ",
                  get_full_name( ), ".vif"})
    end


    for (int i = 0; i < NREQUESTERS-1; i++) begin
      base_sequence[i] = hpdcache_base_sequence::type_id::create($sformatf("seq_%0d", i));
    end

    `uvm_info(get_full_name(), "Build phase complete", UVM_LOW)
  endfunction: build_phase

  // -------------------------------------------------------------------------
  // Connect phase
  // -------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    `uvm_info(get_full_name( ), "Connect phase complete.", UVM_LOW)
    env.m_hpdcache_sb.vif = vif;
  endfunction: connect_phase 

  // -------------------------------------------------------------------------
  // End of elaboration phase
  // -------------------------------------------------------------------------
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);

    `uvm_info(get_full_name(), "Entering end of elaboration", UVM_LOW)

    if( !env.m_top_cfg.randomize()) begin
      `uvm_error("End of elaboration", "Randomization of config failed");
    end

    if ( !env.m_hpdcache_conf.randomize() ) begin
      `uvm_error("End of elaboration", "Randomization of config failed");
    end
    env.m_hpdcache_conf.hpdcache_configuration_coverage.sample();
    // If the randomization is done the config phase, it doesn't work

    // -------------------------------------------------------------------------
    // Generate random configuration for memory resposne model
    // FIXME: temporarily all error insertion is disabled
    // -------------------------------------------------------------------------
    if ( !env.m_rsp_cfg.randomize() with
          {
            m_enable                   == 1'b1;
            insert_wr_error        == 1'b0; 
            insert_rd_error        == 1'b0; 
            insert_amo_wr_error        == 1'b0; 
            insert_amo_rd_error        == 1'b0; 
            insert_wr_exclusive_fail        == 1'b0; 
            insert_rd_exclusive_fail        == 1'b0; 
            unsolicited_rsp        == 1'b0; 

          } )
    begin    
      `uvm_error("End of elaboration", "Randomization of config failed");
    end

    `uvm_info("TEST BASE", $sformatf("Printing the mem rsp config:\n%s",
                                         env.m_rsp_cfg.convert2string()), UVM_HIGH)

    // -------------------------------------------------------------------------
    // Generate random memory partititons 
    // -------------------------------------------------------------------------
    if(!env.m_hpdcache_partitions.randomize() with { m_max_mem_size       == 64*HPDCACHE_CL_WIDTH ;
                                                   m_min_mem_size       == 32*HPDCACHE_CL_WIDTH  ;
                                                   m_max_partition_size == 8*HPDCACHE_CL_WIDTH  ;
                                                   m_min_partition_size == HPDCACHE_CL_WIDTH    ;
                                                   m_max_num_partition  == NUM_MEM_REGION      ; } ) begin
       `uvm_fatal( "RANDOMIZE_FAILED", "DCACHE PARTITION" );
    end
    `uvm_info(get_full_name(), $sformatf("Printing the test topology:\n%s",
                                         this.sprint(printer)), UVM_LOW)


    `uvm_info("TEST BASE", $sformatf("TOP CONFIGURATION %s", env.m_top_cfg.convert2string()), UVM_LOW)

    // Generating a random configuration for the hpdcache
    if ( env.m_hpdcache_conf.randomize() == 0 )
        $error("Error in randomizing the hpdcache configuration");


    // -----------------------------------
    // Configure pulse generator
    // --> it is used to generate a pulse for signal flush 
    // -----------------------------------
    env.m_flush_cfg.set_pulse_enable(env.m_top_cfg.m_flush_on_the_fly);
    env.m_flush_cfg.set_pulse_clock_based(1);
    env.m_flush_cfg.set_pulse_width(1);
    env.m_flush_cfg.set_pulse_period($urandom_range(1000, 4000));
    env.m_flush_cfg.set_pulse_phase_shift(0);
    env.m_flush_cfg.set_pulse_num(10);
    `uvm_info("TEST BASE", $sformatf("PULSE CONFIGURATION %s", env.m_flush_cfg.convert2string()), UVM_LOW)

    if(env.m_top_cfg.m_reset_on_the_fly == 1) env.reset_driver.set_num_reset( $urandom_range(1, 5));

  endfunction: end_of_elaboration_phase

  virtual task reset_phase(uvm_phase phase);
    super.reset_phase(phase);

    dram_vif.mem_req_read_ready_i       = 0 ;
    dram_vif.mem_resp_read_i            = 0 ;

    //      Write-buffer write interface
    dram_vif.mem_req_write_ready_i      = 0 ;
    dram_vif.mem_req_write_base_id_i    = 0 ;
    dram_vif.mem_req_write_data_ready_i = 0 ;
    dram_vif.mem_resp_write_valid_i     = 0 ;
    dram_vif.mem_resp_write_i           = 0 ;

    // Reset value for the hpdcache configuration
    conf_vif.cfg_enable_i                      = 'h0 ;
    conf_vif.cfg_wbuf_threshold_i              = 'h0 ;
    conf_vif.cfg_wbuf_reset_timecnt_on_write_i = 'h0 ;
    conf_vif.cfg_wbuf_sequential_waw_i         = 'h0 ;
    conf_vif.cfg_wbuf_inhibit_write_coalescing_i = 'h0;
    conf_vif.cfg_hwpf_stride_updt_plru_i       = 'h0 ;
    conf_vif.cfg_error_on_cacheable_amo_i      = 'h0 ;
    conf_vif.cfg_rtab_single_entry_i           = 'h0 ;
    conf_vif.cfg_default_wb_i                  = 'h0 ;

     // Reset value for the hwpf_strides configuration
     for ( int m = 0 ;  m < NUM_HW_PREFETCH ; m++ ) begin
       hwpf_stride_cfg_vif.base_set[m]     = 'h0 ;
       hwpf_stride_cfg_vif.param_set[m]    = 'h0 ;
       hwpf_stride_cfg_vif.throttle_set[m] = 'h0 ;

       hwpf_stride_cfg_vif.hwpf_stride_cfg[m].hw_prefetch_base     = 'h0 ;
       hwpf_stride_cfg_vif.hwpf_stride_cfg[m].hw_prefetch_param    = 'h0 ;
       hwpf_stride_cfg_vif.hwpf_stride_cfg[m].hw_prefetch_throttle = 'h0 ;
       hwpf_stride_cfg_vif.hwpf_stride_cfg[m].hw_prefetch_snoop    = 'h0 ;
     end

  endtask 

  virtual task configure_phase(uvm_phase phase);
    super.configure_phase(phase);
    `uvm_info("start configure phase", $sformatf("NUM PERFETCHER PREF %0d", NUM_HW_PREFETCH), UVM_LOW);

    phase.raise_objection(this, "Init Dcache Start");    

    conf_vif.cfg_enable_i                        = env.m_hpdcache_conf.m_cfg_enable;
    conf_vif.cfg_wbuf_threshold_i                = env.m_hpdcache_conf.m_cfg_wbuf_threshold;
    conf_vif.cfg_wbuf_reset_timecnt_on_write_i   = env.m_hpdcache_conf.m_cfg_wbuf_reset_timecnt_on_write;
    conf_vif.cfg_wbuf_sequential_waw_i           = env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw;
    conf_vif.cfg_wbuf_inhibit_write_coalescing_i = env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing;
    conf_vif.cfg_hwpf_stride_updt_plru_i         = env.m_hpdcache_conf.m_cfg_hwpf_stride_updt_plru;
    conf_vif.cfg_hwpf_stride_sid_i               = env.m_hpdcache_conf.m_cfg_hwpf_stride_sid;
    conf_vif.cfg_error_on_cacheable_amo_i        = env.m_hpdcache_conf.m_cfg_error_on_cacheable_amo;
    conf_vif.cfg_rtab_single_entry_i             = env.m_hpdcache_conf.m_cfg_rtab_single_entry;
    conf_vif.cfg_default_wb_i                    = env.m_hpdcache_conf.m_cfg_default_wb_i ;

    // Generating a random configuration for the hpdcache
    for ( int i = 0 ; i < NUM_HW_PREFETCH ; i++ ) begin
      generate_random_hwpf_stride_cfg ( i );

    end
 
    phase.drop_objection(this, "Init Dcache Stop");    
  endtask

  virtual task post_configure_phase(uvm_phase phase);
    super.post_configure_phase(phase); 
   
    phase.raise_objection(this, "Init Dcache Start");    
    vif.wait_n_clocks(128); 
    phase.drop_objection(this, "Init Dcache Stop");    

    `uvm_info(get_full_name(), "post configure phase complete", UVM_LOW)
  endtask

  // ----------------------------------------------------------
  // PRE MAIN PHASE 
  // ----------------------------------------------------------
  virtual task pre_main_phase(uvm_phase phase);

    for (int i = 0; i < NREQUESTERS-1; i++) begin
      base_sequence[i].m_hpdcache_partitions = env.m_hpdcache_partitions; 
      base_sequence[i].set_sid(i);
    end
    env.m_bp_read_vseq.which_bp            = env.m_top_cfg.m_read_bp_type;
    env.m_bp_write_req_vseq.which_bp       = env.m_top_cfg.m_write_req_bp_type;
    env.m_bp_write_data_vseq.which_bp      = env.m_top_cfg.m_write_data_bp_type;
  endtask
  // -------------------------------------------------------------------------
  // Run phase
  // -------------------------------------------------------------------------
  virtual task main_phase(uvm_phase phase);
    int eot_delay;
    phase.phase_done.set_drain_time(this, 1500);
    // Add delay
    phase.raise_objection(this, "Starting sequences");

    eot_delay = env.m_top_cfg.m_num_requesters*num_txn*200;
   // eot_delay = 100;
    // -------------------------------------
    // Create new sequence
    // start the base sequence here 
    // This base sequence needs to be overwritten in the test class 
    // --------------------------------------
    for (int i = 0; i < NREQUESTERS-1; i++) begin
      automatic int r = i;
      fork begin
        if(env.m_top_cfg.m_requester_enable[r]) begin
          `uvm_info("TEST BASE", "Start base sequence", UVM_LOW);
          base_sequence[r].start(env.m_hpdcache[r].m_sequencer);
        end
      end join_none
    end

    // start back pressure sequence(only once)
    if(start_bp_virtual_seq == 1) begin
      fork begin
        env.m_bp_read_vseq.start(null);
      end join_none
      fork begin
        env.m_bp_write_req_vseq.start(null);
      end join_none
      fork begin
        env.m_bp_write_data_vseq.start(null);
      end join_none
    end
    start_bp_virtual_seq = 0;
    // ------------------------
    // Assert reset  
    // ------------------------
    if(env.m_top_cfg.m_reset_on_the_fly == 1) begin
      fork 
       phase.raise_objection(this, "Start reset asertion");
       forever begin
         
         vif.wait_n_clocks(1); 
         clk_cnt++; 
         if(env.reset_driver.get_reset_on_the_fly_done == 1) begin

             `uvm_info("RESET ON THE FLY END", $sformatf("%0d(d), %0d(d)",env.m_hpdcache_sb.get_req_counter, nb_trans ), UVM_DEBUG);    
             phase.drop_objection(this, "Finish reset assertion");
             break;
         
         end

         `uvm_info("RESET ON THE FLY", $sformatf("%0d(d), %0d(d)",env.m_hpdcache_sb.get_req_counter, nb_trans ), UVM_DEBUG);
         
         if((env.m_hpdcache_sb.get_req_counter() == $urandom_range(num_txn/4, num_txn/2)) || (clk_cnt == 10000)) begin

           phase.drop_objection(this, "Assert reset");
           env.reset_driver.emit_assert_reset();

         end
       end
      join_none
    end

    vif.wait_n_clocks(eot_delay);

    phase.drop_objection(this, "Completed sequences");

    `uvm_info(get_full_name(), "Main phase complete", UVM_LOW)
  endtask: main_phase
  
  // -----------------------------------------------------------------------
  // Report phase
  // FIXEME: Performance counter do not seems to be working
  // -----------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);

    bit cov_write_miss;
    bit cov_read_miss;
    bit cov_uncached_req;
    bit cov_cmo_req;
    bit cov_write_req;
    bit cov_read_req;
    super.report_phase(phase); 

    cov_write_miss = 1; 
    cov_cmo_req    = 1;
    cov_write_req    = 1;
    cov_read_req    = 1;

 // -----------------------------------------------------------------------------------------------------------
 // No prediction for hit miss yet 
 //   check_perf_counter(perf_vif.cnt_cache_write_miss, env.m_hpdcache_sb.cnt_cache_write_miss , "WRITE MISS");
 //   ---------------------------------------------------------------------------------------------------------

//   check_perf_counter(perf_vif.cnt_cmo_req         , env.m_hpdcache_sb.cnt_cmo_req          , "CMO REQ");
//   check_perf_counter(perf_vif.cnt_write_req       , env.m_hpdcache_sb.cnt_write_req        , "WRITE REQ");

 // --------------------------------------------------------------------------------------------------------
 // RTL bug: #215667 (tuleap)
 // check_perf_counter(perf_vif.cnt_read_req        , env.m_hpdcache_sb.cnt_read_req         , "READ REQ");
 // check_perf_counter(perf_vif.cnt_cache_read_miss , env.m_hpdcache_sb.cnt_cache_read_miss  , "READ MISS");
 // check_perf_counter(perf_vif.cnt_uncached_req    , env.m_hpdcache_sb.cnt_uncached_req    , "UNCACHE REQ")
 // --------------------------------------------------------------------------------------------------------
 
//  check_perf_counter(perf_vif.cnt_granted_req    , env.m_hpdcache_sb.cnt_granted_req    , "GRANTED REQ");

 //   if(env.m_hpdcache_sb.cnt_cache_write_miss > 0 ) begin
 //     cov_write_miss = 0; 
 //     cnt_write_cov:cover(cov_write_miss);
 //   end
   // if(env.m_hpdcache_sb.cnt_cache_read_miss > 0 ) cnt_read_cov:cover(cov_read_miss);
   // if(env.m_hpdcache_sb.cnt_cache_read_miss > 0 ) cnt_read_cov:cover(cov_read_miss);
 //   if(env.m_hpdcache_sb.cnt_cmo_req > 0 ) begin
 //     cov_cmo_req = 0; 
 //     cnt_cmo_req_cov:cover(cov_cmo_req);
 //   end
 //   if(env.m_hpdcache_sb.cnt_write_req > 0 ) begin
 //     cov_write_req = 0; 
 //     cnt_write_req_cov:cover(cov_write_req);
 //   end
 //   if(env.m_hpdcache_sb.cnt_read_req > 0 ) begin
 //     cov_read_req = 0; 
 //     cnt_read_req_cov:cover(cov_read_req);
 //   end
  endfunction: report_phase

  function void check_perf_counter(int R, int E, string S);
    if(R != E) `uvm_error("TEST BASE", $sformatf("Performance Counter %0s, Received %0d(d) Expected %0d(d)", S, R, E))
    else       `uvm_info("TEST BASE", $sformatf("Performance Counter %0s, Received %0d(d) Expected %0d(d)", S, R, E), UVM_LOW)
  endfunction 
  // -------------------------------------------------------------------------
  // Generate_random_hwpf_stride_cfg function
  // Function in charge of generating a random configuration for the
  // hwpf_stride, concatenating the value into vector and drive the
  // configuration interface of the hwpf_stride
  // -------------------------------------------------------------------------
  task generate_random_hwpf_stride_cfg ( int i );
    logic [63:0]  base[NUM_HW_PREFETCH]     ;
    logic [63:0]  param[NUM_HW_PREFETCH]    ;
    logic [31:0]  throttle[NUM_HW_PREFETCH] ;

    // Randomizing a new configuration
    if (env.hwpf_stride_cfg.randomize() with { enable_bit == 'h1 ; } == 0)
      $error("Error in randomizing the hwpf_stride configuration");
   
    cycle_before_abort[i] = env.hwpf_stride_cfg.cycle_before_abort;
    // Storing the address to start the hwpf_stride in the tests
    base_addr[i] = { env.hwpf_stride_cfg.base_address, 6'h0 };

    // Concatenating the configuration in vector
    throttle[i] = { 
      env.hwpf_stride_cfg.ninflight ,
      env.hwpf_stride_cfg.nwait} ;

    param[i] = { 
      env.hwpf_stride_cfg.nblocks ,
      env.hwpf_stride_cfg.nlines  ,
      env.hwpf_stride_cfg.strides } ;

    base[i] = { 
      env.hwpf_stride_cfg.base_address ,
      2'b0 ,
      env.hwpf_stride_cfg.upstream_bit ,
      env.hwpf_stride_cfg.cycle_bit ,
      env.hwpf_stride_cfg.rearm_bit ,
      env.hwpf_stride_cfg.enable_bit } ;

    // Configuring the hwpf_stride 

    hwpf_stride_cfg_vif.base_set[i]                             <= 'h1         ;
    hwpf_stride_cfg_vif.hwpf_stride_cfg[i].hw_prefetch_base     <= (hwpf_stride_cfg_vif.hwpf_stride_status[32+i] == 0) ? base[i]
                                                                    : hwpf_stride_cfg_vif.hwpf_stride_cfg[i].hw_prefetch_base    ;
    hwpf_stride_cfg_vif.param_set[i]                            <= 'h1         ;
    hwpf_stride_cfg_vif.hwpf_stride_cfg[i].hw_prefetch_param    <= (hwpf_stride_cfg_vif.hwpf_stride_status[32+i] == 0) ? param[i]    
                                                                    : hwpf_stride_cfg_vif.hwpf_stride_cfg[i].hw_prefetch_param ;
    hwpf_stride_cfg_vif.throttle_set[i]                         <= 'h1         ;
    hwpf_stride_cfg_vif.hwpf_stride_cfg[i].hw_prefetch_throttle <= (hwpf_stride_cfg_vif.hwpf_stride_status[32+i] == 0) ? throttle[i] 
                                                                    : hwpf_stride_cfg_vif.hwpf_stride_cfg[i].hw_prefetch_throttle;

    // Check if the following line is still necessary
    hwpf_stride_cfg_vif.hwpf_stride_cfg[i].hw_prefetch_snoop    <= {NUM_HW_PREFETCH{1'b1}}   ;

    vif.wait_n_clocks(1);

    hwpf_stride_cfg_vif.base_set[i]     <= 'h0 ;
    hwpf_stride_cfg_vif.param_set[i]    <= 'h0 ;
    hwpf_stride_cfg_vif.throttle_set[i] <= 'h0 ;

    vif.wait_n_clocks(1);

  endtask

  // API to get the minumum of the numbers 
  function int unsigned get_min(int unsigned a, int unsigned b);
    int unsigned ret;

    ret = a;
    if (a > b) ret = b; 

    return ret; 
  endfunction 

endclass: test_base

`endif // __test_base_SVH__
