/// ----------------------------------------------------------------------------
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

`ifndef __test_hpdcache_multiple_mostly_cacheable_store_with_memory_bp_SVH__
`define __test_hpdcache_multiple_mostly_cacheable_store_with_memory_bp_SVH__

class test_hpdcache_multiple_mostly_cacheable_store_with_memory_bp extends test_hpdcache_multiple_random_requests;

  `uvm_component_utils(test_hpdcache_multiple_mostly_cacheable_store_with_memory_bp)
  hpdcache_multiple_random_requests_mostly_cached m_seq_mostly_cached[NREQUESTERS-1];

// -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    set_type_override_by_type(hpdcache_txn::get_type(), hpdcache_mostly_cacheable_store_txn::get_type());
  endfunction: new

  // -------------------------------------------------------------------------
  // Pre Main Phase
  // -------------------------------------------------------------------------
  virtual task pre_main_phase(uvm_phase phase);
    
    // Create new sequence
    for (int i = 0; i < NREQUESTERS-1; i++) begin
      m_seq_mostly_cached[i] = hpdcache_multiple_random_requests_mostly_cached::type_id::create($sformatf("seq_%0d", i));
      if(!$cast(base_sequence[i], m_seq_mostly_cached[i])) `uvm_fatal("CAST FAILED", "cannot cast base seqence");
    end

    super.pre_main_phase(phase);
    env.m_mem_rsp_model.set_enable_rd_output(0);
    env.m_mem_rsp_model.set_enable_wr_output(0);

  endtask: pre_main_phase


  virtual task main_phase(uvm_phase phase);
  
    
    fork 
    begin
      phase.raise_objection(this);
      vif.wait_n_clocks(1000); 
      
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

endclass: test_hpdcache_multiple_mostly_cacheable_store_with_memory_bp

`endif // __test_hpdcache_multiple_mostly_cacheable_store_with_memory_bp_SVH__
