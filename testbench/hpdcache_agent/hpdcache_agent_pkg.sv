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

package hpdcache_agent_pkg;
  timeunit 1ns;
  timeprecision 1ps;
 
import uvm_pkg::*;
import hpdcache_pkg::*;
import hpdcache_common_pkg::*;
import memory_partitions_pkg::*;
`include "uvm_macros.svh"

   `include "hpdcache_txn.svh" 
   `include "hpdcache_covergroups.svh" 
   `include "hpdcache_driver.svh"
   `include "hpdcache_sequencer.svh"
   `include "hpdcache_sequences.svh"
   `include "hpdcache_monitor.svh"
   `include "hpdcache_agent.svh" 
endpackage
