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
//  Description : Sequencer for hpdcache request
// ----------------------------------------------------------------------------

class hpdcache_sequencer extends uvm_sequencer #(hpdcache_txn, hpdcache_txn);

  `uvm_sequencer_utils(hpdcache_sequencer)

  // -------------------------------------------------------
  // List to be passed on to sequence to create unique tids
  // -------------------------------------------------------
  hpdcache_req_tid_t   q_inflight_tid[hpdcache_req_tid_t];
  
  // -------------------------------------------------------
  // List to be passed on to sequence to create unique uncacheable regions
  // -------------------------------------------------------
  static bit               q_uncacheable[int];

  // --------------------------------------------------------------
  // Region for the sequence of request within a memory region
  // --------------------------------------------------------------
  int               m_region;

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name = "hpdcache_sequencer", uvm_component parent);
      super.new(name, parent);
      
  endfunction: new

  virtual task reset_phase(uvm_phase phase);
     super.reset_phase(phase); 
     q_inflight_tid.delete();
  endtask 
  
endclass: hpdcache_sequencer
