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
//  Description : Prefetcher Scoreboard
// ----------------------------------------------------------------------------

// -----------------------------------------------------------------------
// Coverage covergroups
// -----------------------------------------------------------------------
// Prefetcher configuration coverage
covergroup hwpf_stride_cfg_cg (ref hwpf_stride_cfg_c packet);
  type_option.merge_instances = 1;
  option.get_inst_coverage = 1;
  option.per_instance = 1;

  cov_ninfligth: coverpoint packet.ninflight
  {
    bins zero  = {'h0};
    bins all[] = {['h1:'hfe]};
    bins one   = {'hff};
  }

  cov_nwait: coverpoint packet.nwait
  {
    bins zero    = {'h0};
    bins all[16] = {['h1:'hfffe]};
    bins one     = {'hffff};
  }

  cov_nlines: coverpoint packet.nlines
  {
    bins zero    = {'h0};
    bins all[16] = {['h1:'hfffe]};
    bins one     = {'hffff};
  }

  cov_nblocks : coverpoint packet.nblocks
  {
    bins all_low[]    = {['h0:'h1ff]};
    bins all_high[16] = {['h1000:'hfffe]};
    bins one          = {'hffff};
  }

  cov_strides : coverpoint packet.strides
  {
    bins zero    = {'h0};
    bins all[16] = {['h1:'hffff_fffe]};
    bins one     = {'hffff_ffff};
  }

  cov_base_address : coverpoint packet.base_address
  {
    bins zero    = {'h0};
    bins all[16] = {['h1:{58{1'b1}}-1]};
    bins one     = {{58{1'b1}}};
  }

  cov_en: coverpoint packet.enable_bit
  {
    bins is_disabled = {'h0};
    bins is_enabled  = {'h1};
  }

  cov_activation_mode: coverpoint { packet.cycle_bit , packet.rearm_bit }
  {
    bins disarm             = {'h0};
    bins cycle_and_disarm   = {'h1};
    bins rearm              = {'h2};
    bins cycle_and_rearm    = {'h3};
  }

endgroup : hwpf_stride_cfg_cg

// status configuration coverage
covergroup status_cg (ref status_c packet);
  type_option.merge_instances = 1;
  option.get_inst_coverage = 1;
  option.per_instance = 1;

  cov_status_enable : coverpoint packet.enable
  {
    bins all[NUM_HW_PREFETCH] = {['h0:{NUM_HW_PREFETCH{1'b1}}]};
  }

  cov_status_free_index : coverpoint packet.free_index
  {
    bins all[NUM_HW_PREFETCH] = {['h0:NUM_HW_PREFETCH-1]};
  }

  cov_status_free : coverpoint packet.free
  {
    bins working = {'h0};
    bins free    = {'h1};
  }

  cov_status_busy : coverpoint packet.busy
  {
    bins all[NUM_HW_PREFETCH] = {['h0:{NUM_HW_PREFETCH{1'b1}}]};
  }

endgroup : status_cg

class hwpf_stride_sb #( int NUM_HW_PREFETCH = 1 ) extends uvm_scoreboard;

  `uvm_component_param_utils ( hwpf_stride_sb#(NUM_HW_PREFETCH) )

  protected string name             ;
  event            reset_asserted   ;
  event            reset_deasserted ;

  // -----------------------------------------------------------------------
  // Analysis Ports
  // -----------------------------------------------------------------------
  uvm_tlm_analysis_fifo #(hpdcache_req_mon_t)  m_af_hpdcache_req;
  uvm_tlm_analysis_fifo #(hpdcache_rsp_t)      m_af_hpdcache_rsp;

  // -----------------------------------------------------------------------
  // Typedef
  // -----------------------------------------------------------------------
  typedef enum {
    DISARM ,
    CYCLE_AND_DISARM ,
    REARM  ,
    CYCLE_AND_REARM
  } mode_e;

  mode_e hwpf_stride_mode_type [4] = {DISARM, REARM, CYCLE_AND_DISARM, CYCLE_AND_REARM} ;

  // -----------------------------------------------------------------------
  // Performance Monitor
  // -----------------------------------------------------------------------
  perf_monitor_c  m_perf_monitor;
 
  // -----------------------------------------------------------------------
  // Dcache/DRAM  Request queue  
  // -----------------------------------------------------------------------
  hpdcache_req_mon_t    m_hpdcache_req[NUM_HW_PREFETCH][$];
  hpdcache_req_mon_t    m_hpdcache_rsp[NUM_HW_PREFETCH][$];
  bit                   m_first_match[NUM_HW_PREFETCH];

  // -----------------------------------------------------------------------
  // Prefetcher configuration
  // -----------------------------------------------------------------------
  hwpf_stride_cfg_c    m_hwpf_stride_cfg[NUM_HW_PREFETCH] ;
  status_c            m_status ;

  // -----------------------------------------------------------------------
  // Counters for the number of requests/responses analyzed by the scoreboard
  // -----------------------------------------------------------------------
  int unsigned m_hpdcache_req_counter = 0 ;
  int unsigned m_hpdcache_rsp_counter = 0 ;

  // -----------------------------------------------------------------------
  // Coverage covergroups
  // -----------------------------------------------------------------------
  hwpf_stride_cfg_cg    m_hwpf_stride_cfg_cg[NUM_HW_PREFETCH] ;
  status_cg            m_status_cg ;

  // Counter to check that the number of request for one burst corresponds to
  // the number of responses for the same burst
  int m_prefetch_inflight_counter[NUM_HW_PREFETCH];

  // Counter to check that at the end of a prefetch, the hwpf_stride waits
  // before disabling itself
  int m_prefetch_nwait_counter[NUM_HW_PREFETCH];

  // Counter to check if there are some abnormal error in the simulation
  int m_prefetch_error_counter[NUM_HW_PREFETCH];

  // Variable to store the last address of a prefetch, in case you need it for
  // a rearmed hwpf_stride that is starting again
  hpdcache_req_addr_t last_prefetch_base_addr[NUM_HW_PREFETCH] ;
  hpdcache_req_addr_t last_prefetch_end_addr[NUM_HW_PREFETCH]  ;
  mode_e            last_hwpf_stride_mode[NUM_HW_PREFETCH]    ;

  // Virtual interface
  virtual hwpf_stride_cfg_if   hwpf_stride_cfg_vif; 

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    this.name = name;

    // Creation of the covergroup for the configuration
    for ( int i = 0 ; i < NUM_HW_PREFETCH ; i++ ) begin
      m_hwpf_stride_cfg_cg[i] = new(m_hwpf_stride_cfg[i]);
    end

    // Creation of the covergroup for the status
    m_status_cg = new(m_status);

  endfunction: new

  // -------------------------------------------------------------------------
  // Build phase
  // -------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
   
    // Instantiation of the uvm_tlm_analysis_fifo
    m_af_hpdcache_req = new("m_af_hpdcache_req");
    m_af_hpdcache_rsp = new("m_af_hpdcache_rsp");

    // Instantiation of the transaction for the configuration coverage
    for ( int i = 0 ; i < NUM_HW_PREFETCH ; i++ ) begin
      m_hwpf_stride_cfg[i] = hwpf_stride_cfg_c::type_id::create($sformatf("hwpf_stride_cfg_%0d" , i ) , this );
    end

    // Instantiation of the transaction for the status coverage
    m_status = status_c::type_id::create("status", this);

    // Getting hte hwpf_stride configuration interface from the uvm_config_db
    if(!uvm_config_db #( virtual hwpf_stride_cfg_if )::get(null, "*", "PREFETCHER_IF" , hwpf_stride_cfg_vif) ) begin
        `uvm_error("NOVIF", {"Unable to get vif from dramiguration database for: ",
            get_full_name( ), ".vif"})
    end

    // Instance of the perf monitor
    m_perf_monitor = perf_monitor_c::type_id::create("m_perf_monitor", this );

    `uvm_info(this.name, "Build stage complete.", UVM_LOW)
  endfunction: build_phase

  // ------------------------------------------------------------------------
  // Pre reset phase
  // ------------------------------------------------------------------------
  virtual task pre_reset_phase(uvm_phase phase);
    -> reset_asserted;
    `uvm_info(this.name, "Pre Reset stage complete.", UVM_LOW)
  endtask : pre_reset_phase

  // ------------------------------------------------------------------------
  // Reset phase
  // ------------------------------------------------------------------------
  task reset_phase(uvm_phase phase );
    super.reset_phase(phase);

    if ( m_hpdcache_req_counter != m_hpdcache_rsp_counter)
        `uvm_info(this.name, $sformatf("Warning : Number of request not equal to the number of response. NB_REQ=%0d(d) NB_RSP=%0d(d)", m_hpdcache_req_counter, m_hpdcache_rsp_counter), UVM_NONE )

    m_hpdcache_req_counter  = 0;
    m_hpdcache_rsp_counter  = 0;

    for (int i = 0 ; i < NUM_HW_PREFETCH ; i++ ) begin
      last_prefetch_base_addr[i]  = 0      ;
      last_prefetch_end_addr[i]   = 0      ;
      last_hwpf_stride_mode[i]    = DISARM ;
      m_prefetch_error_counter[i] = 0      ;
      m_prefetch_nwait_counter[i] = 0      ;
    end

    m_af_hpdcache_req.flush();
    m_af_hpdcache_rsp.flush();

    m_perf_monitor.reset_open_transactions( );

    `uvm_info(this.name, "Reset stage complete.", UVM_LOW)
  endtask: reset_phase

  // ------------------------------------------------------------------------
  // Post reset phase
  // ------------------------------------------------------------------------
  virtual task post_reset_phase(uvm_phase phase);
    -> reset_deasserted;
    `uvm_info(this.name, "Post Reset stage complete.", UVM_LOW)
  endtask : post_reset_phase

  // -------------------------------------------------------------------------
  // Run phase
  // -------------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);

    super.run_phase(phase);

    forever begin
      @(reset_deasserted);
      // Loop to start a process for each hwpf_stride, to wait for a match to
      // start the checks
      for ( int i = 0 ; i < NUM_HW_PREFETCH ; i++) begin
        for ( int j = 0 ; j < NUM_HW_PREFETCH ; j++) begin
          automatic int r = i;
          automatic int k = j;
          fork
            wait_for_match( r, k );
          join_none
        end
      end

      // Start one process for each global task: getting the request, getting
      // the response, and checking the status
      fork
      //  check_status  ( phase );
        get_hpdcache_req( phase );
        get_hpdcache_rsp( phase );
      join_none

      // In case of a reset on the fly, kill all processes
      @(reset_asserted);
      disable fork;
    end

  endtask: run_phase

  // -----------------------------------------------------------------------
  // -----------------------------------------------------------------------
  // Global tasks:
  //
  // Getting hpdcache request and storing them in an associative array
  // Getting hpdcache response and storing them in an associative array
  // Snooping on each hwpf_stride to detect a match, and start the analysis of
  // the prefetch
  // Checking the configuration outputs of the hwpf_strides
  //
  // -----------------------------------------------------------------------
  // -----------------------------------------------------------------------

  // -------------------------------------------------------------------------
  // Task get_hpdcache_req
  // -------------------------------------------------------------------------
  virtual task get_hpdcache_req( uvm_phase phase );
    hpdcache_req_mon_t  hpdcache_req ;

    forever begin
      // Get the request from the uvm_tlm_analysis_fifo
      m_af_hpdcache_req.get(hpdcache_req);

      // If the transaction is not for this hwpf_stride, push the transaction
      // in a queue for the corresponding hwpf_stride, and get the next
      // transaction for this hwpf_stride in its specific queue
      m_hpdcache_req[hpdcache_req.tid].push_back( hpdcache_req );
      
      // Raise objection for each new request
      // phase.raise_objection( this );
      
    end // end forever

  endtask : get_hpdcache_req

  // -------------------------------------------------------------------------
  // Task get_hpdcache_rsp
  // -------------------------------------------------------------------------
  virtual task get_hpdcache_rsp( uvm_phase phase );
    hpdcache_rsp_t  hpdcache_rsp ;

    forever begin
      // Get the request from the uvm_tlm_analysis_fifo
      m_af_hpdcache_rsp.get(hpdcache_rsp);

      // If the transaction is not for this hwpf_stride, push the transaction
      // in a queue for the corresponding hwpf_stride, and get the next
      // transaction for this hwpf_stride in its specific queue
      m_hpdcache_rsp[hpdcache_rsp.tid].push_back( hpdcache_rsp );
      
      // Raise objection for each new request
      // phase.drop_objection( this );

    end // end forever

  endtask : get_hpdcache_rsp


  // -------------------------------------------------------------------------
  // Task wait_for_match
  // This task spy on on the snoop_match signal to detect a match. When
  // a match happens and the hwpf_stride is enable, the configuration of the 
  // concerned hwpf_stride is stored.
  // Some checks are made concerning the validity of the match, the activation
  // mode and the status of the hwpf_stride.
  // Then multiples processes are started to check the requests of the
  // hwpf_stride and the responses from the hpdcache.
  // -------------------------------------------------------------------------
  virtual task wait_for_match( int num_hwpf_stride, int num_snoop_port );
    // -------------------------------------------------------------------------
    // Variables for the task
    // -------------------------------------------------------------------------
    // Prefetcher configuration
    mode_e  hwpf_stride_mode ;
    // Variables to get the number of transaction of a burst of hwpf_strides
    int unsigned prefetch_lenght;

    m_first_match[num_hwpf_stride] = 0; 
    forever begin
      @(negedge hwpf_stride_cfg_vif.clk);
      // Check if there is a match happening for a specific hwpf_stride, which
      // should then be starting
      wait( hwpf_stride_cfg_vif.hwpf_stride_status[32+num_hwpf_stride] == 0);
      if ( ( hwpf_stride_cfg_vif.snoop_valid[num_snoop_port]    == 1 ) && 
           ( hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[0] == 1 ) && 
           ( ((m_first_match[num_hwpf_stride] == 0 ) && ( hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[HPDCACHE_OFFSET_WIDTH +: HPDCACHE_NLINE_WIDTH] == hwpf_stride_cfg_vif.snoop_addr[num_snoop_port] ) )|| ( (m_first_match[num_hwpf_stride] == 1 ) && 
             (( hwpf_stride_cfg_vif.snoop_addr[num_snoop_port] == last_prefetch_end_addr[num_hwpf_stride] ) ||
             ( hwpf_stride_cfg_vif.snoop_addr[num_snoop_port] == last_prefetch_base_addr[num_hwpf_stride][42:0] ) ) ) )
         ) begin
        // -------------------------------------------------------------------------
        // Getting the configuration of the hwpf_stride when the match happens
        // -------------------------------------------------------------------------
        // Base
        m_hwpf_stride_cfg[num_hwpf_stride].base_address = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[HPDCACHE_OFFSET_WIDTH +: HPDCACHE_NLINE_WIDTH]   ;
        m_hwpf_stride_cfg[num_hwpf_stride].cycle_bit    = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[2]      ;
        m_hwpf_stride_cfg[num_hwpf_stride].rearm_bit    = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[1]      ;
        m_hwpf_stride_cfg[num_hwpf_stride].enable_bit   = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[0]      ;
        // Param
        m_hwpf_stride_cfg[num_hwpf_stride].strides      = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_param[31:0]  ;
        m_hwpf_stride_cfg[num_hwpf_stride].nlines       = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_param[47:32] ;
        m_hwpf_stride_cfg[num_hwpf_stride].nblocks      = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_param[63:48] ;
        // Throttle
        m_hwpf_stride_cfg[num_hwpf_stride].nwait        = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_throttle[15:0] ;
        m_hwpf_stride_cfg[num_hwpf_stride].ninflight    = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_throttle[31:16] ;

        m_status.enable     = hwpf_stride_cfg_vif.hwpf_stride_status[15:0]  ;
        m_status.free_index = hwpf_stride_cfg_vif.hwpf_stride_status[19:16] ;
        m_status.free       = hwpf_stride_cfg_vif.hwpf_stride_status[31]    ;
        m_status.busy       = hwpf_stride_cfg_vif.hwpf_stride_status[47:32] ;

        // Sampling the configuration
        m_hwpf_stride_cfg_cg[num_hwpf_stride].sample();
        m_status_cg.sample();

        // If loop to manage the case where the hwpf_stride was already started
        // previously in REARM mode in the simulation. In this case, the
        // prefetcehr is starting from the last address if the last prefetch,
        // not from the base_address
        if ( last_hwpf_stride_mode[num_hwpf_stride] == REARM ) begin
          m_first_match[num_hwpf_stride] = 1;
          if ( hwpf_stride_cfg_vif.snoop_addr[num_snoop_port] == last_prefetch_end_addr[num_hwpf_stride] ) begin
            m_hwpf_stride_cfg[num_hwpf_stride].base_address = last_prefetch_end_addr[num_hwpf_stride] ;
            `uvm_info(this.name,
              $sformatf("PREFETCHER_%0d ; DETECTING A PREFETECHER WITH ACTIVATION_MODE=%0p(p) THAT IS RESTARTING",
                num_hwpf_stride,
                last_hwpf_stride_mode[num_hwpf_stride]),
              UVM_DEBUG)
          end
        end
        if ( last_hwpf_stride_mode[num_hwpf_stride] == CYCLE_AND_REARM ) begin
          if ( hwpf_stride_cfg_vif.snoop_addr[num_snoop_port] == last_prefetch_base_addr[num_hwpf_stride][42:0] ) begin
            m_hwpf_stride_cfg[num_hwpf_stride].base_address = hwpf_stride_cfg_vif.snoop_addr[num_snoop_port] ;
            `uvm_info(this.name,
              $sformatf("PREFETCHER_%0d ; DETECTING A PREFETECHER WITH ACTIVATION_MODE=%0p(p) THAT IS RESTARTING",
                num_hwpf_stride,
                last_hwpf_stride_mode[num_hwpf_stride]),
              UVM_DEBUG)
          end
        end

        // Check that the match is occuring on the base_address
        if ( m_hwpf_stride_cfg[num_hwpf_stride].base_address[42:0] != hwpf_stride_cfg_vif.snoop_addr[num_snoop_port] ) begin
          `uvm_error(this.name, 
            $sformatf("The match is occuring on the wrong address; PREFETCHER_%0d CFG_BASE_ADDRESS=%0x(x), SNOOP_ADDR=%0x(x)",
              num_hwpf_stride,
              m_hwpf_stride_cfg[num_hwpf_stride].base_address[42:0], 
              hwpf_stride_cfg_vif.snoop_addr[num_snoop_port]) );
        end

        // Check if the match is occurring while the hwpf_stride is busy
        if ( hwpf_stride_cfg_vif.hwpf_stride_status[32+num_hwpf_stride] == 1 ) begin
          `uvm_error(this.name, $sformatf("PREFETCHER_%0d IS BUSY WHEN THERE IS A MATCH", num_hwpf_stride) );
        end

        // Calculate the number of transaction that should be sent by the
        // hwpf_stride for this match
        prefetch_lenght = ( m_hwpf_stride_cfg[num_hwpf_stride].nblocks + 1 ) * ( m_hwpf_stride_cfg[num_hwpf_stride].nlines + 1 ) - 1 ;

        // Determine the activation policy of the hwpf_stride
        hwpf_stride_mode = hwpf_stride_mode_type[{m_hwpf_stride_cfg[num_hwpf_stride].cycle_bit, m_hwpf_stride_cfg[num_hwpf_stride].rearm_bit}];
        last_hwpf_stride_mode[num_hwpf_stride] = hwpf_stride_mode ;
        last_prefetch_base_addr[num_hwpf_stride] = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[HPDCACHE_OFFSET_WIDTH +: HPDCACHE_NLINE_WIDTH] ;

        // Just a useful message for the debug to check if the hwpf_stride has
        // started in the simulation, and if yes, the length of the prefetch
        // burst
        `uvm_info(this.name,
          $sformatf("PREFETCHER_%0d ; Match is happening with the following configuration: nblocks=%0x(x), nlines=%0x(x), stride=%0x(x), base_address=%0x(x), base_address_match=%0h(h), nwait=%0h(h), ninflight=%0h(h). The number of requests to be sent is %0d(d). The activation policy is %0p(p).",
            num_hwpf_stride,
            m_hwpf_stride_cfg[num_hwpf_stride].nblocks,
            m_hwpf_stride_cfg[num_hwpf_stride].nlines,
            m_hwpf_stride_cfg[num_hwpf_stride].strides,
            hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[63:6],
            hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[HPDCACHE_OFFSET_WIDTH +: HPDCACHE_NLINE_WIDTH],
            m_hwpf_stride_cfg[num_hwpf_stride].nwait,
            m_hwpf_stride_cfg[num_hwpf_stride].ninflight,
            prefetch_lenght,
            hwpf_stride_mode),
          UVM_NONE)

          // Starting all the processes to check the requests, the responses
          // and the configuration during a prefetch
        fork begin
          fork
            analyze_hwpf_stride_req( num_hwpf_stride, m_hwpf_stride_cfg[num_hwpf_stride] );
            analyze_hwpf_stride_rsp( num_hwpf_stride, m_hwpf_stride_cfg[num_hwpf_stride] );
            check_cfg( num_hwpf_stride, prefetch_lenght, hwpf_stride_mode );
          join_none // fork

          @(negedge hwpf_stride_cfg_vif.clk);

          // While a prefetch is in progress, snoop on the enable signal to
          // detect an abortion. If the hwpf_stride is disabled, the precedent
          // process will be disabled, and the verification for the current
          // prefetch will end, then back to the wait for the next match.
          while ( hwpf_stride_cfg_vif.hwpf_stride_status[32+num_hwpf_stride] != 0 ) begin
            if ( ( hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[0] == 0 ) ) begin
              // Sampling the configuration to get the disabled hwpf_stride in
              // the coverage
              m_hwpf_stride_cfg[num_hwpf_stride].enable_bit = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[0] ;
              m_hwpf_stride_cfg_cg[num_hwpf_stride].sample();

              // Waiting for the hwpf_stride to process its infligth
              // transaction and disabling itself before killing the processes
              wait ( hwpf_stride_cfg_vif.hwpf_stride_status[32+num_hwpf_stride] == 0 );
              `uvm_info(this.name, $sformatf("DISABLING THE FORK PREFETCHER_%0d", num_hwpf_stride), UVM_LOW)

              // Reinitialise these counter to avoid problem for these
              // verification in the case of an abortion
              m_prefetch_nwait_counter[num_hwpf_stride] = 0 ;
              m_prefetch_error_counter[num_hwpf_stride] = 0 ;
              last_prefetch_base_addr[num_hwpf_stride]  = 0 ;
              last_prefetch_end_addr[num_hwpf_stride]   = 0 ;
              // Disabling the process for the precedent fork
              disable fork;
            end else begin
              @(negedge hwpf_stride_cfg_vif.clk);
            end
          end

        end join

        `uvm_info(this.name, $sformatf("END OF MATCH FOR PREFETCHER_%0d", num_hwpf_stride), UVM_NONE)

      end // end if
    end // end forever

  endtask

  // -------------------------------------------------------------------------
  // Task check_status
  // Task which check that the status output of the hwpf_strides is coherent
  // -------------------------------------------------------------------------
  virtual task check_status( uvm_phase phase );
    logic                       free       ;
    logic [3:0]                 free_index ;
    logic [NUM_HW_PREFETCH-1:0] busy       ;
    logic [NUM_HW_PREFETCH-1:0] enables    ;

    logic flag_error_index ;

    forever begin
      @(negedge hwpf_stride_cfg_vif.clk);
      
      // Get the current status of the hwpf_stride
      busy       = hwpf_stride_cfg_vif.hwpf_stride_status[47:32] ;
      free       = hwpf_stride_cfg_vif.hwpf_stride_status[31]    ;
      free_index = hwpf_stride_cfg_vif.hwpf_stride_status[19:16] ;
      enables    = hwpf_stride_cfg_vif.hwpf_stride_status[16:0]  ;

      // Check of the enables bits
      for ( int i = 0 ; i < NUM_HW_PREFETCH ; i++ ) begin
        if ( enables[i] != hwpf_stride_cfg_vif.hwpf_stride_cfg[i].hw_prefetch_base[0] ) begin
          `uvm_error(this.name, 
            $sformatf("ERROR STATUS ENABLES ; ENABLE_STATUS[%0d]=%0x(x) ; ENABLE_CFG[%0d]=%0x(x)",
              i,
              enables[i],
              i,
              hwpf_stride_cfg_vif.hwpf_stride_cfg[i].hw_prefetch_base[0]) );
        end
      end

      // Check of the free bit
      if ( free != !( &( busy | enables ) ) ) begin
        `uvm_error(this.name, 
          $sformatf("ERROR STATUS ; FREE=%0x(x) ; PREFETCH_BUSY=%0x(x) ; PREFETCH_ENABLE=%0x(x)",
            free,
            busy,
            enables) );
      end

      flag_error_index = 0 ;
      // Check the free_index value depending of the hwpf_strides busy/enable
      // status
      for ( int i = 0 ; i < NUM_HW_PREFETCH ; i++ ) begin
        if ( ( !busy[i] && !enables[i] ) ) begin
          flag_error_index = ( free_index != i );
          break;
        end
      end

      // Print the error if there was one
      if (flag_error_index) begin
        `uvm_error(this.name, 
          $sformatf("ERROR FREE_INDEX ; BUSY=%0x(x) ; ENABLES=%0x(x); FREE_INDEX=%0d(d)",
            busy,
            enables,
            free_index) );
      end

      // Loop to decrement the nwait counter
      for ( int i = 0 ; i < NUM_HW_PREFETCH ; i++ ) begin
        if ( m_prefetch_nwait_counter[i] > 0 ) begin
          m_prefetch_nwait_counter[i]--;
          if ( hwpf_stride_cfg_vif.hwpf_stride_status[32+i] == 0 ) begin
            `uvm_error(this.name, 
              $sformatf("ERROR PREFETCHER BUSY DURING PREFETCH; PREFETCHER_%0d ; PREFETCHER_STATUS[%0d]=%0x(x)", 
                i, 
                32+i,
                hwpf_stride_cfg_vif.hwpf_stride_status[32+i]) );
          end // if
        end
      end
    end // end forever

  endtask

  // -----------------------------------------------------------------------
  // -----------------------------------------------------------------------
  // Verification task
  //  Check the prefetching requests for a match
  //  Check the number of responses and the activation policy for a match
  // -----------------------------------------------------------------------
  // -----------------------------------------------------------------------

  // -------------------------------------------------------------------------
  // Task analyze_hwpf_stride_req
  // -------------------------------------------------------------------------
  virtual task analyze_hwpf_stride_req
  ( 
    int               num_hwpf_stride    ,
    hwpf_stride_cfg_c  hwpf_stride_cfg_task
  );
    // -------------------------------------------------------------------------
    // Variables for the task
    // -------------------------------------------------------------------------
    // Verification variables
    hpdcache_req_mon_t  hpdcache_req ;

    // Variables to get the number of transaction of a burst of hwpf_strides
    // and to check the address of each request of a prefetch burst
    int                nblocks_counter ; // counter of the number of block hwpf_strided
    hpdcache_req_addr_t  req_addr        ; // Address of the hwpf_stride request
    hpdcache_req_addr_t  end_addr        ; // Last address of a prefetch

    // Variable to check the nwait feature
    time  current_req_time ; // Timestamp of the current hwpf_stride request
    time  last_req_time    ; // Timestamp of the last hwpf_stride request to compare with the current one

    // Variable to check the uncacheable field of the requests
    hpdcache_req_addr_t                  masked_addr        ;

    // Variable to store the value from the configuration interface
    hpdcache_nline_t                          base_address      ;
    logic [31:0]                              strides           ;
    logic [15:0]                              nblocks           ;
    logic [15:0]                              nlines            ;
    logic [15:0]                              nwait             ;
    logic [15:0]                              ninflight         ;
    logic [$clog2(HPDCACHE_CL_WIDTH/8) -1:0]  offset           ;

    base_address      = hwpf_stride_cfg_task.base_address      ;
    strides           = hwpf_stride_cfg_task.strides           ;
    nblocks           = hwpf_stride_cfg_task.nblocks           ;
    nlines            = hwpf_stride_cfg_task.nlines            ;
    nwait             = hwpf_stride_cfg_task.nwait             ;
    ninflight         = hwpf_stride_cfg_task.ninflight         ;

    `uvm_info(this.name,
              $sformatf("TASK ANALYZE_PREFETCHER_REQ STARTING FOR PREFETCHER_%0d", num_hwpf_stride),
              UVM_LOW )

    // Initializing some values for the verification
    offset          = 'h0;
    req_addr        = { base_address , offset} ; // first address of the prefetch
    nblocks_counter = 0                       ; // counter of block hwpf_strided to calculate the address of the request
    last_req_time   = 0ns                     ;

    // Reset the inflight counter before the start of the prefetch
    m_prefetch_inflight_counter[num_hwpf_stride] = 0 ;

    // -------------------------------------------------------------------------
    // Loop to get each requests of a prefetch burst and to check them
    // -------------------------------------------------------------------------
    for ( int block = 0 ; block < nblocks + 1 ; block++ ) begin

      // Calculate the address of the current block with the number of block
      // and the stride
      req_addr = ( base_address + ( block * ( strides + 1 ) ) ) * (HPDCACHE_CL_WIDTH/8) ;

      for ( int line = 0 ; line < ( nlines + 1 ) ; line++ ) begin

        if ( ( block == 0 ) && ( line == 0 ) ) begin
          req_addr += (HPDCACHE_CL_WIDTH/8) ;
          continue;
        end

        // Waiting for the get_hpdcache_req task to get/ store a request for this
        // hwpf_stride in the associative array before analyzing it
        // ( synchronization mechanism between the forked tasks )
        wait ( m_hpdcache_req[num_hwpf_stride].size() != 0 );
        hpdcache_req = m_hpdcache_req[num_hwpf_stride].pop_front();

        // --------------------------------------------------------------------
        // Verification of the address of the current request
        // --------------------------------------------------------------------

        // Checking that the address from the hwpf_stride corresponds to its
        // theoritical one
        if ( req_addr != hpdcache_req.addr ) begin
          `uvm_error(this.name, 
            $sformatf("WRONG ADDR ; PREFETCHER_%0d ; block=%0d(d) ; line=%0d(d), PREFETCH_REQ_ADDR=%0x(x), THEORITICAL_ADDR=%0x(x)", 
              num_hwpf_stride,
              block,
              line,
              hpdcache_req.addr,
              req_addr) );
        end

        // For each iteration, increment the address for a new line
        if ( ( nlines != 0 ) || ( line != 0 ) ) begin
          req_addr += (HPDCACHE_CL_WIDTH/8) ;
        end

        // --------------------------------------------------------------------
        // Verification of the delay between two request for the Nwait feature
        // --------------------------------------------------------------------

        // Check that the delay between two requests of the same hwpf_stride is
        // not inferior to the nwait parameter
        current_req_time = $time ; 
        if ( ( ( current_req_time - last_req_time ) < ( nwait * 1ns ) ) && ( ( block != 0 ) && ( line != 0 ) ) ) begin // Only work if the frequency is of 1 GHz
          `uvm_error(this.name, 
            $sformatf("ERROR IN THE DELAY BETWEEN TWO REQUEST ; PREFETCHER_%0d ; nwait=%0t(t), delay=%0t(t)", 
              num_hwpf_stride,
              nwait * 1ns,
              current_req_time - last_req_time ) );
        end
        // Store the timestamp of the current request in the last_req_time for
        // the next iteration verification
        last_req_time = current_req_time;

        // --------------------------------------------------------------------
        // Verification of the number of outstanding request for the Ninfligth
        // feature
        // --------------------------------------------------------------------

        // Check that the number of inflight request doesn't exceed the maximu 
        // number of inflight request of the configuration
        if ( ninflight != 0 ) begin // case of unlimited number of inflight transaction
          if ( m_prefetch_inflight_counter[num_hwpf_stride] > ninflight ) begin
            `uvm_error(this.name, 
              $sformatf("EXCEEDING THE MAX NUMBER OF INFLIGHT REQUEST ; PREFETCHER_%0d ; INFLIGHT_COUNTER=%0d(d)", 
                num_hwpf_stride, 
                m_prefetch_inflight_counter[num_hwpf_stride] ) );
          end
        end

        // --------------------------------------------------------------------
        // Ending the loop
        // --------------------------------------------------------------------

        // Recording the transaction in the performance monitor
        m_perf_monitor.register_source_event(
          (HPDCACHE_CL_WIDTH/8),
          $sformatf("PREFETCHER_%0d_REQ", num_hwpf_stride),
          $time,
          $sformatf("PREFETCH_%0d_%0d_%0d", num_hwpf_stride, block, line));

        // Increment the counters
        m_hpdcache_req_counter++;
        m_prefetch_inflight_counter[num_hwpf_stride]++;

      end // end for line
    end // end for block

    // Initializing the counter for end of prefetch nwait verification
    m_prefetch_nwait_counter[num_hwpf_stride] = nwait ;

    // --------------------------------------------------------------------
    // Verification of the last address of the prefetch operation
    // --------------------------------------------------------------------
    if (nlines != 0 ) begin
      end_addr = ( base_address + ( ( nlines + 1 ) + ( nblocks * ( strides + 1 ) ) ) - 1 )  * (HPDCACHE_CL_WIDTH/8) ;
    end else begin
      end_addr = ( base_address + ( ( nblocks ) * ( strides + 1 ) + 1 ) - 1 ) * (HPDCACHE_CL_WIDTH/8) ;
    end

    // Comparing the theoritical last address with the actual one to determine
    // if there is an error
    if ( end_addr != hpdcache_req.addr ) begin
      `uvm_error(this.name, 
        $sformatf("WRONG LAST ADDRESS ; PREFETCHER_%0d ; PREFETCH_LAST_REQ_ADDR=%0x(x), CONFIGURATION_LAST_ADDR=%0x(x)", 
          num_hwpf_stride, 
          hpdcache_req.addr,
          end_addr) );
    end

  endtask : analyze_hwpf_stride_req

  // -------------------------------------------------------------------------
  // Collect store response sent by the HPDCACHE
  // -------------------------------------------------------------------------
  virtual task analyze_hwpf_stride_rsp
  ( 
    int               num_hwpf_stride  ,
    hwpf_stride_cfg_c  hwpf_stride_cfg_task
  );
    // -------------------------------------------------------------------------
    // Variables for the task
    // -------------------------------------------------------------------------
    // Verification variables
    hpdcache_rsp_t      hpdcache_rsp ;
    hpdcache_req_addr_t end_addr   ;
    hpdcache_req_addr_t snoop_addr ;

    // Activation policy
    mode_e hwpf_stride_mode ;

    // Variable to store the value from the configuration interface
    hpdcache_nline_t  base_address ;
    logic [31:0]    strides      ;
    logic [15:0]    nblocks      ;
    logic [15:0]    nlines       ;
    logic           rearm_bit    ;
    logic           cycle_bit    ;

    base_address = hwpf_stride_cfg_task.base_address ;
    strides      = hwpf_stride_cfg_task.strides      ;
    nblocks      = hwpf_stride_cfg_task.nblocks      ;
    nlines       = hwpf_stride_cfg_task.nlines       ;
    rearm_bit    = hwpf_stride_cfg_task.rearm_bit    ;
    cycle_bit    = hwpf_stride_cfg_task.cycle_bit    ;

    `uvm_info(this.name,
              $sformatf("TASK ANALYZE_PREFETCHER_RSP STARTING FOR PREFETCHER_%0d", num_hwpf_stride),
              UVM_LOW )

    // -------------------------------------------------------------------------
    // Loop to get all responses for this hwpf_stride, just for the performance
    // measure
    // -------------------------------------------------------------------------
    for ( int block = 0 ; block < nblocks + 1 ; block++ ) begin
      for ( int line = 0 ; line < ( nlines + 1 ) ; line++ ) begin

        // Ignoring the first block/ first line of the prefetch
        if ( ( block == 0 ) && ( line == 0 ) ) begin
          continue;
        end

        // Waiting for the get_hpdcache_rsp task to get/store a response for this
        // hwpf_stride in the associative array before analyzing it
        // ( synchronization mechanism between the forked tasks )
        wait ( m_hpdcache_rsp[num_hwpf_stride].size() != 0 );
        hpdcache_rsp = m_hpdcache_rsp[num_hwpf_stride].pop_front();

        // Checking that until the end of the prefetch, the hwpf_stride stays
        // busy
        if ( hwpf_stride_cfg_vif.hwpf_stride_status[32+num_hwpf_stride] == 0 ) begin
          `uvm_error(this.name, 
            $sformatf("ERROR PREFETCHER BUSY DURING PREFETCH; PREFETCHER_%0d ; PREFETCHER_STATUS[%0d]=%0x(x)", 
              num_hwpf_stride, 
              32+num_hwpf_stride,
              hwpf_stride_cfg_vif.hwpf_stride_status[32+num_hwpf_stride]) );
        end

        // Decrementing the counter for normal error
        if ( hpdcache_rsp.error ) begin
          m_prefetch_error_counter[num_hwpf_stride]--;
          `uvm_info(this.name,
                $sformatf("PREFETCHER_%0d Error=%0x(x) Number_error=%0d(d)", num_hwpf_stride, hpdcache_rsp.error, m_prefetch_error_counter[num_hwpf_stride] ),
                UVM_DEBUG )
        end

        // Recording the transaction in the performance monitor
        m_perf_monitor.register_dest_event(
          0,
          $sformatf("PREFETCHER_%0d_RSP", num_hwpf_stride),
          $time,
          $sformatf("PREFETCH_%0d_%0d_%0d", num_hwpf_stride, block, line));

        // Increment the counters
        m_hpdcache_rsp_counter++;
        m_prefetch_inflight_counter[num_hwpf_stride]--;

      end // end for line
    end // end for block

    // -------------------------------------------------------------------------
    // End of prefetch verification
    // Checking that the number of responses corresponds to the number of
    // requests
    // Checking that the outputs of the hwpf_stride corresponds to its
    // Activation policy
    // Checking the end of prefetch status
    // -------------------------------------------------------------------------

    // Check that the number of request is the same as the number of response
    if ( m_prefetch_inflight_counter[num_hwpf_stride] != 0 ) begin
      `uvm_error(this.name, 
        $sformatf("WRONG NUMBER OF RSP ; PREFETCHER_%0d, NUMBER_OF_INFLIGHT_TXN=%0d(d)", 
          num_hwpf_stride, 
          m_prefetch_inflight_counter[num_hwpf_stride]) );
    end
   
    // -------------------------------------------------------------------------
    // Verification of the activation policy
    // -------------------------------------------------------------------------
    // Determine the activation policy of the hwpf_stride
    hwpf_stride_mode = hwpf_stride_mode_type[{cycle_bit, rearm_bit}];

    // Wait that the nwait counter of the hwpf_stride finished counting before
    // checking if the hwpf_stride is disarming/rearming itself corretly
    if ( m_prefetch_nwait_counter[num_hwpf_stride] != 0 ) begin
      wait ( m_prefetch_nwait_counter[num_hwpf_stride] == 0 );
    end else begin
      @(negedge hwpf_stride_cfg_vif.clk);
    end

    // Checking that if the activation mode is DISARM, that the hw_prefetch_en
    // output changes for this hwpf_stride
//    if ( ( hwpf_stride_mode == DISARM ) || ( hwpf_stride_mode == CYCLE_AND_DISARM ) ) begin
//      if ( hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[0] != 0 ) begin
//        `uvm_error(this.name, 
//          $sformatf("ERROR ACTIVATION MODE %0s; PREFETCHER_%0d ; HW_PREFETCH_EN[%0d]=%0x(x) ; HW_PREFETCH_NWAIT=%0d(d)", 
//            hwpf_stride_mode,
//            num_hwpf_stride, 
//            num_hwpf_stride,
//            hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[0],
//            m_prefetch_nwait_counter[num_hwpf_stride]) );
//      end
//    end

    // Wait another cycle to check if the hwpf_stride is rearming itself or not
    @(negedge hwpf_stride_cfg_vif.clk);

    // In a case of a REARM/DISARM policy, the snoop address is not reinitialized. 
    // Calculate the last address of the prefetch with the configuration, 
    // and get the theoritical snoop addr that it will produce
    end_addr = ( base_address + ( ( nblocks + 1 ) * ( strides + 1 ) ) ) * (HPDCACHE_CL_WIDTH/8) ;
    // Getting the part of the address that should be equal to the snoop address
    end_addr = end_addr[48:6] ;

    // Storing the end address in case of the hwpf_stride starting again with
    // the rearm mode
    last_prefetch_end_addr[num_hwpf_stride] = end_addr;

    // Get the actual snoop addr of the hwpf_stride
    snoop_addr = hwpf_stride_cfg_vif.snoop_addr[num_hwpf_stride] ;

    // Checking that signals of the hwpf_stride are changing accordingly to the
    // activation policy
    if ( ( hwpf_stride_mode == CYCLE_AND_REARM  ) ||
         ( hwpf_stride_mode == CYCLE_AND_DISARM ) ) begin // Snoop address is reinitialized to the base_address
      // Getting the snoop addr of the hwpf_stride and its base_address
      logic [57:0] current_base_address ; // For some reason, the base address size is larger than the hpdcache interface address size
      current_base_address = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[HPDCACHE_OFFSET_WIDTH +: HPDCACHE_NLINE_WIDTH];

     // if ( snoop_addr != current_base_address[42:0] ) begin
     //   `uvm_error(this.name, 
     //     $sformatf("ERROR ACTIVATION MODE %0s ; PREFETCHER_%0d ; SNOOP_ADDR[%0d]=%0x(x), BASE_ADDR=%0x(x)", 
     //       hwpf_stride_mode,
     //       num_hwpf_stride, 
     //       num_hwpf_stride,
     //       snoop_addr,
     //       current_base_address[42:0]) );
     // end
    end else begin // Snoop address should correspond to the address of the last request of a prefetch, with a + 1
     // if ( snoop_addr != end_addr ) begin
     //   `uvm_error(this.name, 
     //     $sformatf("ERROR ACTIVATION MODE %0s ; PREFETCHER_%0d ; SNOOP_ADDR[%0d]=%0x(x) END_ADDR=%0x(x)", 
     //       hwpf_stride_mode,
     //       num_hwpf_stride, 
     //       num_hwpf_stride,
     //       snoop_addr,
     //       end_addr ) );
     // end
    end

    // -------------------------------------------------------------------------
    // Verification of the status of the hwpf_stride
    // -------------------------------------------------------------------------

    // Checking that at the end of the prefetch, the hwpf_stride is signaling
    // correctly that he is available
    if ( hwpf_stride_cfg_vif.hwpf_stride_status[32+num_hwpf_stride] != 0 ) begin
      `uvm_error(this.name, 
        $sformatf("ERROR PREFETCHER BUSY ; PREFETCHER_%0d ; PREFETCHER_STATUS[%0d]=%0x(x)", 
          num_hwpf_stride, 
          32+num_hwpf_stride,
          hwpf_stride_cfg_vif.hwpf_stride_status[32+num_hwpf_stride]) );
    end

    m_status.enable     = hwpf_stride_cfg_vif.hwpf_stride_status[15:0]  ;
    m_status.free_index = hwpf_stride_cfg_vif.hwpf_stride_status[19:16] ;
    m_status.free       = hwpf_stride_cfg_vif.hwpf_stride_status[31]    ;
    m_status.busy       = hwpf_stride_cfg_vif.hwpf_stride_status[47:32] ;

    m_status_cg.sample();

  endtask : analyze_hwpf_stride_rsp


  // -------------------------------------------------------------------------
  // Task check_cfg
  // Task which check that the configuration of the hwpf_stride is not changing
  // when a prefetch is in progress
  // -------------------------------------------------------------------------
  virtual task check_cfg( int num_hwpf_stride, int unsigned prefetch_lenght, mode_e hwpf_stride_mode );
    hpdcache_nline_t  base_address    ;
    logic           cycle           ;
    logic           rearm           ;
    logic [31:0]    stride          ;
    logic [15:0]    nblocks         ;
    logic [15:0]    nlines          ;
    logic [15:0]    nwait           ;
    logic [15:0]    ninflight       ;

    // Variables to get the number of transaction of a burst of hwpf_strides
    int     current_prefetch_lenght ;
    mode_e  current_hwpf_stride_mode ;

    @(negedge hwpf_stride_cfg_vif.clk);

    // -------------------------------------------------------------------------
    // Verification of the status of the hwpf_stride
    // -------------------------------------------------------------------------
    // Checking that one cycle after the match, the hwpf_stride becomes busy
    if ( hwpf_stride_cfg_vif.hwpf_stride_status[32+num_hwpf_stride] == 0 ) begin
      `uvm_error(this.name,
        $sformatf("ERROR PREFETCHER BUSY ; PREFETCHER_%0d ; PREFETCHER_STATUS[%0d]=%0x(x)",
          num_hwpf_stride,
          num_hwpf_stride,
          hwpf_stride_cfg_vif.hwpf_stride_status[32+num_hwpf_stride]) );
    end

    while ( hwpf_stride_cfg_vif.hwpf_stride_status[32+num_hwpf_stride] != 0 ) begin
      base_address = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[HPDCACHE_OFFSET_WIDTH +: HPDCACHE_NLINE_WIDTH]   ;
      cycle        = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[2]      ;
      rearm        = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_base[1]      ;
      stride       = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_param[31:0]  ;
      nlines       = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_param[47:32] ;
      nblocks      = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_param[63:48] ;
      nwait        = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_throttle[15:0] ;
      ninflight    = hwpf_stride_cfg_vif.hwpf_stride_cfg[num_hwpf_stride].hw_prefetch_throttle[31:16] ;

      // Calculate the number of transaction that should be sent by the
      // hwpf_stride for this match
      current_prefetch_lenght = ( nblocks + 1 ) * ( nlines + 1 ) - 1 ;

      // Determine the activation policy of the hwpf_stride
      current_hwpf_stride_mode = hwpf_stride_mode_type[{cycle, rearm}];

      if ( current_prefetch_lenght != prefetch_lenght ) begin
        `uvm_error(this.name,
          $sformatf("CHANGE IN CFG ; PREFETCHER_%0d, It seems that the configuration of the prefetch lenght of this hwpf_stride changed during the prefetch: Current_prefetch_lenght=%0d(d) ; Prefetch_lenght=%0d(d), %0x, %0x", 
            num_hwpf_stride,
            current_prefetch_lenght,
            prefetch_lenght, nblocks, nlines) );
          break;
      end

      if ( current_hwpf_stride_mode != hwpf_stride_mode ) begin
        `uvm_error(this.name,
          $sformatf("CHANGE IN CFG ; PREFETCHER_%0d, It seems that the activation policy of this hwpf_stride changed during the prefetch", 
            num_hwpf_stride) );
          break;
      end

      @(negedge hwpf_stride_cfg_vif.clk);
    end // end while

  endtask

  // -----------------------------------------------------------------------
  // Report phase
  // -----------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
        // -----------------------------------------------------------------------
        // Check that the transaction counters are coherent ( number of write
        // request from the source should be the same as the number of write
        // request on the dest)
        // -----------------------------------------------------------------------
        if ( m_hpdcache_req_counter != m_hpdcache_rsp_counter)
            `uvm_error(this.name, "Number of request not equal to the number of response")

        for ( int i = 0 ; i < NUM_HW_PREFETCH ; i++) begin
          if ( m_hpdcache_req[i].size() != 0 ) begin
            `uvm_error(this.name, $sformatf("ERROR PREFETCHER_%0d : REQUEST QUEUE IS NOT EMPTY ; REQ_QUEUE_SIZE=%0d(d)", i , m_hpdcache_req[i].size() ) )
          end
          if ( m_hpdcache_rsp[i].size() != 0 ) begin
            `uvm_error(this.name, $sformatf("ERROR PREFETCHER_%0d : RESPONSE QUEUE IS NOT EMPTY ; RSP_QUEUE_SIZE=%0d(d)", i , m_hpdcache_rsp[i].size() ) )
          end
          if ( m_prefetch_error_counter[i] != 0 ) begin
            `uvm_error(this.name, $sformatf("ERROR PREFETCHER_%0d : Number of error response is abnormal ; NUMBER_ERROR=%0d(d)", i , m_prefetch_error_counter[i] ) )
          end
        end
  endfunction: report_phase

endclass: hwpf_stride_sb
