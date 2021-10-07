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
//  Description : The aime of this test is to test LR/SC sequences 
//                A sequence of LR/SC mixed with LOAD/STORE AMOS are run 
//                Most(not all) of the accesses are done at the same address. 
//                Aim is to cover all possible combination of LR/SC failure
//                and succes. 
// ----------------------------------------------------------------------------

`ifndef __test_hpdcache_multiple_amo_lr_sc_requests_SVH__
`define __test_hpdcache_multiple_amo_lr_sc_requests_SVH__

class test_hpdcache_multiple_amo_lr_sc_requests extends test_base;

  `uvm_component_utils(test_hpdcache_multiple_amo_lr_sc_requests)

  hpdcache_multiple_amo_lr_sc_requests m_seq[NREQUESTERS-1];
  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  // -------------------------------------------------------------------------
  // Run phase
  // -------------------------------------------------------------------------
  virtual task pre_main_phase(uvm_phase phase);
    
    // Create new sequence
    for (int i = 0; i < NREQUESTERS-1; i++) begin
        m_seq[i] = hpdcache_multiple_amo_lr_sc_requests::type_id::create($sformatf("seq_%0d", i));
        if(!$cast(base_sequence[i], m_seq[i])) `uvm_fatal("CAST FAILED", "cannot cast base seqence");
    end

    super.pre_main_phase(phase);
  endtask: pre_main_phase

endclass: test_hpdcache_multiple_amo_lr_sc_requests

`endif // __test_hpdcache_multiple_amo_lr_sc_requests_SVH__
