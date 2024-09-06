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
//  Description : This is a directed to predict the behaviour of PLRU  
// ----------------------------------------------------------------------------

`ifndef __test_hpdcache_multiple_directed_addr_bPLRU_prediction_SVH__
`define __test_hpdcache_multiple_directed_addr_bPLRU_prediction_SVH__

class test_hpdcache_multiple_directed_addr_bPLRU_prediction extends test_hpdcache_multiple_directed_addr;

  `uvm_component_utils(test_hpdcache_multiple_directed_addr_bPLRU_prediction)

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    set_type_override_by_type(hpdcache_txn::get_type(), hpdcache_bPLRU_txn::get_type());    
    set_type_override_by_type(hpdcache_top_cfg::get_type(), hpdcache_bPLRU_cfg::get_type()); 
    set_type_override_by_type(hpdcache_conf_txn::get_type(), hpdcache_conf_bPLRU::get_type() );
  endfunction: new

  function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase); 
    // If the randomization is done the config phase, it doesn't work
    if ( !env.m_rsp_cfg.randomize() with
          {
            m_enable        == 1'b1;
            rsp_mode        == ZERO_DELAY_RSP;
          } )
    begin    
      `uvm_error("End of elaboration", "Randomization of config failed");
    end

  endfunction 
endclass: test_hpdcache_multiple_directed_addr_bPLRU_prediction

`endif // __test_hpdcache_multiple_directed_addr_bPLRU_prediction_SVH__
