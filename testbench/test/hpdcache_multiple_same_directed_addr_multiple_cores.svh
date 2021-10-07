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
//  Description : This tests random access to the DCACHE
//                Addresses are with in a partitioned region
// ----------------------------------------------------------------------------

`ifndef __test_hpdcache_multiple_same_directed_addr_multiple_cores_SVH__
`define __test_hpdcache_multiple_same_directed_addr_multiple_cores_SVH__

class test_hpdcache_multiple_same_directed_addr_multiple_cores extends test_base;

  `uvm_component_utils(test_hpdcache_multiple_same_directed_addr_multiple_cores)

  hpdcache_set_t      set; 
  hpdcache_req_addr_t req_addr_arr[DCACHE_WAYS+1];

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  // -------------------------------------------------------------------------
  // Run phase
  // -------------------------------------------------------------------------
  virtual task main_phase(uvm_phase phase);
    hpdcache_multiple_same_directed_addr_multiple_cores m_seq[NREQUESTERS-1];

 
    phase.raise_objection(this, "Starting sequences");


    // Fix the set 
    set = $urandom;
    // Randomize the tag 
    foreach (req_addr_arr[i]) begin 
      req_addr_arr[i] = {$urandom, $urandom}; 
      req_addr_arr[i][DCACHE_OFFSET_WIDTH +: DCACHE_SET_WIDTH] = set;
    end
 
    // Create new sequence
    for (int i = 0; i < NREQUESTERS-1; i++) begin
      automatic int r = i;
      fork begin
        m_seq[r] = hpdcache_multiple_same_directed_addr_multiple_cores::type_id::create($sformatf("seq_%0d", r));
        m_seq[r].set_sid(r);
        m_seq[r].set_addr_arr(req_addr_arr);
        m_seq[r].start(env.m_hpdcache[r].m_sequencer);
      end join_none
    end
    phase.drop_objection(this, "Completed sequences");

    super.main_phase(phase);
  endtask: main_phase

endclass: test_hpdcache_multiple_same_directed_addr_multiple_cores

`endif // __test_hpdcache_multiple_same_directed_addr_multiple_cores_SVH__
