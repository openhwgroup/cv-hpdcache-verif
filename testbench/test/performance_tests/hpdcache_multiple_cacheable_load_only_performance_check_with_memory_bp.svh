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
//  Description : This tests perfromance of HPDCACHE
//                This test runs random cacheable load with zelo delay 
// ----------------------------------------------------------------------------

`ifndef __test_hpdcache_multiple_cacheable_load_only_performance_check_with_memory_bp_SVH__
`define __test_hpdcache_multiple_cacheable_load_only_performance_check_with_memory_bp_SVH__
// -----------------------------------------------------
// Derived config class with zero delay 
// -----------------------------------------------------
class memory_rsp_cfg_fixed_delay_rsp extends memory_rsp_cfg;

    `uvm_object_utils( memory_rsp_cfg_fixed_delay_rsp )

    function new( string name ="" );
        super.new( name );
    endfunction

    constraint memory_rsp_mode_c              { rsp_mode == FIXED_DELAY_RSP;};
    constraint inter_data_cycle_fixed_delay_c { inter_data_cycle_fixed_delay == 2*HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS;};
endclass 

class test_hpdcache_multiple_cacheable_load_only_performance_check_with_memory_bp extends test_base;

  `uvm_component_utils(test_hpdcache_multiple_cacheable_load_only_performance_check_with_memory_bp)
   hpdcache_multiple_random_requests_cached m_seq[NREQUESTERS-1];

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    set_type_override_by_type(hpdcache_txn::get_type(),   hpdcache_zero_delay_cacheable_load_txn::get_type());
    set_type_override_by_type(hpdcache_conf_txn::get_type(),   hpdcache_conf_performance_txn::get_type());
    set_type_override_by_type(memory_rsp_cfg::get_type(), memory_rsp_cfg_fixed_delay_rsp::get_type());
  endfunction: new

  // -------------------------------------------------------------------------
  // Pre Main Phase
  // -------------------------------------------------------------------------
  virtual task pre_main_phase(uvm_phase phase);
    
    // Create new sequence
    for (int i = 0; i < NREQUESTERS-1; i++) begin
      m_seq[i] = hpdcache_multiple_random_requests_cached::type_id::create($sformatf("seq_%0d", i));
      if(!$cast(base_sequence[i], m_seq[i])) `uvm_fatal("CAST FAILED", "cannot cast base seqence");
    end

    super.pre_main_phase(phase);
  endtask: pre_main_phase

    virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    if((env.m_hpdcache_sb.m_last_trans_cycle -env.m_hpdcache_sb.m_first_trans_cycle) < 2*3*(num_txn) ) begin
      `uvm_error("TEST REPORT", $sformatf("Expected %0d(d), Recieved %0d(d)", num_txn , (env.m_hpdcache_sb.m_last_trans_cycle -env.m_hpdcache_sb.m_first_trans_cycle + 1) ));
    end else begin
      `uvm_info("TEST REPORT", $sformatf("FIRST %0d(d), LAST %0d(d), TOTAL %0d(d)", env.m_hpdcache_sb.m_first_trans_cycle, env.m_hpdcache_sb.m_last_trans_cycle, (env.m_hpdcache_sb.m_last_trans_cycle -env.m_hpdcache_sb.m_first_trans_cycle) ), UVM_LOW);
    end
  endfunction 


endclass: test_hpdcache_multiple_cacheable_load_only_performance_check_with_memory_bp

`endif // __test_hpdcache_multiple_cacheable_load_only_performance_check_with_memory_bp_SVH__
