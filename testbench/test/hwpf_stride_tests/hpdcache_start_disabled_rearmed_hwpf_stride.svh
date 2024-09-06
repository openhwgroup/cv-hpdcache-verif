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

`ifndef __test_hpdcache_start_disabled_rearmed_hwpf_stride_SVH__
`define __test_hpdcache_start_disabled_rearmed_hwpf_stride_SVH__

class test_hpdcache_start_disabled_rearmed_hwpf_stride extends test_base;

  `uvm_component_utils(test_hpdcache_start_disabled_rearmed_hwpf_stride)

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    set_type_override_by_type(hpdcache_txn::get_type(), hpdcache_load_store_with_amos_txn::get_type());
    set_type_override_by_type(memory_rsp_cfg::get_type(), memory_rsp_cfg_no_error::get_type());
  endfunction: new

  // -------------------------------------------------------------------------
  // Configure phase
  // -------------------------------------------------------------------------
  virtual task configure_phase(uvm_phase phase);

    super.configure_phase(phase);

    for ( int m = 0 ; m < NUM_HW_PREFETCH ; m++ ) begin
      hwpf_stride_cfg_vif.hwpf_stride_cfg[m].hw_prefetch_base[1] <= 1 ;
      hwpf_stride_cfg_vif.hwpf_stride_cfg[m].hw_prefetch_base[2] <= 0 ;
    end

  endtask

  // -------------------------------------------------------------------------
  // Run phase
  // -------------------------------------------------------------------------
  virtual task main_phase(uvm_phase phase);

    hpdcache_single_directed_addr m_seq[NREQUESTERS-1];

    phase.raise_objection(this, "Starting sequences");

    // Loop to start send only a few request from the Requester to start the
    // hwpf_strides
    for ( int m = 0 ; m < NUM_HW_PREFETCH ; m++) begin
      for ( int i = 0 ; i < NREQUESTERS-1 ; i++ ) begin
        automatic int r = i;
        automatic logic [63:0] auto_address = base_addr[m];
        fork begin
          m_seq[r] = hpdcache_single_directed_addr::type_id::create($sformatf("seq_%0d", r));
          m_seq[r].set_sid(r);
          m_seq[r].set_addr(auto_address);
          m_seq[r].start(env.m_hpdcache[r].m_sequencer);
        end join_none
      end
    end

    // Waiting until all hwpf_strides have started
    wait ( hwpf_stride_cfg_vif.hwpf_stride_status[32+NUM_HW_PREFETCH:32] != 'h0 ) 

    // Waiting until all hwpf_strides have ended
    wait ( hwpf_stride_cfg_vif.hwpf_stride_status[32+NUM_HW_PREFETCH:32] == 'h0 ) 

    // Disabling the hwpf_stride to reset its configuration between two burst
    for ( int i = 0 ; i < NUM_HW_PREFETCH ; i++) begin 
      automatic int r = i;
      fork begin
        hwpf_stride_cfg_vif.hwpf_stride_cfg[r].hw_prefetch_base[0] = 'h0 ;
        #100ns;
        hwpf_stride_cfg_vif.hwpf_stride_cfg[r].hw_prefetch_base[0] = 'h1 ;
      end join_none
    end
    #100ns

    // Loop to start all the hwpf_stride again
    for ( int m = 0 ; m < NUM_HW_PREFETCH ; m++) begin
      // Creating the sequence to restart the hwpf_stride
      for ( int i = 0 ; i < NREQUESTERS-1 ; i++ ) begin
        automatic int r = i;
        automatic logic [63:0] auto_address = base_addr[m];
        fork begin
          m_seq[r] = hpdcache_single_directed_addr::type_id::create($sformatf("seq_%0d", r));
          m_seq[r].set_sid(r);
          m_seq[r].set_addr(auto_address);
          m_seq[r].start(env.m_hpdcache[r].m_sequencer);
        end join_none
      end
    end

    // Waiting to check if the hwpf_strides have restarted
    wait ( hwpf_stride_cfg_vif.hwpf_stride_status[32+NUM_HW_PREFETCH:32] != 'h0 ) 

    // Wait for all hwpf_strides to end
    wait ( hwpf_stride_cfg_vif.hwpf_stride_status[32+NUM_HW_PREFETCH:32] == 0 )

    phase.drop_objection(this, "Completed sequences");
    super.main_phase(phase);

  endtask: main_phase

endclass: test_hpdcache_start_disabled_rearmed_hwpf_stride

`endif // __test_hpdcache_start_disabled_rearmed_hwpf_stride_SVH__
