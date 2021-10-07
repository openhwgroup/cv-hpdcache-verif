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

package dram_mon_agent_pkg;
  timeunit 1ns;
  timeprecision 1ps;
 
import uvm_pkg::*;
import hpdcache_pkg::*;
import hpdcache_common_pkg::*;




`include "uvm_macros.svh"
    typedef enum {
       NEVER,
       LIGHT, 
       MEDIUM,
       HEAVY
    } bp_t;

   `include "dram_mon_cfg.svh"
   `include "dram_mon_fifo.svh"
   `include "dram_monitor.svh" 
   `include "dram_mon_agent.svh"

endpackage
