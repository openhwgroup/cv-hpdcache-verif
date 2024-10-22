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
// *  Description   : conf and perf  if
// ----------------------------------------------------------------------------

import hpdcache_pkg::*;
import hpdcache_common_pkg::*;
interface perf_if (input bit clk_i, input bit rst_ni);
    //      Performance events
    logic   evt_cache_write_miss_o;
    logic   evt_cache_read_miss_o;
    logic   evt_uncached_req_o;
    logic   evt_cmo_req_o;
    logic   evt_write_req_o;
    logic   evt_read_req_o;
    logic   evt_granted_req_o;
    logic   evt_req_on_hold_o;
    logic   evt_rtab_rollback_o;
    logic   evt_stall_refill_o;
    logic   evt_stall_o;
   

    int   cnt_cache_write_miss;
    int   cnt_cache_read_miss;
    int   cnt_uncached_req;
    int   cnt_cmo_req;
    int   cnt_write_req;
    int   cnt_read_req;
    int   cnt_granted_req;
    int   cnt_req_on_hold;

    evt_cache_write_miss_o_assert     : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( evt_cache_write_miss_o ) );
    evt_cache_read_miss_o_assert      : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( evt_cache_read_miss_o  ) );
    evt_uncached_req_o_assert         : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( evt_uncached_req_o     ) );
    evt_cmo_req_o_assert              : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( evt_cmo_req_o          ) );
    evt_write_req_o_assert            : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( evt_write_req_o        ) );
    evt_read_req_o_uncacheable_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( evt_read_req_o         ) );
    evt_granted_req_o_assert          : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( evt_granted_req_o      ) );
    evt_req_on_hold_o_assert          : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( evt_req_on_hold_o      ) );

    //      Status interface
    logic   wbuf_empty_o;

    wbuf_empty_o_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( wbuf_empty_o ) );


   // ----------------------------
   // performance counters 
   // ----------------------------
   always @ ( posedge clk_i ) begin

     if ( ~rst_ni ) begin
       cnt_cache_write_miss <= 0 ;
       cnt_cache_read_miss  <= 0 ;
       cnt_uncached_req     <= 0 ;
       cnt_cmo_req          <= 0 ;
       cnt_write_req        <= 0 ;
       cnt_read_req         <= 0 ;
       cnt_granted_req      <= 0 ;
       cnt_req_on_hold      <= 0 ;
     end else begin
       if(evt_cache_write_miss_o ) cnt_cache_write_miss<= cnt_cache_write_miss + 1  ;
       if(evt_cache_read_miss_o  ) cnt_cache_read_miss <= cnt_cache_read_miss + 1   ;
       if(evt_uncached_req_o     ) cnt_uncached_req    <= cnt_uncached_req + 1      ;
       if(evt_cmo_req_o          ) cnt_cmo_req         <= cnt_cmo_req + 1           ;
       if(evt_write_req_o        ) cnt_write_req       <= cnt_write_req + 1         ;
       if(evt_read_req_o         ) cnt_read_req        <= cnt_read_req + 1          ;
       if(evt_granted_req_o      ) cnt_granted_req     <= cnt_granted_req + 1       ;
       if(evt_req_on_hold_o      ) cnt_req_on_hold     <= cnt_req_on_hold + 1       ;
     end
   end
    

endinterface

interface conf_if (input bit clk_i, input bit rst_ni);
    //      Configuration interface
    logic              cfg_enable_i;
    wbuf_timecnt_t     cfg_wbuf_threshold_i;
    logic              cfg_wbuf_reset_timecnt_on_write_i;
    logic              cfg_wbuf_sequential_waw_i;
    logic              cfg_wbuf_inhibit_write_coalescing_i;
    logic              cfg_hwpf_stride_updt_plru_i;
    hpdcache_req_sid_t cfg_hwpf_stride_sid_i;
    logic              cfg_error_on_cacheable_amo_i;
    logic              cfg_rtab_single_entry_i;
    logic              cfg_default_wb_i;

    cfg_enable_i_assert                      : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( cfg_enable_i              ) );
    cfg_wbuf_threshold_i_assert              : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( cfg_wbuf_threshold_i              ) );
    cfg_wbuf_reset_timecnt_on_write_i_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( cfg_wbuf_reset_timecnt_on_write_i ) );
    cfg_wbuf_sequential_waw_i_assert         : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( cfg_wbuf_sequential_waw_i         ) );
    cfg_hwpf_stride_updt_plru_i_assert       : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( cfg_hwpf_stride_updt_plru_i          ) );
  //  cfg_hwpf_stride_sid_i_assert             : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( cfg_hwpf_stride_sid_i                ) );
    cfg_error_on_cacheable_amo_i_assert      : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( cfg_error_on_cacheable_amo_i      ) );
    cfg_rtab_single_entry_i_assert           : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( cfg_rtab_single_entry_i           ) );
    cfg_default_wb_i_assert                  : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( cfg_default_wb_i           ) );

endinterface
