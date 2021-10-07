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
//                This test runs random load/store intertwine with AMOs
// ----------------------------------------------------------------------------

`ifndef __test_hpdcache_multiple_load_store_requests_SVH__
`define __test_hpdcache_multiple_load_store_requests_SVH__

class test_hpdcache_multiple_load_store_requests extends test_hpdcache_multiple_random_requests;

  `uvm_component_utils(test_hpdcache_multiple_load_store_requests)

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    set_type_override_by_type(hpdcache_txn::get_type(), hpdcache_load_store_with_amos_txn::get_type());
  endfunction: new

endclass: test_hpdcache_multiple_load_store_requests

`endif // __test_hpdcache_multiple_load_store_requests_SVH__
