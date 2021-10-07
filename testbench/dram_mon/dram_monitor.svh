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
//  Description : Monitor for dram memory miss request
// ----------------------------------------------------------------------------

class dram_monitor extends uvm_monitor;

  `uvm_component_utils(dram_monitor)
  
  virtual dram_if               vif;

  int                              num_req_pkts;
  int                              num_resp_pkts;
  
  // Internal members for monitoring requests
  uvm_analysis_port #(hpdcache_mem_req_t)     ap_mem_miss_req;
  uvm_analysis_port #(hpdcache_mem_ext_req_t) ap_mem_miss_ext_req;
  hpdcache_mem_req_t                       req;
  hpdcache_mem_ext_req_t                   req_ext;

  // Internal members for monitoring responses
  uvm_analysis_port #(hpdcache_mem_resp_r_t) ap_mem_read_rsp;
  uvm_analysis_port #(hpdcache_mem_resp_w_t) ap_mem_write_rsp;
  hpdcache_mem_resp_r_t                      rsp_cloned;

  // Events to handle reset
  event                             reset_asserted;
  event                             reset_deasserted;

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

    if(!uvm_config_db#(virtual dram_if)::get(this, "", "DRAM_IF", vif)) begin
      `uvm_error("NOVIF", {"Monitor virtual interface must be set for: ",
                  get_full_name( ), ".vif"})
    end

    ap_mem_miss_req      = new("ap_mem_miss_req", this);
    ap_mem_miss_ext_req  = new("ap_mem_miss_ext_req", this);
//    req          = mon_trans::type_id::create("req");
//    req_cloned   = mon_trans::type_id::create("req_cloned");

    ap_mem_read_rsp    = new("ap_mem_read_rsp", this);
    ap_mem_write_rsp   = new("ap_mem_write_rsp", this);
//    rsp          = vrp_response::type_id::create("rsp");
//    rsp_cloned   = vrp_response::type_id::create("rsp_cloned");

    num_req_pkts        = 0;
    num_resp_pkts       = 0;

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
    num_req_pkts        = 0;
    num_resp_pkts       = 0;
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
      super.main_phase(phase);
      fork
        collect_reqs( phase );
        collect_resps( phase );
      join_none
  endtask: main_phase

  // -------------------------------------------------------------------------
  // Collect requests 
  // -------------------------------------------------------------------------
  virtual task collect_reqs( uvm_phase phase );

    forever begin
      @(negedge vif.clk_i);
      
      if (vif.mem_req_miss_read_valid_o && vif.mem_req_miss_read_ready_i) begin

        req     = vif.mem_req_miss_read_o; 
        print_hpdcache_mem_req_t(req, "DRAM MONITOR MISS READ REQ");
        ap_mem_miss_req.write(req);
        num_req_pkts++;

      end
      if (vif.mem_req_uc_read_valid_o && vif.mem_req_uc_read_ready_i) begin

        req     = vif.mem_req_uc_read_o; 
        print_hpdcache_mem_req_t(req, "DRAM MONITOR UC READ REQ");
        ap_mem_miss_req.write(req);
        num_req_pkts++;

      end

      // Write request 
      if (vif.mem_req_wbuf_write_valid_o && vif.mem_req_wbuf_write_ready_i) begin

        req     = vif.mem_req_wbuf_write_o; 
        print_hpdcache_mem_req_t(req, "DRAM MONITOR WBUF WRITE REQ");
        ap_mem_miss_req.write(req);
        num_req_pkts++;

      end
      if (vif.mem_req_uc_write_valid_o && vif.mem_req_uc_write_ready_i) begin

        req     = vif.mem_req_uc_write_o; 
        print_hpdcache_mem_req_t(req, "DRAM MONITOR UC WRITE REQ");
        ap_mem_miss_req.write(req);
        num_req_pkts++;


        // In case of atomics memory sent 2 responses 
        // Except in the case of LDEX/STEX
        if(req.mem_req_command == HPDCACHE_MEM_ATOMIC && !(req.mem_req_atomic == HPDCACHE_MEM_ATOMIC_LDEX || req.mem_req_atomic == HPDCACHE_MEM_ATOMIC_STEX)) begin
          num_req_pkts++;         
        end
      end

      // Write data 
      if (vif.mem_req_wbuf_write_valid_int_o && vif.mem_req_wbuf_write_ready_int_i) begin

        req_ext     = vif.mem_req_wbuf_write_int_o; 
        ap_mem_miss_ext_req.write(req_ext);

      end
      if (vif.mem_req_uc_write_valid_int_o && vif.mem_req_uc_write_ready_int_i) begin

        req_ext     = vif.mem_req_uc_write_int_o; 
        ap_mem_miss_ext_req.write(req_ext);

      end
    end
  endtask: collect_reqs
 
  // -------------------------------------------------------------------------
  // Collect responses
  // -------------------------------------------------------------------------
  task collect_resps( uvm_phase phase );
    hpdcache_mem_resp_r_t   r_rsp;
    hpdcache_mem_resp_r_t   w_rsp;
    forever begin
      @(negedge vif.clk_i);
      if (vif.mem_resp_miss_read_ready_o && vif.mem_resp_miss_read_valid_int_i) begin

        // Send object to the scoreboard
        r_rsp      = vif.mem_resp_miss_read_int_i;
        print_hpdcache_mem_resp_r_t(r_rsp, "DRAM MONITOR MISS READ RSP");
        ap_mem_read_rsp.write(r_rsp);
        num_resp_pkts++;

      end      
      if (vif.mem_resp_uc_read_ready_o && vif.mem_resp_uc_read_valid_int_i) begin

        // Send object to the scoreboard
        r_rsp      = vif.mem_resp_uc_read_int_i;
        print_hpdcache_mem_resp_r_t(r_rsp, "DRAM MONITOR UC READ RSP");
        ap_mem_read_rsp.write(r_rsp);
        num_resp_pkts++;

      end      
      if (vif.mem_resp_wbuf_write_ready_o && vif.mem_resp_wbuf_write_valid_i) begin

        // Send object to the scoreboard
        w_rsp      = vif.mem_resp_wbuf_write_i;
        print_hpdcache_mem_resp_w_t(w_rsp, "DRAM MONITOR WBUF WRITE RSP");
        ap_mem_write_rsp.write(w_rsp);
        num_resp_pkts++;

      end      
      if (vif.mem_resp_uc_write_ready_o && vif.mem_resp_uc_write_valid_i) begin

        // Send object to the scoreboard
        w_rsp      = vif.mem_resp_uc_write_i;
        print_hpdcache_mem_resp_w_t(w_rsp, "DRAM MONITOR UC WRITE RSP");
        ap_mem_write_rsp.write(w_rsp);
        num_resp_pkts++;

      end      
    end
  endtask

endclass: dram_monitor
