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
//  Description : This tests sends an unique request to the DCACHE to start up
//                the hwpf_stride, which is configured to send exactly 
//                256 requests to the DCACHE
// ----------------------------------------------------------------------------

`ifndef __test_hpdcache_multiple_directed_addr_with_multiple_hwpf_stride_at_same_addr_SVH__
`define __test_hpdcache_multiple_directed_addr_with_multiple_hwpf_stride_at_same_addr_SVH__

class test_hpdcache_multiple_directed_addr_with_multiple_hwpf_stride_at_same_addr extends test_base;

  `uvm_component_utils(test_hpdcache_multiple_directed_addr_with_multiple_hwpf_stride_at_same_addr)

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    set_type_override_by_type(hpdcache_txn::get_type(), hpdcache_load_store_with_amos_txn::get_type());
    set_type_override_by_type(memory_rsp_cfg::get_type(), memory_rsp_cfg_no_error::get_type());
  endfunction: new

  // -------------------------------------------------------------------------
  // Run phase
  // -------------------------------------------------------------------------
  virtual task main_phase(uvm_phase phase);

    hpdcache_multiple_directed_consecutive_addr   m_seq[NREQUESTERS-1];
    
    phase.raise_objection(this, "Starting sequences");

    // Loop to start send only a few request from the Requester to start the
    // hwpf_strides
    for ( int m = 0 ; m < NUM_HW_PREFETCH ; m++) begin
      for ( int i = 0 ; i < NREQUESTERS-1 ; i++ ) begin
        automatic int r = i;
        automatic logic [63:0] auto_address = base_addr[m]; 
        fork begin
          m_seq[r] = hpdcache_multiple_directed_consecutive_addr::type_id::create($sformatf("seq_%0d", r));
          m_seq[r].set_sid(r);
          m_seq[r].req_addr_start = auto_address;
          m_seq[r].start(env.m_hpdcache[r].m_sequencer);
        end join_none
      end
    end

    // Wait for the hwpf_stride to start
    wait ( hwpf_stride_cfg_vif.hwpf_stride_status[35:32] != 'h0 );

    // Wait for the hwpf_stride to end
    wait ( hwpf_stride_cfg_vif.hwpf_stride_status[35:32] == 'h0 );

    #10000ns;
    phase.drop_objection(this, "Completed sequences");
    super.main_phase(phase);

  endtask: main_phase

endclass:test_hpdcache_multiple_directed_addr_with_multiple_hwpf_stride_at_same_addr

`endif // __test_hpdcache_single_directed_addr_with_multiple_hwpf_stride_at_same_addr_SVH__
