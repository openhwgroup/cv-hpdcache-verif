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
//  Description : This tests random access to the HPDCACHE
// ----------------------------------------------------------------------------

`ifndef __test_hpdcache_multiple_consecutive_set_store_with_memory_bp_SVH__
`define __test_hpdcache_multiple_consecutive_set_store_with_memory_bp_SVH__

class test_hpdcache_multiple_consecutive_set_store_with_memory_bp extends test_base;

  `uvm_component_utils(test_hpdcache_multiple_consecutive_set_store_with_memory_bp)
  hpdcache_consecutive_set_access_request_cached m_seq[NREQUESTERS-1];

// -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    set_type_override_by_type(hpdcache_txn::get_type(), hpdcache_mostly_cacheable_store_txn::get_type());
    set_type_override_by_type(hpdcache_top_cfg::get_type(), hpdcache_top_one_requester_congestion_cfg::get_type());
  endfunction: new

  function void start_of_simulation_phase(uvm_phase phase);

    super.start_of_simulation_phase(phase);
    env.m_mem_rsp_model.set_enable_rd_output(0);
    env.m_mem_rsp_model.set_enable_wr_output(0);
  endfunction 
  // -------------------------------------------------------------------------
  // Pre Main Phase
  // -------------------------------------------------------------------------
  virtual task pre_main_phase(uvm_phase phase);
    // Create new sequence
    for (int i = 0; i < NREQUESTERS-1; i++) begin
      m_seq[i] = hpdcache_consecutive_set_access_request_cached::type_id::create($sformatf("seq_%0d", i));
      if(!$cast(base_sequence[i], m_seq[i])) `uvm_fatal("CAST FAILED", "cannot cast base seqence");
    end

    super.pre_main_phase(phase);

  endtask: pre_main_phase


  virtual task main_phase(uvm_phase phase);
  
    
    fork 
    begin
      phase.raise_objection(this);
      vif.wait_n_clocks(1000); 
      
      if(env.m_hpdcache_sb.get_mem_req_counter() == HPDCACHE_WBUF_DIR_ENTRIES) begin
        `uvm_info("TEST", $sformatf("Number of requests recieved %0d(d), HPDCACHE SETS %0d(d)", env.m_hpdcache_sb.get_mem_req_counter(), HPDCACHE_WBUF_DIR_ENTRIES), UVM_LOW);
      end else begin
        `uvm_error("TEST", $sformatf("Number of requests recieved %0d(d), HPDCACHE SETS %0d(d)", env.m_hpdcache_sb.get_mem_req_counter(), HPDCACHE_WBUF_DIR_ENTRIES));
      end
      env.m_mem_rsp_model.set_enable_rd_output(1);
      env.m_mem_rsp_model.set_enable_wr_output(1);

      phase.drop_objection(this);
    end 
    join_none

    super.main_phase(phase);
     phase.raise_objection(this);

    #100000ns;
    phase.drop_objection(this, "Completed sequences");

  endtask

endclass: test_hpdcache_multiple_consecutive_set_store_with_memory_bp

`endif // __test_hpdcache_multiple_consecutive_set_store_with_memory_bp_SVH__
