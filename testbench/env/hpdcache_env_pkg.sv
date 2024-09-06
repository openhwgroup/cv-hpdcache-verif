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
//  Description : UVM environement package
// ----------------------------------------------------------------------------
package hpdcache_env_pkg;
  
  timeunit 1ns;

  `include "uvm_macros.svh"


  import uvm_pkg::*;
  import hpdcache_pkg::*;
  import hpdcache_common_pkg::*;
  import hpdcache_agent_pkg::*;
  import dram_mon_agent_pkg::*;
  import conf_and_perf_pkg::*;
  import clock_driver_pkg::*;
  import pulse_gen_pkg::*;
  import bp_driver_pkg::*;
  import reset_driver_pkg::*;
  import watchdog_pkg::*;
  import memory_rsp_model_pkg::*;
  import memory_partitions_pkg::*;
  import perf_mon_pkg::*;
`ifdef AXI2MEM 
  import axi2mem_pkg::*;
`endif
  // import memory_shadow_pkg::*;
  `include "../hwpf_stride_cfg/hwpf_stride_cfg_c.svh"
  `include "../hwpf_stride_cfg/cacheability_cfg_c.svh"
  `include "../hwpf_stride_cfg/status_c.svh"
  `include "hpdcache_top_cfg.svh"
  `include "hpdcache_sb.svh"
  `include "hwpf_stride_sb.svh"
  `include "hpdcache_env.svh"
  
endpackage : hpdcache_env_pkg
