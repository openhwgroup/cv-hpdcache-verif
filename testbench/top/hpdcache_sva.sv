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

`include "hpdcache_typedef.svh"

module hpdcache_SVA
import hpdcache_pkg::*;
import hpdcache_common_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t hpdcacheCfg = '0,

    parameter type wbuf_timecnt_t = logic,

    //  Request Interface Definitions
    //  {{{
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_data_word_t = logic,
    parameter type hpdcache_data_be_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    //  }}}

    //  Memory Interface Definitions
    //  {{{
    parameter type hpdcache_mem_addr_t = logic,
    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_data_t = logic,
    parameter type hpdcache_mem_be_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic
    //  }}}
)
    //  }}}

    //  Ports
    //  {{{
(
    //      Clock and reset signals
    input  logic                          clk_i,
    input  logic                          rst_ni,

    //      Force the write buffer to send all pending writes
    input  logic                          wbuf_flush_i,

    //      Core request interface
    //         1st cycle
    input  logic                          core_req_valid_i [hpdcacheCfg.u.nRequesters-1:0],
    input logic                           core_req_ready_o [hpdcacheCfg.u.nRequesters-1:0],
    input  hpdcache_req_t                 core_req_i       [hpdcacheCfg.u.nRequesters-1:0],
    //         2nd cycle
    input  logic                          core_req_abort_i [hpdcacheCfg.u.nRequesters-1:0],
    input  hpdcache_tag_t                 core_req_tag_i   [hpdcacheCfg.u.nRequesters-1:0],
    input  hpdcache_pma_t                 core_req_pma_i   [hpdcacheCfg.u.nRequesters-1:0],

    //      Core response interface
    input logic                          core_rsp_valid_o [hpdcacheCfg.u.nRequesters-1:0],
    input hpdcache_rsp_t                 core_rsp_o       [hpdcacheCfg.u.nRequesters-1:0],

    //      Miss read / invalidation interface
    input  logic                          mem_req_read_ready_i,
    input logic                           mem_req_read_valid_o,
    input hpdcache_mem_req_t              mem_req_read_o,

    input logic                           mem_resp_read_ready_o,
    input  logic                          mem_resp_read_valid_i,
    input  hpdcache_mem_resp_r_t          mem_resp_read_i,
`ifdef HPDCACHE_OPENPITON
    input  logic                          mem_resp_read_inval_i,
    input  hpdcache_nline_t               mem_resp_read_inval_nline_i,
`endif

    //      Write-buffer write interface
    input  logic                          mem_req_write_ready_i,
    input logic                           mem_req_write_valid_o,
    input hpdcache_mem_req_t              mem_req_write_o,

    input  logic                          mem_req_write_data_ready_i,
    input logic                           mem_req_write_data_valid_o,
    input hpdcache_mem_req_w_t            mem_req_write_data_o,

    input logic                           mem_resp_write_ready_o,
    input  logic                          mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t          mem_resp_write_i,

    //      Performance events
    input logic                          evt_cache_write_miss_o,
    input logic                          evt_cache_read_miss_o,
    input logic                          evt_uncached_req_o,
    input logic                          evt_cmo_req_o,
    input logic                          evt_write_req_o,
    input logic                          evt_read_req_o,
    input logic                          evt_prefetch_req_o,
    input logic                          evt_req_on_hold_o,
    input logic                          evt_rtab_rollback_o,
    input logic                          evt_stall_refill_o,
    input logic                          evt_stall_o,

    //      Status interface
    input logic                          wbuf_empty_o,

    //      Configuration interface
    input  logic                          cfg_enable_i,
    input  wbuf_timecnt_t                 cfg_wbuf_threshold_i,
    input  logic                          cfg_wbuf_reset_timecnt_on_write_i,
    input  logic                          cfg_wbuf_sequential_waw_i,
    input  logic                          cfg_wbuf_inhibit_write_coalescing_i,
    input  logic                          cfg_prefetch_updt_plru_i,
    input  logic                          cfg_error_on_cacheable_amo_i,
    input  logic                          cfg_rtab_single_entry_i,
    input  logic                          cfg_default_wb_i,

    // Internal signals
    input logic miss_mshr_empty,
    input logic ctrl_empty, rtab_empty,
 
    input logic arb_req_valid, arb_req_ready, core_rsp_valid,
    input logic miss_mshr_alloc,
    input logic miss_mshr_alloc_ready,
    input logic miss_mshr_check,
    input logic miss_mshr_alloc_full,
    input logic refill_req_valid,
    input logic refill_req_ready,
    input hpdcache_req_t arb_req,
    input hpdcache_rsp_t core_rsp
);

 localparam int unsigned HPDCACHE_OFFSET_WIDTH   = $clog2(hpdcacheCfg.u.wordWidth*hpdcacheCfg.u.clWords/8);

  logic post_shutdown_phase; 



  genvar itr_wbuf;

  // --------------------------------------------------
  // EOT FSM CHECKS::enum for the fms are defined within the module and
  // are not visible outside the scop of the module
  // --------------------------------------------------
//  generate
//  for(itr_wbuf = 0; itr_wbuf < HPDCACHE_WBUF_DIR_ENTRIES; itr_wbuf++) begin: fsm_wbuf_eot
//    wbuf_dir_state_eot_check : assert property 
//     (  @( posedge post_shutdown_phase )
//         (  dcache_wbuf_i.wbuf_dir_state_q[itr_wbuf] == BUF_FREE) )
//     else $error("At post shutdown dcache wbuf is not FREE");
//    wbuf_dir_state_rst_check : assert property 
//     (  @( posedge clk_i)
//         ( rst_ni == 0 |->  dcache_wbuf_i.wbuf_dir_state_q[itr_wbuf] == BUF_FREE) )
//     else $error("Under reset dcache wbuf is not FREE");
//  end
//  endgenerate 
//  
//  cmoh_fsm_q_eot_check : assert property 
//   (  @( posedge post_shutdown_phase )
//       (  dcache_cmo_i.cmoh_fsm_q == CMOH_IDLE) )
//   else $error("At post shutdown dcache cmoh_fsm_q is not CMOH_IDLE");
//
//  cmoh_fsm_q_rst_check : assert property 
//     (  @( posedge clk_i)
//       ( rst_ni == 0 |->  dcache_cmo_i.cmoh_fsm_q == CMOH_IDLE) )
//   else $error("Under reset dcache cmoh_fsm_q is not CMOH_IDLE");
//
//  miss_req_fsm_eot_check : assert property 
//   (  @( posedge post_shutdown_phase )
//       (  dcacche_miss_handler_i.miss_req_fsm_q == MISS_REQ_IDLE) )
//   else $error("At post shutdown dcache miss_req_fsm is not MISS_REQ_IDLE");
//
//  miss_req_fsm_rst_check : assert property 
//     (  @( posedge clk_i)
//       ( rst_ni == 0 |->  dcacche_miss_handler_i.miss_req_fsm_q == MISS_REQ_IDLE) )
//   else $error("Under rst dcache miss_req_fsm is not MISS_REQ_IDLE");
//
//  refill_fsm_eot_check : assert property 
//   (  @( posedge post_shutdown_phase )
//       (  dcacche_miss_handler_i.refill_fsm_q == REFILL_IDLE) )
//   else $error("At post shutdown dcache refill_fsm is not REFILL_IDLE");
//
//  refill_fsm_rst_check : assert property 
//     (  @( posedge clk_i)
//       ( rst_ni == 0 |->  dcacche_miss_handler_i.refill_fsm_q == REFILL_IDLE) )
//   else $error("Under rst dcache refill_fsm is not REFILL_IDLE");
//
//  // --------------------------------------------------
 

 wbuf_empty_eot_check : assert property 
 (  @( posedge post_shutdown_phase)
    ( wbuf_empty_o == 1'b1 ) )
    else $error("At post shutdown wbuf is not empty");

 mshr_empty_eot_check : assert property 
 (  @( posedge post_shutdown_phase)
    ( miss_mshr_empty == 1'b1 ) )
    else $error("At post shutdown mshr is not empty");

 rtab_empty_eot_check : assert property 
 (  @( posedge post_shutdown_phase)
    ( rtab_empty == 1'b1 ) )
    else $error("At post shutdown rtab is not empty");

 ctrl_empty_eot_check : assert property 
 (  @( posedge post_shutdown_phase )
    ( ctrl_empty == 1'b1 ) )
    else $error("At post shutdown ctrl is not empty");

 wbuf_empty_rst_check : assert property 
 (  @( posedge clk_i)
    ( rst_ni == 0 |-> wbuf_empty_o == 1'b1 ) )
    else $error("At post shutdown wbuf is not empty");

 mshr_empty_rst_check : assert property 
 (  @( posedge clk_i)
    ( rst_ni == 0 |-> miss_mshr_empty == 1'b1 ) )
    else $error("At post shutdown mshr is not empty");

 rtab_empty_rst_check : assert property 
 (  @( posedge clk_i)
    ( rst_ni == 0 |-> rtab_empty == 1'b1 ) )
    else $error("At post shutdown rtab is not empty");

 ctrl_empty_rst_check : assert property 
 (  @( posedge clk_i)
    ( rst_ni == 0 |-> ctrl_empty == 1'b1 ) )
    else $error("At post shutdown ctrl is not empty");

  genvar i;
  generate
    for ( genvar i = 0 ; i < hpdcacheCfg.u.nRequesters -1 ; i++ ) begin
      /* pragma translate_off */
      assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( core_req_valid_i[i] ) );
      assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( core_req_ready_o[i] ) );

      assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i[i] ) -> !$isunknown( core_req_i[i].addr_offset ) );
      assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i[i] ) -> !$isunknown( core_req_i[i].addr_tag    ) );
      assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i[i] ) -> !$isunknown( core_req_i[i].wdata       ) );
      assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i[i] ) -> !$isunknown( core_req_i[i].op          ) );
      assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i[i] ) -> !$isunknown( core_req_i[i].be          ) );
      assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i[i] ) -> !$isunknown( core_req_i[i].size        ) );
      assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i[i] ) -> !$isunknown( core_req_i[i].pma.uncacheable ) );
      assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i[i] ) -> !$isunknown( core_req_i[i].sid         ) );
      assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i[i] ) -> !$isunknown( core_req_i[i].tid         ) );
      assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i[i] ) -> !$isunknown( core_req_i[i].need_rsp    ) );

      assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( core_rsp_valid_o[i] ) );

      // assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_rsp_valid_o[i] ) -> !$isunknown( core_rsp_o[i].rdata ) );
      assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_rsp_valid_o[i] ) -> !$isunknown( core_rsp_o[i].sid   ) );
      assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_rsp_valid_o[i] ) -> !$isunknown( core_rsp_o[i].tid   ) );
      assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_rsp_valid_o[i] ) -> !$isunknown( core_rsp_o[i].error ) );

      /* pragma translate_on */
 
    end
  endgenerate
  // -------------------------------------------------------------------------
  //      read req interface
  // -------------------------------------------------------------------------
  /* pragma translate_off */
  mem_req_read_valid_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    !$isunknown( mem_req_read_valid_o ) );
  mem_req_read_ready_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    !$isunknown( mem_req_read_ready_i ) );

  mem_req_read_addr_assert      :  assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_read_valid_o && mem_req_read_ready_i ) -> !$isunknown( mem_req_read_o.mem_req_addr ) );
  mem_req_read_len_assert       :  assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_read_valid_o && mem_req_read_ready_i ) -> !$isunknown( mem_req_read_o.mem_req_len ) );
  mem_req_read_size_assert      :  assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_read_valid_o && mem_req_read_ready_i ) -> !$isunknown( mem_req_read_o.mem_req_size ) );
  mem_req_read_id_assert        :  assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_read_valid_o && mem_req_read_ready_i ) -> !$isunknown( mem_req_read_o.mem_req_id ) );
  mem_req_read_command_assert   :  assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_read_valid_o && mem_req_read_ready_i ) -> !$isunknown( mem_req_read_o.mem_req_command ) );
  mem_req_read_atom_assert      :  assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_read_valid_o && mem_req_read_ready_i ) -> !$isunknown( mem_req_read_o.mem_req_atomic ) );
  mem_req_read_cacheable_assert :  assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_read_valid_o && mem_req_read_ready_i ) -> !$isunknown( mem_req_read_o.mem_req_cacheable ) );
  /* pragma translate_on */


  // -------------------------------------------------------------------------
  //      read resp interface
  // -------------------------------------------------------------------------
  /* pragma translate_off */
  mem_resp_read_ready_assert     : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    !$isunknown( mem_resp_read_ready_o ) );
  mem_resp_read_valid_assert     : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    !$isunknown( mem_resp_read_valid_i ) );

  mem_resp_read_error_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_resp_read_ready_o && mem_resp_read_valid_i ) -> !$isunknown( mem_resp_read_i.mem_resp_r_error ) );
  mem_resp_read_id_assert    : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_resp_read_ready_o && mem_resp_read_valid_i ) -> !$isunknown( mem_resp_read_i.mem_resp_r_id ) );
  mem_resp_read_data_assert  : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_resp_read_ready_o && mem_resp_read_valid_i ) -> !$isunknown( mem_resp_read_i.mem_resp_r_data ) );
  mem_resp_read_last_assert  : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_resp_read_ready_o && mem_resp_read_valid_i ) -> !$isunknown( mem_resp_read_i.mem_resp_r_last ) );
  /* pragma translate_on */


  // -------------------------------------------------------------------------
  //      write req interface
  // -------------------------------------------------------------------------
  /* pragma translate_off */
  mem_req_write_valid_assert  : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    !$isunknown( mem_req_write_valid_o ) );
  mem_req_write_ready_assert  : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    !$isunknown( mem_req_write_ready_i ) );

  mem_req_write_addr_assert      : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_write_valid_o && mem_req_write_ready_i ) -> !$isunknown( mem_req_write_o.mem_req_addr ) );
  mem_req_write_len_assert       : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_write_valid_o && mem_req_write_ready_i ) -> !$isunknown( mem_req_write_o.mem_req_len ) );
  mem_req_write_size_assert      : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_write_valid_o && mem_req_write_ready_i ) -> !$isunknown( mem_req_write_o.mem_req_size ) );
  mem_req_write_id_assert        : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_write_valid_o && mem_req_write_ready_i ) -> !$isunknown( mem_req_write_o.mem_req_id ) );
  mem_req_write_command_assert   : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_write_valid_o && mem_req_write_ready_i ) -> !$isunknown( mem_req_write_o.mem_req_command ) );
  mem_req_write_atomic_assert    : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_write_valid_o && mem_req_write_ready_i ) -> !$isunknown( mem_req_write_o.mem_req_atomic ) );
  mem_req_write_cacheable_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_write_valid_o && mem_req_write_ready_i ) -> !$isunknown( mem_req_write_o.mem_req_cacheable ) );

  /* pragma translate_on */

  // -------------------------------------------------------------------------
  //      write data req interface
  // -------------------------------------------------------------------------
  /* pragma translate_off */
  mem_req_write_data_valid_assert  : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    !$isunknown( mem_req_write_data_valid_o ) );
  mem_req_write_data_ready_assert  : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    !$isunknown( mem_req_write_data_ready_i ) );

  mem_req_write_data_data_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_write_data_valid_o && mem_req_write_data_ready_i ) -> !$isunknown( mem_req_write_data_o.mem_req_w_data ) );
  mem_req_write_data_be_assert   : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_write_data_valid_o && mem_req_write_data_ready_i ) -> !$isunknown( mem_req_write_data_o.mem_req_w_be ) );
  mem_req_write_data_last_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_req_write_data_valid_o && mem_req_write_data_ready_i ) -> !$isunknown( mem_req_write_data_o.mem_req_w_last ) );
  /* pragma translate_on */


  // -------------------------------------------------------------------------
  //      write resp interface
  // -------------------------------------------------------------------------
  /* pragma translate_off */
  mem_resp_write_valid_assert  : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    !$isunknown( mem_resp_write_valid_i ) );
  mem_resp_write_ready_assert  : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    !$isunknown( mem_resp_write_ready_o ) );

  mem_resp_write_is_atomic_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_resp_write_valid_i && mem_resp_write_ready_o ) -> !$isunknown( mem_resp_write_i.mem_resp_w_is_atomic ) );
  mem_resp_write_error_assert     : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_resp_write_valid_i && mem_resp_write_ready_o ) -> !$isunknown( mem_resp_write_i.mem_resp_w_error ) );
  mem_resp_write_id_assert        : assert property ( @(posedge clk_i) disable iff(!rst_ni)
    ( mem_resp_write_valid_i && mem_resp_write_ready_o ) -> !$isunknown( mem_resp_write_i.mem_resp_w_id ) );
  /* pragma translate_on */

  /* pragma translate_off */

      // Ready is one hot 
      rr_aribter_read_onehot_check : assert property ( @(posedge clk_i) disable iff(!rst_ni)
         ($onehot0(core_req_ready_o) == 1)) else
           $error("More than one request is accepted at the same time");


  hpdcache_set_t  hpdcache_req_set; 
  hpdcache_tag_t  hpdcache_req_tag;
  hpdcache_word_t hpdcache_req_word;
  hpdcache_offset_t hpdcache_req_offset; 

  hpdcache_tag_t mem_rd_tag; 
  hpdcache_set_t mem_rd_set; 

  hpdcache_set_t mem_wr_set; 
  hpdcache_tag_t mem_wr_tag; 

  hpdcache_req_addr_t        addr_sva; 
  hpdcache_req_addr_t        addr_sva_aligned; 

  assign addr_sva              = {arb_req.addr_tag, arb_req.addr_offset};



  assign hpdcache_req_set    =  hpdcache_get_req_addr_set(addr_sva);
  assign hpdcache_req_tag    =  hpdcache_get_req_addr_tag(addr_sva);
  assign hpdcache_req_word   =  hpdcache_get_req_addr_word(addr_sva);

  assign hpdcache_req_offset =  addr_sva[HPDCACHE_OFFSET_WIDTH -1 :0];

  assign addr_sva_aligned[hpdcacheCfg.u.memAddrWidth -1 : HPDCACHE_OFFSET_WIDTH]    = addr_sva[hpdcacheCfg.u.memAddrWidth -1: HPDCACHE_OFFSET_WIDTH];
  assign addr_sva_aligned[HPDCACHE_OFFSET_WIDTH -1 :0]    = 0;

  assign mem_rd_set =  hpdcache_get_req_addr_set(mem_req_read_o.mem_req_addr);
  assign mem_rd_tag =  hpdcache_get_req_addr_tag(mem_req_read_o.mem_req_addr);

  assign mem_wr_set =  hpdcache_get_req_addr_set(mem_req_write_o.mem_req_addr);
  assign mem_wr_tag =  hpdcache_get_req_addr_tag(mem_req_write_o.mem_req_addr);


  genvar clk_delay_itr;
  generate 
    
    for(clk_delay_itr=0; clk_delay_itr<= 5 ; clk_delay_itr++) begin: clk_delay_itr_cached 

      // -----------------------------------------------------------------------
      // hpdcache request followed by miss read request on the same set and tag
      // with 0 to 5 clock cyccles 
      // -----------------------------------------------------------------------
      property mem_req_rd_miss_tmp_schmoo_0_prop;

        hpdcache_set_t set; 
        hpdcache_tag_t tag; 
        @( posedge clk_i )
 
        (arb_req_valid & arb_req_ready, set = hpdcache_req_set, tag = hpdcache_req_tag)   |-> ##clk_delay_itr (mem_req_read_valid_o & mem_req_read_ready_i & mem_rd_set == set & mem_rd_tag == tag & mem_req_read_o.mem_req_cacheable ==1) ;

      endproperty
      mem_req_rd_miss_tmp_schmoo_0_cov: cover property ( mem_req_rd_miss_tmp_schmoo_0_prop )
      if ($test$plusargs("+COVER_VERBOSE"))
      $display("[%2t] Event mem_req_rd_miss_tmp_schmoo_0_prop", $time );

      // -----------------------------------------------------------------------
      // miss read request followed by hpdcache request on the same set and tag
      // with 0 to 5 clock cycles 
      // -----------------------------------------------------------------------
      property mem_req_rd_miss_tmp_schmoo_1_prop;

        hpdcache_set_t set; 
        hpdcache_tag_t tag; 
        @( posedge clk_i )
 
       (mem_req_read_valid_o & mem_req_read_ready_i & mem_req_read_o.mem_req_cacheable ==1, set = mem_rd_set, tag = mem_rd_tag)  |-> ##clk_delay_itr (arb_req_valid & arb_req_ready & set == hpdcache_req_set & tag == hpdcache_req_tag);    

      endproperty
      mem_req_rd_miss_tmp_schmoo_1_cov: cover property ( mem_req_rd_miss_tmp_schmoo_1_prop )
      if ($test$plusargs("+COVER_VERBOSE"))
      $display("[%2t] Event mem_req_rd_miss_tmp_schmoo_1_prop", $time );

      // -----------------------------------------------------------------------
      // hpdcache request followed by miss read request on the same set and tag
      // with 0 to 5 clock cyccles 
      // -----------------------------------------------------------------------
      property mem_req_wr_wbuf_tmp_schmoo_0_prop;

        hpdcache_set_t set; 
        hpdcache_tag_t tag; 
        @( posedge clk_i )
 
        (arb_req_valid & arb_req_ready, set = hpdcache_req_set, tag = hpdcache_req_tag)   |-> ##clk_delay_itr (mem_req_write_valid_o & mem_req_write_ready_i & mem_wr_set == set & mem_wr_tag == tag & mem_req_write_o.mem_req_cacheable ==1) ;

      endproperty
      mem_req_wr_wbuf_tmp_schmoo_0_cov: cover property ( mem_req_wr_wbuf_tmp_schmoo_0_prop )
      if ($test$plusargs("+COVER_VERBOSE"))
      $display("[%2t] Event mem_req_wr_wbuf_tmp_schmoo_0_prop", $time );

      // -----------------------------------------------------------------------
      // miss read request followed by hpdcache request on the same set and tag
      // with 0 to 5 clock cycles 
      // -----------------------------------------------------------------------
      property mem_req_wr_wbuf_tmp_schmoo_1_prop;

        hpdcache_set_t set; 
        hpdcache_tag_t tag; 
        @( posedge clk_i )
 
       (mem_req_write_valid_o & mem_req_write_ready_i & mem_req_write_o.mem_req_cacheable ==1, set = mem_wr_set, tag = mem_wr_tag)  |-> ##clk_delay_itr (arb_req_valid & arb_req_ready & set == hpdcache_req_set & tag == hpdcache_req_tag);    

      endproperty
      mem_req_wr_wbuf_tmp_schmoo_1_cov: cover property ( mem_req_wr_wbuf_tmp_schmoo_1_prop )
      if ($test$plusargs("+COVER_VERBOSE"))
      $display("[%2t] Event mem_req_wr_wbuf_tmp_schmoo_1_prop", $time );

    end // for


    for(clk_delay_itr=0; clk_delay_itr<= 5 ; clk_delay_itr++) begin: clk_delay_itr_uncached
      // -----------------------------------------------------------------------
      // hpdcache request followed by uc read request on the same set and tag
      // with 0 to 5 clock cyccles 
      // -----------------------------------------------------------------------
      property mem_req_rd_uc_tmp_schmoo_0_prop;

        hpdcache_set_t set; 
        hpdcache_tag_t tag; 
        @( posedge clk_i )
 
        (arb_req_valid & arb_req_ready, set = hpdcache_req_set, tag = hpdcache_req_tag)   |-> ##clk_delay_itr (mem_req_read_valid_o & mem_req_read_ready_i & mem_rd_set == set & mem_rd_tag == tag & mem_req_read_o.mem_req_cacheable ==0) ;

      endproperty
      mem_req_rd_uc_tmp_schmoo_0_cov: cover property ( mem_req_rd_uc_tmp_schmoo_0_prop )
      if ($test$plusargs("+COVER_VERBOSE"))
      $display("[%2t] Event mem_req_rd_uc_tmp_schmoo_0_prop", $time );

     // -----------------------------------------------------------------------
     // uc read request followed by hpdcache request on the same set and tag
     // with 0 to 5 clock cycles 
     // -----------------------------------------------------------------------
      property mem_req_rd_uc_tmp_schmoo_1_prop;

        hpdcache_set_t set; 
        hpdcache_tag_t tag; 
        @( posedge clk_i )
 
       (mem_req_read_valid_o & mem_req_read_ready_i & mem_req_read_o.mem_req_cacheable ==0, set = mem_rd_set, tag = mem_rd_tag)  |-> ##clk_delay_itr (arb_req_valid & arb_req_ready & set == hpdcache_req_set & tag == hpdcache_req_tag);    

      endproperty
      mem_req_rd_uc_tmp_schmoo_1_cov: cover property ( mem_req_rd_uc_tmp_schmoo_1_prop )
      if ($test$plusargs("+COVER_VERBOSE"))
      $display("[%2t] Event mem_req_rd_uc_tmp_schmoo_1_prop", $time );





      // -----------------------------------------------------------------------
      // hpdcache request followed by uc read request on the same set and tag
      // with 0 to 5 clock cyccles 
      // -----------------------------------------------------------------------
      property mem_req_wr_uc_tmp_schmoo_0_prop;

        hpdcache_set_t set; 
        hpdcache_tag_t tag; 
        @( posedge clk_i )
 
        (arb_req_valid & arb_req_ready, set = hpdcache_req_set, tag = hpdcache_req_tag)   |-> ##clk_delay_itr (mem_req_write_valid_o & mem_req_write_ready_i & mem_wr_set == set & mem_wr_tag == tag & mem_req_write_o.mem_req_cacheable ==0) ;

      endproperty
      mem_req_wr_uc_tmp_schmoo_0_cov: cover property ( mem_req_wr_uc_tmp_schmoo_0_prop )
      if ($test$plusargs("+COVER_VERBOSE"))
      $display("[%2t] Event mem_req_wr_uc_tmp_schmoo_0_prop", $time );

      // -----------------------------------------------------------------------
      // uc read request followed by hpdcache request on the same set and tag
      // with 0 to 5 clock cycles 
      // -----------------------------------------------------------------------
      property mem_req_wr_uc_tmp_schmoo_1_prop;

        hpdcache_set_t         set; 
        hpdcache_tag_t         tag; 
        @( posedge clk_i )
 
       (mem_req_write_valid_o & mem_req_write_ready_i & mem_req_write_o.mem_req_cacheable ==0, set = mem_wr_set, tag = mem_wr_tag)  |-> ##clk_delay_itr (arb_req_valid & arb_req_ready & set == hpdcache_req_set & tag == hpdcache_req_tag);    

      endproperty
      mem_req_wr_uc_tmp_schmoo_1_cov: cover property ( mem_req_wr_uc_tmp_schmoo_1_prop )
      if ($test$plusargs("+COVER_VERBOSE"))
      $display("[%2t] Event mem_req_wr_uc_tmp_schmoo_1_prop", $time );

    end // for

  endgenerate 

  sequence hpdcache_req(local input hpdcache_req_op_t op);
    arb_req_valid & arb_req_ready & (arb_req.op == op);
  endsequence
  sequence hpdcache_amo_req(local input hpdcache_req_op_t op);
    arb_req_valid & arb_req_ready & (is_amo(arb_req.op));
  endsequence

  // Sequence to cover load/store error response followed by LOAD/AMO no error 
  sequence load_req_with_error_rsp;
    hpdcache_req_tid_t     tid;
    @( posedge clk_i )
    hpdcache_req(HPDCACHE_REQ_LOAD) ##0 ((arb_req.need_rsp == 1), tid = arb_req.tid)  ##[1:100] $rose(core_rsp_valid) ##0 (core_rsp.tid == tid && core_rsp.error == 1);
  endsequence 

  sequence store_req_with_error_rsp;
    hpdcache_req_tid_t     tid;
    @( posedge clk_i )
    hpdcache_req(HPDCACHE_REQ_STORE) ##0 ((arb_req.need_rsp == 1), tid = arb_req.tid)  ##[1:100] $rose(core_rsp_valid) ##0 (core_rsp.tid == tid && core_rsp.error == 1);
  endsequence 

  sequence load_req_no_rsp;
    hpdcache_req_tid_t     tid;
    @( posedge clk_i )
    arb_req_valid & arb_req_ready & (arb_req.op == HPDCACHE_REQ_LOAD) & (arb_req.need_rsp == 0);
  endsequence 

  // store with error rsp followed by need_rsp == 0 load
  property err_store_no_rsp_load;

    @( posedge clk_i )
    store_req_with_error_rsp and 
    ##[1:100] load_req_no_rsp; 
  endproperty
  err_store_no_rsp_load_cov: cover property ( err_store_no_rsp_load )
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%2t] Event err_store_no_rsp_load", $time );

  // load with error rsp is followed by need_rsp == 0 load
  property err_load_no_rsp_load;

    @( posedge clk_i )
    load_req_with_error_rsp and 
    ##[1:100] load_req_no_rsp; 
  endproperty
  err_load_no_rsp_load_cov: cover property ( err_load_no_rsp_load )
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%2t] Event err_load_no_rsp_load", $time );


  property lr_sc_fail_1;
    hpdcache_req_addr_t    addr;
    hpdcache_offset_t      offset;
        
    @( posedge clk_i )
    (hpdcache_req(HPDCACHE_REQ_AMO_LR), addr = addr_sva_aligned, offset = (hpdcache_req_offset >> 3) << 3)  
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_AMO_SC) 
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] == addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH]) & (offset != (hpdcache_req_offset >> 3) << 3);
  endproperty 
  lr_sc_fail_1_cov: cover property ( lr_sc_fail_1 )
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%2t] Event lr_sc_fail_1", $time );

  property lr_sc_fail_2;
    hpdcache_req_addr_t    addr;
    hpdcache_offset_t      offset;
        
    @( posedge clk_i )
    (hpdcache_req(HPDCACHE_REQ_AMO_LR), addr = addr_sva_aligned, offset = (hpdcache_req_offset >> 3) << 3)  
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_AMO_SC) 
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] != addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH]) ;
  endproperty 
  lr_sc_fail_2_cov: cover property ( lr_sc_fail_2 )
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%2t] Event lr_sc_fail_2", $time );

  property lr_sc_fail_3;
    hpdcache_req_addr_t    addr;
    hpdcache_offset_t      offset;
        
    @( posedge clk_i )
    (hpdcache_req(HPDCACHE_REQ_AMO_LR), addr = addr_sva_aligned, offset = (hpdcache_req_offset >> 3) << 3)  
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_STORE)
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] == addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH]) & (offset == (hpdcache_req_offset >> 3) << 3)
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_AMO_SC) 
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] == addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH]) & (offset == (hpdcache_req_offset >> 3) << 3);
  endproperty 
  lr_sc_fail_3_cov: cover property ( lr_sc_fail_3 )
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event lr_sc_fail_3", $time );

  property lr_sc_pass_1;
    hpdcache_req_addr_t    addr;
    hpdcache_offset_t      offset;
        
    @( posedge clk_i )
    (hpdcache_req(HPDCACHE_REQ_AMO_LR), addr = addr_sva_aligned, offset = (hpdcache_req_offset >> 3) << 3)  
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_AMO_SC) 
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] == addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH]) & (offset == (hpdcache_req_offset >> 3) << 3);
  endproperty 
  lr_sc_pass_1_cov: cover property ( lr_sc_pass_1 )
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%2t] Event lr_sc_pass_1", $time );

  property lr_sc_pass_2;
    hpdcache_req_addr_t    addr;
    hpdcache_offset_t      offset;
        
    @( posedge clk_i )
    (hpdcache_req(HPDCACHE_REQ_AMO_LR), addr = addr_sva_aligned, offset = (hpdcache_req_offset >> 3) << 3)  
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_STORE)
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] == addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH]) & (offset != (hpdcache_req_offset >> 3) << 3)
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_AMO_SC) 
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] == addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH]) & (offset == (hpdcache_req_offset >> 3) << 3);
  endproperty 
  lr_sc_pass_2_cov: cover property ( lr_sc_pass_2 )
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event lr_sc_pass_2", $time );

  property lr_sc_pass_3;
    hpdcache_req_addr_t    addr;
    hpdcache_offset_t      offset;
        
    @( posedge clk_i )
    (hpdcache_req(HPDCACHE_REQ_AMO_LR), addr = addr_sva_aligned, offset = (hpdcache_req_offset >> 3) << 3)  
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_LOAD)
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] == addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH]) & (offset == (hpdcache_req_offset >> 3) << 3)
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_AMO_SC) 
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] == addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH]) & (offset == (hpdcache_req_offset >> 3) << 3);
  endproperty 
  lr_sc_pass_3_cov: cover property ( lr_sc_pass_3 )
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event lr_sc_pass_3", $time );

  property lr_sc_pass_4;
    hpdcache_req_addr_t    addr;
    hpdcache_offset_t      offset;
        
    @( posedge clk_i )
    (hpdcache_req(HPDCACHE_REQ_AMO_LR), addr = addr_sva_aligned, offset = (hpdcache_req_offset >> 3) << 3)  
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_LOAD)
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] != addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH])
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_AMO_SC) 
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] == addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH]) & (offset == (hpdcache_req_offset >> 3) << 3);
  endproperty 
  lr_sc_pass_4_cov: cover property ( lr_sc_pass_4 )
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event lr_sc_pass_4", $time );

  property lr_sc_pass_5;
    hpdcache_req_addr_t    addr;
    hpdcache_offset_t      offset;
        
    @( posedge clk_i )
    (hpdcache_req(HPDCACHE_REQ_AMO_LR), addr = addr_sva_aligned, offset = (hpdcache_req_offset >> 3) << 3)  
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_LOAD)
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] == addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH]) & (offset != (hpdcache_req_offset >> 3) << 3)
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_AMO_SC) 
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] == addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH]) & (offset == (hpdcache_req_offset >> 3) << 3);
  endproperty 
  lr_sc_pass_5_cov: cover property ( lr_sc_pass_5 )
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event lr_sc_pass_5", $time );


  property lr_sc_pass_6;
    hpdcache_req_addr_t    addr;
    hpdcache_offset_t      offset;
        
    @( posedge clk_i )
    (hpdcache_req(HPDCACHE_REQ_AMO_LR), addr = addr_sva_aligned, offset = (hpdcache_req_offset >> 3) << 3)  
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_STORE)
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] != addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH])
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_AMO_SC) 
    ##0 (addr_sva[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH] == addr[hpdcacheCfg.u.memAddrWidth-1: HPDCACHE_OFFSET_WIDTH]) & (offset == (hpdcache_req_offset >> 3) << 3);
  endproperty 
  lr_sc_pass_6_cov: cover property ( lr_sc_pass_6 )
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event lr_sc_pass_6", $time );


  // --------------------------------------------------------
  // hpdcache load without rsp followed by hpdcache req with rsp        
  // --------------------------------------------------------
  property load_no_rsp_hpdcache_req_with_rsp(Op);
    hpdcache_set_t set; 
    hpdcache_tag_t tag; 
    @( posedge clk_i )
    hpdcache_req(HPDCACHE_REQ_LOAD) ##0 (arb_req.need_rsp == 0, set = hpdcache_req_set, tag = hpdcache_req_tag) 
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(Op) ##0 ((set == hpdcache_req_set) & (tag == hpdcache_req_tag));
  endproperty 

  // --------------------------------------------------------
  // hpdcache store without rsp followed by hpdcache req with rsp
  // --------------------------------------------------------
  property store_no_rsp_hpdcache_req_with_rsp(Op);
    hpdcache_set_t set; 
    hpdcache_tag_t tag; 
    @( posedge clk_i )
    hpdcache_req(HPDCACHE_REQ_STORE) ##0 (arb_req.need_rsp == 0, set = hpdcache_req_set, tag = hpdcache_req_tag) 
    ##[1:100] (!(arb_req_valid & arb_req_ready))
    ##1 hpdcache_req(Op) ##0 ((set == hpdcache_req_set) & (tag == hpdcache_req_tag));
  endproperty 

  load_no_rsp_load_rsp_cov: cover property ( load_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_LOAD ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event load_no_rsp_load_rsp", $time );

  load_no_rsp_store_rsp_cov: cover property ( load_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_STORE ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_store_rsp", $time );

  load_no_rsp_amo_lr_rsp_cov: cover property ( load_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_LR ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event load_no_rsp_amo_lr_rsp", $time );

  load_no_rsp_amo_sc_rsp_cov: cover property ( load_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_SC ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event load_no_rsp_amo_lr_rsp", $time );

  load_no_rsp_amo_swap_rsp_cov: cover property ( load_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_SWAP ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event load_no_rsp_amo_lr_rsp", $time );

  load_no_rsp_amo_add_rsp_cov: cover property ( load_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_ADD ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event load_no_rsp_amo_lr_rsp", $time );

  load_no_rsp_amo_and_rsp_cov: cover property ( load_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_AND ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event load_no_rsp_amo_lr_rsp", $time );

  load_no_rsp_amo_or_rsp_cov: cover property ( load_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_OR ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event load_no_rsp_amo_lr_rsp", $time );

  load_no_rsp_amo_xor_rsp_cov: cover property ( load_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_XOR ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event load_no_rsp_amo_lr_rsp", $time );

  load_no_rsp_amo_max_rsp_cov: cover property ( load_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_MAX ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event load_no_rsp_amo_lr_rsp", $time );

  load_no_rsp_amo_maxu_rsp_cov: cover property ( load_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_MAXU ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event load_no_rsp_amo_lr_rsp", $time );

  load_no_rsp_amo_min_rsp_cov: cover property ( load_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_MIN ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event load_no_rsp_amo_lr_rsp", $time );

  load_no_rsp_amo_minu_rsp_cov: cover property ( load_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_MINU ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event load_no_rsp_amo_lr_rsp", $time );

  store_no_rsp_load_rsp_cov: cover property ( store_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_LOAD ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_amo_lr_rsp", $time );

  store_no_rsp_store_rsp_cov: cover property ( store_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_STORE ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_amo_lr_rsp", $time );

  store_no_rsp_amo_lr_rsp_cov: cover property ( store_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_LR ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_amo_lr_rsp", $time );

  store_no_rsp_amo_sc_rsp_cov: cover property ( store_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_SC ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_amo_lr_rsp", $time );

  store_no_rsp_amo_swap_rsp_cov: cover property ( store_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_SWAP ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_amo_lr_rsp", $time );
  
  store_no_rsp_amo_add_rsp_cov: cover property ( store_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_ADD ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_amo_lr_rsp", $time );
  
  store_no_rsp_amo_and_rsp_cov: cover property ( store_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_AND ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_amo_lr_rsp", $time );
  
  store_no_rsp_amo_or_rsp_cov: cover property ( store_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_OR ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_amo_lr_rsp", $time );
  
  store_no_rsp_amo_xor_rsp_cov: cover property ( store_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_XOR ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_amo_lr_rsp", $time );
  
  store_no_rsp_amo_max_rsp_cov: cover property ( store_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_MAX ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_amo_lr_rsp", $time );
  
  store_no_rsp_amo_maxu_rsp_cov: cover property ( store_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_MAXU ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_amo_lr_rsp", $time );
  
  store_no_rsp_amo_min_rsp_cov: cover property ( store_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_MIN ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_amo_lr_rsp", $time );
  
  store_no_rsp_amo_minu_rsp_cov: cover property ( store_no_rsp_hpdcache_req_with_rsp( HPDCACHE_REQ_AMO_MINU ))
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event store_no_rsp_amo_lr_rsp", $time );

  // back to back operation at different addr followed by load
  property b2b_op_op_load(Op1, Op2);
    hpdcache_req_addr_t       Op1_addr; 
    @( posedge clk_i )
    (hpdcache_req(Op1), Op1_addr = addr_sva_aligned) 
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(Op2) ##0 (addr_sva_aligned != Op1_addr) ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_LOAD) ##0 (addr_sva_aligned == Op1_addr);
  endproperty 

  // N operation followed by an operation at diff addr  followed by load
  property b2b_op_n_op_load(Op1, local input int N);
    hpdcache_req_addr_t       Op1_addr; 
    @( posedge clk_i )
    (hpdcache_req(Op1), Op1_addr = addr_sva_aligned) 
    ##1 ((arb_req_valid & arb_req_ready) & (addr_sva_aligned != Op1_addr))[=N]
    ##1 hpdcache_req(HPDCACHE_REQ_LOAD) ##0 (addr_sva_aligned == Op1_addr);
  endproperty 

  property b2b_amo_op_load(Op1, Op2);
    hpdcache_req_addr_t       Op1_addr; 
    @( posedge clk_i )
    (hpdcache_amo_req(Op1), Op1_addr = addr_sva_aligned) 
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(Op2) ##0 (addr_sva_aligned != Op1_addr)
    ##1 (!(arb_req_valid & arb_req_ready))[*0:100] 
    ##1 hpdcache_req(HPDCACHE_REQ_LOAD) ##0 (addr_sva_aligned == Op1_addr);
  endproperty 

  property b2b_amo_n_op_load(Op1, local input int N);
    hpdcache_req_addr_t       Op1_addr; 
    @( posedge clk_i )
    (hpdcache_amo_req(Op1), Op1_addr = addr_sva_aligned) 
    ##1 ((arb_req_valid & arb_req_ready) & (addr_sva_aligned != Op1_addr))[=N]
    ##1 hpdcache_req(HPDCACHE_REQ_LOAD) ##0 (addr_sva_aligned == Op1_addr);
  endproperty 
  // White Box
  property  mshr_alloc_with_ready; 

    @( posedge clk_i )
    ( miss_mshr_alloc == 1) & (miss_mshr_alloc_ready == 1)
  endproperty 
  mshr_alloc_with_ready_cov: cover property (mshr_alloc_with_ready)
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event mshr_alloc_with_ready", $time );

  property  mshr_alloc_without_ready; 

    @( posedge clk_i )
    ( miss_mshr_alloc == 1) |-> ##1 (miss_mshr_alloc_ready == 0)
  endproperty 
  mshr_alloc_without_ready_cov: cover property (mshr_alloc_without_ready)
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event mshr_alloc_without_ready", $time );

  property  mshr_check_with_alloc_full; 

    @( posedge clk_i )
    ( miss_mshr_check == 1) |-> ##1 (miss_mshr_alloc_full == 1)
  endproperty 
  mshr_check_with_alloc_full_cov: cover property (mshr_check_with_alloc_full)
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event mshr_check_with_alloc_full", $time );

  property  mshr_check_without_alloc_full; 

    @( posedge clk_i )
    ( miss_mshr_check == 1) & (miss_mshr_alloc_full == 0)
  endproperty 
  mshr_check_without_alloc_full_cov: cover property (mshr_check_without_alloc_full)
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event mshr_check_without_alloc_full", $time );

  property  refill_req_with_ready; 

    @( posedge clk_i )
    ( refill_req_valid == 1) & (refill_req_ready == 1)
  endproperty 
  refill_req_with_ready_cov: cover property (refill_req_with_ready)
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event refill_req_with_ready", $time );

  property  refill_req_without_ready; 

    @( posedge clk_i )
    ( refill_req_valid == 1) & (refill_req_ready == 0)
  endproperty 
  refill_req_without_ready_cov: cover property (refill_req_without_ready)
  if ($test$plusargs("+COVER_VERBOSE"))
  $display("[%3t] Event refill_req_without_ready", $time );

  logic [hpdcacheCfg.u.mshrSets*hpdcacheCfg.u.mshrWays-1:0] mshr_valid; 


  assign mshr_valid = hpdcache_miss_handler_i.hpdcache_mshr_i.mshr_valid_q;

  sequence mshr_bit_set(i);
   mshr_valid[i] == 1; 
  endsequence 
  genvar mshr_cnt; 

  generate

   for( mshr_cnt = 0; mshr_cnt < hpdcacheCfg.u.mshrSets*hpdcacheCfg.u.mshrWays; mshr_cnt ++) begin : mshr_bit
     property all_mshr_bit_set; 
      @( posedge clk_i )
      mshr_bit_set(mshr_cnt);
    endproperty 

    all_mshr_bit_set_cov: cover property (all_mshr_bit_set)
    if ($test$plusargs("+COVER_VERBOSE"))
    $display("[%3t] Event all_mshr_bit_set", $time );
   end
  endgenerate

  generate 
       for ( genvar i = 0 ; i < hpdcacheCfg.u.nRequesters -1 ; i++ ) begin
       
          for(clk_delay_itr=0; clk_delay_itr<= 5 ; clk_delay_itr++) begin: clk_delay_itr_rst_flush

             // ------------------------------------------
             // CORE REQ  RESET SCHMOO 
             // ------------------------------------------
             property core_req_reset_schmoo;

               @( posedge clk_i )
    
               $rose((core_req_valid_i[i] & core_req_ready_o[i]))   |-> ##clk_delay_itr $rose(rst_ni) ;

             endproperty
             core_req_reset_schmoo_cov: cover property ( core_req_reset_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_req_reset_schmoo", $time );
             // ------------------------------------------------------------------------------------------

             property core_reset_req_schmoo;

               @( posedge clk_i )
    
               $rose(rst_ni)  |-> ##clk_delay_itr $rose((core_req_valid_i[i] & core_req_ready_o[i])) ;

             endproperty
             core_reset_req_schmoo_cov: cover property ( core_reset_req_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_reset_req_schmoo", $time );
             // ------------------------------------------------------------------------------------------
             //
             // ------------------------------------------
             // MEM READ REQ CACHED  RESET SCHMOO 
             // ------------------------------------------
             property mem_req_read_cached_reset_schmoo;

               @( posedge clk_i )
    
               $rose((mem_req_read_valid_o & mem_req_read_ready_i & mem_req_read_o.mem_req_cacheable ==1))   |-> ##clk_delay_itr $rose(rst_ni) ;

             endproperty
             mem_req_read_cached_reset_schmoo_cov: cover property ( mem_req_read_cached_reset_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event mem_req_read_reset_schmoo", $time );
             // ------------------------------------------------------------------------------------------

             property mem_reset_read_req_cached_schmoo;

               @( posedge clk_i )
    
               $rose(rst_ni)  |-> ##clk_delay_itr $rose((mem_req_read_valid_o & mem_req_read_ready_i & mem_req_read_o.mem_req_cacheable ==1)) ;

             endproperty
             mem_reset_read_req_cached_schmoo_cov: cover property ( mem_reset_read_req_cached_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_reset_req_schmoo", $time );
             // ------------------------------------------------------------------------------------------
             //
             // ------------------------------------------
             // MEM READ REQ UNCACHED  RESET SCHMOO 
             // ------------------------------------------
             property mem_req_read_uncached_reset_schmoo;

               @( posedge clk_i )
    
               $rose((mem_req_read_valid_o & mem_req_read_ready_i & mem_req_read_o.mem_req_cacheable ==0))   |-> ##clk_delay_itr $rose(rst_ni) ;

             endproperty
             mem_req_read_uncached_reset_schmoo_cov: cover property ( mem_req_read_uncached_reset_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event mem_req_read_reset_schmoo", $time );
             // ------------------------------------------------------------------------------------------

             property mem_reset_read_req_uncached_schmoo;

               @( posedge clk_i )
    
               $rose(rst_ni)  |-> ##clk_delay_itr $rose((mem_req_read_valid_o & mem_req_read_ready_i & mem_req_read_o.mem_req_cacheable ==0)) ;

             endproperty
             mem_reset_read_req_uncached_schmoo_cov: cover property ( mem_reset_read_req_uncached_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_reset_req_schmoo", $time );
             // ------------------------------------------------------------------------------------------
             //
             // ------------------------------------------
             // MEM WRITE REQ CACHED  RESET SCHMOO 
             // ------------------------------------------
             property mem_req_write_cached_reset_schmoo;

               @( posedge clk_i )
    
               $rose((mem_req_write_valid_o & mem_req_write_ready_i & mem_req_write_o.mem_req_cacheable ==1))   |-> ##clk_delay_itr $rose(rst_ni) ;

             endproperty
             mem_req_write_cached_reset_schmoo_cov: cover property ( mem_req_write_cached_reset_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event mem_req_write_reset_schmoo", $time );
             // ------------------------------------------------------------------------------------------

             property mem_reset_write_req_cached_schmoo;

               @( posedge clk_i )
    
               $rose(rst_ni)  |-> ##clk_delay_itr $rose((mem_req_write_valid_o & mem_req_write_ready_i & mem_req_write_o.mem_req_cacheable ==1)) ;

             endproperty
             mem_reset_write_req_cached_schmoo_cov: cover property ( mem_reset_write_req_cached_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_reset_req_schmoo", $time );
             // ------------------------------------------------------------------------------------------
             // ------------------------------------------
             // MEM WRITE REQ UNCACHED  RESET SCHMOO 
             // ------------------------------------------
             property mem_req_write_uncached_reset_schmoo;

               @( posedge clk_i )
    
               $rose((mem_req_write_valid_o & mem_req_write_ready_i & mem_req_write_o.mem_req_cacheable ==0))   |-> ##clk_delay_itr $rose(rst_ni) ;

             endproperty
             mem_req_write_uncached_reset_schmoo_cov: cover property ( mem_req_write_uncached_reset_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event mem_req_write_reset_schmoo", $time );
             // ------------------------------------------------------------------------------------------

             property mem_reset_write_req_uncached_schmoo;

               @( posedge clk_i )
    
               $rose(rst_ni)  |-> ##clk_delay_itr $rose((mem_req_write_valid_o & mem_req_write_ready_i & mem_req_write_o.mem_req_cacheable ==0)) ;

             endproperty
             mem_reset_write_req_uncached_schmoo_cov: cover property ( mem_reset_write_req_uncached_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_reset_req_schmoo", $time );
             // ------------------------------------------------------------------------------------------
             // ------------------------------------------
             // MEM WRITE RSP RESET SCHMOO 
             // ------------------------------------------
             property mem_resp_write_reset_schmoo;

               @( posedge clk_i )
    
               $rose((mem_resp_write_valid_i & mem_resp_write_ready_o))   |-> ##clk_delay_itr $rose(rst_ni) ;

             endproperty
             mem_resp_write_reset_schmoo_cov: cover property ( mem_resp_write_reset_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event mem_resp_write_reset_schmoo", $time );
             // ------------------------------------------------------------------------------------------

             property mem_reset_write_resp_schmoo;

               @( posedge clk_i )
    
               $rose(rst_ni)  |-> ##clk_delay_itr $rose((mem_resp_write_valid_i & mem_resp_write_ready_o)) ;

             endproperty
             mem_reset_write_resp_schmoo_cov: cover property ( mem_reset_write_resp_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_reset_resp_schmoo", $time );
             // ------------------------------------------------------------------------------------------
             // ------------------------------------------
             // MEM READ RSP RESET SCHMOO 
             // ------------------------------------------
             property mem_resp_read_reset_schmoo;

               @( posedge clk_i )
    
               $rose((mem_resp_read_valid_i & mem_resp_read_ready_o))   |-> ##clk_delay_itr $rose(rst_ni) ;

             endproperty
             mem_resp_read_reset_schmoo_cov: cover property ( mem_resp_read_reset_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event mem_resp_read_reset_schmoo", $time );
             // ------------------------------------------------------------------------------------------

             property mem_reset_read_resp_schmoo;

               @( posedge clk_i )
    
               $rose(rst_ni)  |-> ##clk_delay_itr $rose((mem_resp_read_valid_i & mem_resp_read_ready_o)) ;

             endproperty
             mem_reset_read_resp_schmoo_cov: cover property ( mem_reset_read_resp_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_reset_resp_schmoo", $time );
             // ------------------------------------------------------------------------------------------

             // ------------------------------------------
             // CORE RSP RESET SCHMOO 
             // ------------------------------------------
             property core_rsp_reset_schmoo;

               @( posedge clk_i )
    
               $rose(core_rsp_valid_o[i])   |-> ##clk_delay_itr $rose(rst_ni) ;

             endproperty
             core_rsp_reset_schmoo_cov: cover property ( core_rsp_reset_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_rsp_reset_schmoo", $time );

             property core_reset_rsp_schmoo;

               @( posedge clk_i )
    
               $rose(rst_ni)  |-> ##clk_delay_itr $rose(core_rsp_valid_o[i]) ;

             endproperty
             core_reset_rsp_schmoo_cov: cover property ( core_reset_rsp_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_reset_rsp_schmoo", $time );

             // ------------------------------------------
             // FLUSH SCHMOO
             // ------------------------------------------
             property core_req_flush_schmoo;

               @( posedge clk_i )
    
               $rose((core_req_valid_i[i] & core_req_ready_o[i]))   |-> ##clk_delay_itr $rose(wbuf_flush_i) ;

             endproperty
             core_req_flush_schmoo_cov: cover property ( core_req_flush_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_req_flush_schmoo", $time );

             property core_flush_req_schmoo;

               @( posedge clk_i )
    
               $rose(wbuf_flush_i)  |-> ##clk_delay_itr $rose((core_req_valid_i[i] & core_req_ready_o[i])) ;

             endproperty
             core_flush_req_schmoo_cov: cover property ( core_flush_req_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_flush_req_schmoo", $time );
             // ------------------------------------------------------------------------------------------
             //
             // ------------------------------------------
             // MEM READ REQ CACHED  FLUSH SCHMOO 
             // ------------------------------------------
             property mem_req_read_cached_flush_schmoo;

               @( posedge clk_i )
    
               $rose((mem_req_read_valid_o & mem_req_read_ready_i & mem_req_read_o.mem_req_cacheable ==1))   |-> ##clk_delay_itr $rose(wbuf_flush_i) ;

             endproperty
             mem_req_read_cached_flush_schmoo_cov: cover property ( mem_req_read_cached_flush_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event mem_req_read_flush_schmoo", $time );
             // ------------------------------------------------------------------------------------------

             property mem_flush_read_req_cached_schmoo;

               @( posedge clk_i )
    
               $rose(wbuf_flush_i)  |-> ##clk_delay_itr $rose((mem_req_read_valid_o & mem_req_read_ready_i & mem_req_read_o.mem_req_cacheable ==1)) ;

             endproperty
             mem_flush_read_req_cached_schmoo_cov: cover property ( mem_flush_read_req_cached_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_flush_req_schmoo", $time );
             // ------------------------------------------------------------------------------------------
             //
             // ------------------------------------------
             // MEM READ REQ UNCACHED  FLUSH SCHMOO 
             // ------------------------------------------
             property mem_req_read_uncached_flush_schmoo;

               @( posedge clk_i )
    
               $rose((mem_req_read_valid_o & mem_req_read_ready_i & mem_req_read_o.mem_req_cacheable ==0))   |-> ##clk_delay_itr $rose(wbuf_flush_i) ;

             endproperty
             mem_req_read_uncached_flush_schmoo_cov: cover property ( mem_req_read_uncached_flush_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event mem_req_read_flush_schmoo", $time );
             // ------------------------------------------------------------------------------------------

             property mem_flush_read_req_uncached_schmoo;

               @( posedge clk_i )
    
               $rose(wbuf_flush_i)  |-> ##clk_delay_itr $rose((mem_req_read_valid_o & mem_req_read_ready_i & mem_req_read_o.mem_req_cacheable ==0)) ;

             endproperty
             mem_flush_read_req_uncached_schmoo_cov: cover property ( mem_flush_read_req_uncached_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_flush_req_schmoo", $time );
             // ------------------------------------------------------------------------------------------
             //
             // ------------------------------------------
             // MEM WRITE REQ CACHED  FLUSH SCHMOO 
             // ------------------------------------------
             property mem_req_write_cached_flush_schmoo;

               @( posedge clk_i )
    
               $rose((mem_req_write_valid_o & mem_req_write_ready_i & mem_req_write_o.mem_req_cacheable ==1))   |-> ##clk_delay_itr $rose(wbuf_flush_i) ;

             endproperty
             mem_req_write_cached_flush_schmoo_cov: cover property ( mem_req_write_cached_flush_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event mem_req_write_flush_schmoo", $time );
             // ------------------------------------------------------------------------------------------

             property mem_flush_write_req_cached_schmoo;

               @( posedge clk_i )
    
               $rose(wbuf_flush_i)  |-> ##clk_delay_itr $rose((mem_req_write_valid_o & mem_req_write_ready_i & mem_req_write_o.mem_req_cacheable ==1)) ;

             endproperty
             mem_flush_write_req_cached_schmoo_cov: cover property ( mem_flush_write_req_cached_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_flush_req_schmoo", $time );
             // ------------------------------------------------------------------------------------------
             // ------------------------------------------
             // MEM WRITE REQ UNCACHED  FLUSH SCHMOO 
             // ------------------------------------------
             property mem_req_write_uncached_flush_schmoo;

               @( posedge clk_i )
    
               $rose((mem_req_write_valid_o & mem_req_write_ready_i & mem_req_write_o.mem_req_cacheable ==0))   |-> ##clk_delay_itr $rose(wbuf_flush_i) ;

             endproperty
             mem_req_write_uncached_flush_schmoo_cov: cover property ( mem_req_write_uncached_flush_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event mem_req_write_flush_schmoo", $time );
             // ------------------------------------------------------------------------------------------

             property mem_flush_write_req_uncached_schmoo;

               @( posedge clk_i )
    
               $rose(wbuf_flush_i)  |-> ##clk_delay_itr $rose((mem_req_write_valid_o & mem_req_write_ready_i & mem_req_write_o.mem_req_cacheable ==0)) ;

             endproperty
             mem_flush_write_req_uncached_schmoo_cov: cover property ( mem_flush_write_req_uncached_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_flush_req_schmoo", $time );
             // ------------------------------------------------------------------------------------------

             // ------------------------------------------
             // CORE RSP FLUSH SCHMOO 
             // ------------------------------------------
             property core_rsp_flush_schmoo;

               @( posedge clk_i )
    
               $rose(core_rsp_valid_o[i])   |-> ##clk_delay_itr $rose(wbuf_flush_i) ;

             endproperty
             core_rsp_flush_schmoo_cov: cover property ( core_rsp_flush_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_rsp_flush_schmoo", $time );

             property core_flush_rsp_schmoo;

               @( posedge clk_i )
    
               $rose(wbuf_flush_i)  |-> ##clk_delay_itr $rose(core_rsp_valid_o[i]) ;

             endproperty
             core_flush_rsp_schmoo_cov: cover property ( core_flush_rsp_schmoo )
             if ($test$plusargs("+COVER_VERBOSE"))
             $display("[%2t] Event core_flush_rsp_schmoo", $time );

          end
      end
 endgenerate

 hpdcache_req_op_t op;
 typedef  hpdcache_req_op_t op_list_t[$];

 op_list_t op_array = op_array_values();

 function automatic op_list_t op_array_values;
   hpdcache_req_op_t tmp = tmp.first;
   do begin
     op_array_values.push_back(tmp);
     tmp = tmp.next;
   end
   while (tmp  != tmp.first);
 endfunction

 initial $display("%p", op_array);

 // CSRs do not exists yet
// Iterating through an enum (store, amo followed by all operation followed by
// load
 genvar j;
 generate 
 for( j = 0; j < op.num(); j++) begin
   for( i = 0; i < op.num(); i++) begin: b2b_amo_op_load_itr
     b2b_amo_op_load_cov  : cover property ( b2b_amo_op_load(op_array[j], op_array[i]) );
   end
   for(genvar k = 0; k < 16; k++) begin: b2b_amo_n_op_load_itr
     b2b_amo_n_op_load_cov: cover property ( b2b_amo_n_op_load(op_array[j], k) );
   end
 end
 for( i = 0; i < op.num(); i++) begin: b2b_op_op_load_itr
   b2b_write_op_load_cov: cover property ( b2b_op_op_load(HPDCACHE_REQ_STORE, op_array[i]) );
 end
 endgenerate 
     

 generate 
 for(i = 0; i < 16; i++) begin: b2b_op_n_op_load_itr
   b2b_write_n_op_load_cov: cover property ( b2b_op_n_op_load(HPDCACHE_REQ_STORE, i) );
 end
 endgenerate 

/* pragma translate_off */

  function int get_index();
    automatic int idx = -1;
    for(int i = 0; i < hpdcacheCfg.u.nRequesters; i ++) begin
      if( core_req_valid_i[i] & core_req_ready_o[i]) begin 
        idx = i; 
        break;
      end
    end
    return idx;
  endfunction 
endmodule: hpdcache_SVA
