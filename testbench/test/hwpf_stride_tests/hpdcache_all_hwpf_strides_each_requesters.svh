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
//  Description : This tests configure randomly the hwpf_strides and 
//                sends an unique request from the Requesters to start 
//                them up
// ----------------------------------------------------------------------------

`ifndef __test_hpdcache_all_hwpf_strides_each_requesters_SVH__
`define __test_hpdcache_all_hwpf_strides_each_requesters_SVH__

class test_hpdcache_all_hwpf_strides_each_requesters extends test_base;

  `uvm_component_utils(test_hpdcache_all_hwpf_strides_each_requesters)

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    set_type_override_by_type(hpdcache_txn::get_type(), hpdcache_load_store_with_amos_txn::get_type());
    set_type_override_by_type(memory_rsp_cfg::get_type(), memory_rsp_cfg_no_error::get_type());
    set_type_override_by_type(hwpf_stride_cfg_c::get_type(), hwpf_stride_cfg_cnr_active_c::get_type());

  endfunction: new

  // -------------------------------------------------------------------------
  // Configure phase
  // -------------------------------------------------------------------------
//  virtual task post_reset_phase(uvm_phase phase);
//
//    super.post_reset_phase(phase);
//
//    for ( int m = 0 ; m < NUM_HW_PREFETCH ; m++ ) begin
//      hwpf_stride_cfg_vif.hwpf_stride_cfg[m].hw_prefetch_base[1] <= 1 ;
//      hwpf_stride_cfg_vif.hwpf_stride_cfg[m].hw_prefetch_base[2] <= 1 ;
//    end
//
//  endtask

  // -------------------------------------------------------------------------
  // Run phase
  // -------------------------------------------------------------------------
  virtual task main_phase(uvm_phase phase);

    hpdcache_single_directed_addr m_seq[NREQUESTERS-1];
    
    phase.raise_objection(this, "Starting sequences");

    // Loop to start send only a few request from the Requester to start the
    // hwpf_strides
    for ( int i = 0 ; i < NREQUESTERS-1 ; i++ ) begin
      for ( int m = 0 ; m < NUM_HW_PREFETCH ; m++) begin
        automatic int r = i;
        automatic logic [63:0] auto_address = base_addr[m];
        fork begin
          m_seq[r] = hpdcache_single_directed_addr::type_id::create($sformatf("seq_%0d", r));
          m_seq[r].set_sid(r);
          m_seq[r].set_addr(auto_address);
          m_seq[r].start(env.m_hpdcache[r].m_sequencer);
        end join_none
        #1000ns;
      end
      // Wait for the hwpf_stride to end their hwpf_stridees betfore restarting them
      // again
      #1000ns;
      while ( hwpf_stride_cfg_vif.hwpf_stride_status[32+NUM_HW_PREFETCH:32] != 0 ) begin
        #1ns;
      end
      #1000ns;
    end

    #5000ns;
    phase.drop_objection(this, "Completed sequences");
    super.main_phase(phase);

  endtask: main_phase

endclass: test_hpdcache_all_hwpf_strides_each_requesters

`endif // __test_hpdcache_all_hwpf_strides_each_requesters_SVH__
