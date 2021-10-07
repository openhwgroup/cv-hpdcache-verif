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
//  Description : Package for the HPDCACHE UVM test
// ----------------------------------------------------------------------------

package hpdcache_test_pkg;
  // import UVM utilities
  import uvm_pkg::*;
  import hpdcache_pkg::*;
  import hpdcache_agent_pkg::*;
  import hpdcache_env_pkg::*;
  import conf_and_perf_pkg::*;
  import hpdcache_common_pkg::*;
  import memory_rsp_model_pkg::*;
  import memory_partitions_pkg::*;

  
  `include "uvm_macros.svh"

  // Include definition of tests
  `include "test_base.svh"

  // Basic tests
  `include "basic_tests/hpdcache_generic_request.svh"
  `include "basic_tests/hpdcache_multiple_directed_addr.svh"
  `include "basic_tests/hpdcache_multiple_directed_addr_bPLRU_prediction.svh"
  `include "basic_tests/hpdcache_multiple_random_requests.svh"
  `include "basic_tests/hpdcache_multiple_load_store_requests.svh"
  `include "basic_tests/hpdcache_multiple_random_requests_in_region.svh"
  `include "basic_tests/hpdcache_multiple_load_store_requests_in_region.svh"
  `include "basic_tests/hpdcache_multiple_amo_lr_sc_requests.svh"
  `include "basic_tests/hpdcache_multiple_random_requests_uncached.svh"

  `include "congestion_tests/memory_bp/hpdcache_multiple_random_requests_in_region_with_memory_bp.svh"
  `include "congestion_tests/memory_bp/hpdcache_multiple_random_requests_with_memory_bp.svh"
  `include "congestion_tests/memory_bp/hpdcache_multiple_consecutive_set_load_with_memory_bp.svh"
  `include "congestion_tests/memory_bp/hpdcache_multiple_consecutive_set_store_with_memory_bp.svh"
  `include "congestion_tests/memory_bp/hpdcache_multiple_same_tag_set_store_with_memory_bp.svh"
  `include "congestion_tests/memory_bp/hpdcache_multiple_same_tag_set_store_random_threshold_no_reset_timecnt_with_memory_bp.svh"
  `include "congestion_tests/memory_bp/hpdcache_multiple_same_tag_set_store_random_threshold_reset_timecnt_with_memory_bp.svh"
  
  `include "congestion_tests/ready_bp/hpdcache_multiple_random_requests_in_region_with_ready_bp.svh"
  `include "congestion_tests/ready_bp/hpdcache_multiple_random_requests_with_ready_bp.svh"
  `include "congestion_tests/ready_bp/hpdcache_multiple_consecutive_set_load_with_ready_bp.svh"
  `include "congestion_tests/ready_bp/hpdcache_multiple_consecutive_set_store_with_ready_bp.svh"
  `include "congestion_tests/ready_bp/hpdcache_multiple_same_tag_set_store_with_ready_bp.svh"
  `include "congestion_tests/ready_bp/hpdcache_multiple_same_tag_set_store_random_threshold_no_reset_timecnt_with_ready_bp.svh"
  `include "congestion_tests/ready_bp/hpdcache_multiple_same_tag_set_store_random_threshold_reset_timecnt_with_ready_bp.svh"

  `include "performance_tests/hpdcache_multiple_cacheable_load_only_performance_check_no_memory_bp.svh"
  `include "performance_tests/hpdcache_multiple_cacheable_load_only_performance_check_with_memory_bp.svh"
  `include "performance_tests/hpdcache_multiple_cacheable_store_only_performance_check_no_memory_bp.svh"
  `include "performance_tests/hpdcache_multiple_cacheable_load_store_only_performance_check_no_memory_bp.svh"

  // Prefetcher tests
  `include "hwpf_stride_tests/hpdcache_random_hwpf_stride.svh"
  `include "hwpf_stride_tests/hpdcache_coverage_extreme_values.svh"
  `include "hwpf_stride_tests/hpdcache_coverage_extreme_nblocks.svh"
  `include "hwpf_stride_tests/hpdcache_coverage_extreme_nlines.svh"
  `include "hwpf_stride_tests/hpdcache_coverage_extreme_nwait.svh"
  `include "hwpf_stride_tests/hpdcache_config_while_busy.svh"
  `include "hwpf_stride_tests/hpdcache_abort_hwpf_stride.svh"
  `include "hwpf_stride_tests/hpdcache_abort_while_sending.svh"
  `include "hwpf_stride_tests/hpdcache_abort_while_waiting.svh"
  `include "hwpf_stride_tests/hpdcache_abort_while_done.svh"
  `include "hwpf_stride_tests/hpdcache_max_address_hwpf_stride.svh"
  `include "hwpf_stride_tests/hpdcache_start_disabled_rearmed_hwpf_stride.svh"
  `include "hwpf_stride_tests/hpdcache_all_hwpf_strides_each_requesters.svh"
  `include "hwpf_stride_tests/hpdcache_multiple_random_hwpf_strides.svh"
  `include "hwpf_stride_tests/hpdcache_multiple_directed_addr_with_multiple_hwpf_stride.svh"
  `include "hwpf_stride_tests/hpdcache_multiple_directed_addr_with_multiple_hwpf_stride_at_same_addr.svh"

  `include "hwpf_stride_tests/hpdcache_reset_on_the_fly.svh"

endpackage: hpdcache_test_pkg

