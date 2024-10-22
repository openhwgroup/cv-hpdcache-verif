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
//  Description : Monitor for hpdcache request
// ----------------------------------------------------------------------------

class hpdcache_monitor extends uvm_monitor;

  `uvm_component_utils(hpdcache_monitor)

  // -------------------------------------------------------------------------
  // Fields for the vrp monitor
  // -------------------------------------------------------------------------
  protected uvm_active_passive_enum is_active = UVM_PASSIVE;

  virtual hpdcache_if               vif;

  int                              num_req_pkts;
  int                              num_req_no_resp_pkts;
  int                              num_resp_pkts;
  
  // -------------------------------------------------------------------------
  // Internal members for monitoring requests
  // -------------------------------------------------------------------------
  uvm_analysis_port #(hpdcache_req_mon_t) ap_hpdcache_req;

  // -------------------------------------------------------------------------
  // Sequencer used to clean the inflight id list
  // -------------------------------------------------------------------------
  hpdcache_sequencer                  m_sequencer;
  
  // -------------------------------------------------------------------------
  // Internal members for monitoring responses
  // -------------------------------------------------------------------------
  uvm_analysis_port #(hpdcache_rsp_t) ap_hpdcache_rsp;

  // -----------------------------------------------------------------------
  // Coverage covergroups
  // -----------------------------------------------------------------------
  // Covergroup
  hpdcache_req_cg   m_hpdcache_req_cg ;
  hpdcache_rsp_cg   m_hpdcache_rsp_cg ;

  hpdcache_req_mon_t    m_req_packet;
  hpdcache_rsp_t    m_rsp_packet;

  // Events to handle reset
  event                             reset_asserted;
  event                             reset_deasserted;
  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
      super.new(name, parent);

      // Creation of the covergroups
      m_hpdcache_req_cg = new ( m_req_packet ) ;
      m_hpdcache_rsp_cg = new ( m_rsp_packet ) ;

  endfunction: new

  // -------------------------------------------------------------------------
  // Build phase
  // -------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    ap_hpdcache_req    = new("ap_hpdcache_req", this);
    ap_hpdcache_rsp    = new("ap_hpdcache_rsp", this);

    num_req_pkts            = 0;
    num_req_no_resp_pkts    = 0;
    num_resp_pkts           = 0;

    `uvm_info(get_full_name( ), "Build stage complete.", UVM_HIGH)
  endfunction: build_phase

  // -------------------------------------------------------------------------
  // Pre-reset phase
  // -------------------------------------------------------------------------
  virtual task pre_reset_phase(uvm_phase phase);
    super.pre_reset_phase(phase);
    -> reset_asserted;
  endtask: pre_reset_phase

  virtual task reset_phase(uvm_phase phase);
    super.reset_phase(phase);
    num_req_pkts            = 0;
    num_req_no_resp_pkts    = 0;
    num_resp_pkts           = 0;
  endtask: reset_phase
  // -------------------------------------------------------------------------
  // Post-reset phase
  // -------------------------------------------------------------------------
  virtual task post_reset_phase(uvm_phase phase);
    super.post_reset_phase(phase);
    -> reset_deasserted;
  endtask: post_reset_phase

  // -------------------------------------------------------------------------
  // Run phase
  // -------------------------------------------------------------------------
  virtual task main_phase(uvm_phase phase);
      `uvm_info("HPDCACHE MONITOR", "Entering Main Phase", UVM_HIGH);
      super.main_phase(phase);
      fork
        collect_reqs( phase );
        collect_resps( phase );
      join_none
      `uvm_info("HPDCACHE MONITOR", "Leaving Main Phase", UVM_HIGH);
  endtask: main_phase

  // -------------------------------------------------------------------------
  // Collect requests 
  // -------------------------------------------------------------------------
  virtual task collect_reqs(uvm_phase phase);
    hpdcache_req_t        req;
    hpdcache_req_mon_t    req_mon;

    forever begin
      @(posedge vif.clk_i);
      
      if (vif.core_req_valid_i && vif.core_req_ready_o) begin
        req_mon.addr_offset  = vif.core_req_i.addr_offset; 
        req_mon.wdata        = vif.core_req_i.wdata      ; 
        req_mon.op           = vif.core_req_i.op         ; 
        req_mon.be           = vif.core_req_i.be         ; 
        req_mon.size         = vif.core_req_i.size       ; 
        req_mon.sid          = vif.core_req_i.sid        ; 
        req_mon.tid          = vif.core_req_i.tid        ; 
        req_mon.need_rsp     = vif.core_req_i.need_rsp   ; 

        //  only valid in case of physically indexed requests
        req_mon.phys_indexed = vif.core_req_i.phys_indexed ; 
        req_mon.addr_tag     = vif.core_req_i.addr_tag ; 
        req_mon.pma          = vif.core_req_i.pma ; 
        req_mon.addr         = {req_mon.addr_tag, req_mon.addr_offset};
        req_mon.second_cycle       = 0;
        
        print_hpdcache_req_t(req_mon, "HPDCACHE MONITOR REQ");

        m_req_packet = req_mon;
        m_hpdcache_req_cg.sample( );


        if(req_mon.need_rsp == 0) begin
          num_req_no_resp_pkts++;
        end
   
        // Send object to the scoreboard
        // #0 delay the write 
        //  --> to respect coherence in case 2 requests arrive at the same
        //  time 
        //   ----> Possibl in the case where phy_index=1 for one channel and
        //   0 for another 
        #0 ap_hpdcache_req.write(req_mon);
        if(req_mon.phys_indexed == 0) begin
          @(posedge vif.clk_i);
          req_mon.abort              = vif.core_req_abort_i;
          req_mon.addr_tag           = vif.core_req_tag_i;
          req_mon.pma.uncacheable    = vif.core_req_pma_i.uncacheable;
          req_mon.pma.io             = vif.core_req_pma_i.io;
          req_mon.addr               = {req_mon.addr_tag, req_mon.addr_offset};
          req_mon.second_cycle       = 1;
          ap_hpdcache_req.write(req_mon);
        end


        num_req_pkts++;
     //   `uvm_info("HPDCACHE MONITOR", $sformatf("NUM REQ=%0d(d), NUM RSP=%0d(d)  NUM NO_RSP=%0d(d)", num_req_pkts, num_resp_pkts, num_req_no_resp_pkts), UVM_HIGH);
      end
    end
  endtask: collect_reqs
 
  // -------------------------------------------------------------------------
  // Collect responses
  // -------------------------------------------------------------------------
  task collect_resps(uvm_phase phase);
    hpdcache_rsp_t    rsp;

    forever begin
      @(posedge vif.clk_i);
      if (vif.core_rsp_valid_o) begin
        rsp = vif.core_rsp_o;
        print_hpdcache_rsp_t(rsp, "HPDCACHE MONITOR RSP");

        m_rsp_packet = rsp ;
        m_hpdcache_rsp_cg.sample( );
        
        if (is_active == UVM_ACTIVE ) m_sequencer.q_inflight_tid.delete(rsp.tid);

        // #0 delay the write 
        //  --> to respect coherence in case the response of the requests 
        //  arrive at the same time 
        //   ----> Possibl in the case where phy_index=0 
        #0 ap_hpdcache_rsp.write(rsp);
        num_resp_pkts++;
   //     `uvm_info("HPDCACHE MONITOR", $sformatf("NUM REQ=%0d(d), NUM RSP=%0d(d)  NUM NO_RSP=%0d(d)", num_req_pkts, num_resp_pkts, num_req_no_resp_pkts), UVM_HIGH);
  //      phase.drop_objection( this );    
      end      
    end
  endtask

  // -------------------------------------------------------------------------
  // POST SHUTDOWN PHASE
  // -------------------------------------------------------------------------
  task post_shutdown_phase(uvm_phase phase);
    super.post_shutdown_phase(phase);

    phase.raise_objection(this, "Entering Shutdown phase");    
    do begin
     #10;
     `uvm_info("HPDCACHE MONITOR", $sformatf("NUM REQ=%0d(d), NUM RSP=%0d(d)  NUM NO_RSP=%0d(d)", num_req_pkts, num_resp_pkts, num_req_no_resp_pkts), UVM_HIGH);
    end while(num_req_pkts != (num_resp_pkts + num_req_no_resp_pkts));
    phase.drop_objection(this, "Leaving Shutdown phase");    

  endtask

  // ----------------------------------------------------------------------
  // Set agent to active mode
  // ----------------------------------------------------------------------
  function void set_is_active();
    is_active = UVM_ACTIVE;
  endfunction: set_is_active

  // -------------------------------------------------------------------------
  // Report phase
  // -------------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
      `uvm_info(get_type_name( ), $psprintf("REPORT: COLLECTED REQUEST TRANSACTIONS = %0d, COLLECTED RESPONSE TRANSACTIONS = %d",
                                            num_req_pkts, (num_resp_pkts + num_req_no_resp_pkts) ), UVM_HIGH)
  endfunction: report_phase

    // API to set the interface 
    function void set_hpdcache_vif (virtual hpdcache_if I);
        vif = I;
    endfunction

endclass: hpdcache_monitor
