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
//  Description : This tests generic access to the HPDCACHE
// ----------------------------------------------------------------------------

`ifndef __test_hpdcache_generic_request_SVH__
`define __test_hpdcache_generic_request_SVH__

class test_hpdcache_generic_request extends test_base;

  `uvm_component_utils(test_hpdcache_generic_request)

  hpdcache_generic_request m_seq[NREQUESTERS-1];
  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  function void build_phase(uvm_phase phase); 
    super.build_phase(phase);
    for (int i = 0; i < NREQUESTERS-1; i++) begin
      m_seq[i] = hpdcache_generic_request::type_id::create($sformatf("seq_%0d", i));
    end

    `uvm_info(get_full_name(), "Build phase complete", UVM_LOW)
  endfunction: build_phase

  // ----------------------------------------------------------
  // PRE MAIN PHASE 
  // ----------------------------------------------------------
  virtual task pre_main_phase(uvm_phase phase);

    for (int i = 0; i < NREQUESTERS-1; i++) begin
      m_seq[i].m_hpdcache_partitions = env.m_hpdcache_partitions; 
      m_seq[i].set_sid(i);
    end
  endtask
  // -------------------------------------------------------------------------
  // Run phase
  // -------------------------------------------------------------------------
  virtual task main_phase(uvm_phase phase);
    hpdcache_txn       item;
  

    item = hpdcache_txn::type_id::create("item");
    // -------------------------------------
    // Create new sequence
    // start the base sequence here 
    // This base sequence needs to be overwritten in the test class 
    // --------------------------------------
    for (int i = 0; i < NREQUESTERS-1; i++) begin
      automatic int r = i;
      fork begin
        if(env.m_top_cfg.m_requester_enable[r]) begin
          `uvm_info("TEST BASE", "Start base sequence", UVM_LOW);
          
          // --------------------------------
          // Randomize transaction item
          // --------------------------------
          if ( !item.randomize() with { m_req_sid == r ;
                                        m_req_op dist {HPDCACHE_REQ_STORE := 50, HPDCACHE_REQ_LOAD := 50};} )
            `uvm_fatal("body","Randomization failed");

          m_seq[r].item = item; 
          m_seq[r].start(env.m_hpdcache[r].m_sequencer);
          // --------------------------------
          // Randomize transaction item
          // --------------------------------
          if ( !item.randomize() with { m_req_sid == r ;
                                        m_req_op dist {HPDCACHE_REQ_STORE := 50, HPDCACHE_REQ_LOAD := 50};} )
            `uvm_fatal("body","Randomization failed");

          m_seq[r].item = item; 
          m_seq[r].start(env.m_hpdcache[r].m_sequencer);
        end
      end join_none
    end
    super.main_phase(phase); 


  endtask;
endclass: test_hpdcache_generic_request

`endif // __test_hpdcache_multiple_generic_requests_SVH__
