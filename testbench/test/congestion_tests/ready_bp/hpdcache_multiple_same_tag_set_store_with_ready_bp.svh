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

`ifndef __test_hpdcache_multiple_same_tag_set_store_with_ready_bp_SVH__
`define __test_hpdcache_multiple_same_tag_set_store_with_ready_bp_SVH__

class test_hpdcache_multiple_same_tag_set_store_with_ready_bp extends test_base;

  `uvm_component_utils(test_hpdcache_multiple_same_tag_set_store_with_ready_bp)
  hpdcache_same_tag_set_access_request_cached m_seq[NREQUESTERS-1];

// -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    set_type_override_by_type(hpdcache_txn::get_type(), hpdcache_mostly_cacheable_store_txn::get_type());
    set_type_override_by_type(hpdcache_top_cfg::get_type(), hpdcache_top_one_requester_congestion_cfg::get_type());
  endfunction: new
  // -------------------------------------------------------------------------
  // Pre Main Phase
  // -------------------------------------------------------------------------
  virtual task pre_reset_phase(uvm_phase phase);
    super.pre_reset_phase(phase);

    // force NoC ready to 0
    m_read_bp_vif.force_bp_out(1'b1);
    m_write_req_bp_vif.force_bp_out(1'b1);
    m_write_data_bp_vif.force_bp_out(1'b1);
  endtask
  // -------------------------------------------------------------------------
  // Pre Main Phase
  // -------------------------------------------------------------------------
  virtual task pre_main_phase(uvm_phase phase);
    // Create new sequence
    for (int i = 0; i < NREQUESTERS-1; i++) begin
      m_seq[i] = hpdcache_same_tag_set_access_request_cached::type_id::create($sformatf("seq_%0d", i));
      if(!$cast(base_sequence[i], m_seq[i])) `uvm_fatal("CAST FAILED", "cannot cast base seqence");
    end

    super.pre_main_phase(phase);

  endtask: pre_main_phase


  virtual task main_phase(uvm_phase phase);
  
    
    fork 
    begin
      phase.raise_objection(this);
      vif.wait_n_clocks(1000); 
            
      //release ready signal
      m_read_bp_vif.release_bp_out();
      m_write_req_bp_vif.release_bp_out();
      m_write_data_bp_vif.release_bp_out();
      phase.drop_objection(this);
    end 
    join_none

    super.main_phase(phase);
     phase.raise_objection(this);

    #100000ns;
    phase.drop_objection(this, "Completed sequences");

  endtask

endclass: test_hpdcache_multiple_same_tag_set_store_with_ready_bp

`endif // __test_hpdcache_multiple_same_tag_set_store_with_ready_bp_SVH__
