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
// ----------------------------------------------------------------------------
interface hwpf_stride_cfg_if (input bit clk, input bit rst_ni);

    import hpdcache_pkg::*;
    import hpdcache_common_pkg::*;
    import hwpf_stride_pkg::*;

    logic             [NUM_HW_PREFETCH-1:0]  base_set           ;
    logic             [NUM_HW_PREFETCH-1:0]  param_set          ;
    logic             [NUM_HW_PREFETCH-1:0]  throttle_set       ;
    hwpf_stride_cfg_t [NUM_HW_PREFETCH-1:0]  hwpf_stride_cfg    ;
    hwpf_stride_status_t                     hwpf_stride_status ;

    hpdcache_nline_t    [NUM_SNOOP_PORTS-1:0] snoop_addr  ;
    logic               [NUM_SNOOP_PORTS-1:0] snoop_valid ;

endinterface
