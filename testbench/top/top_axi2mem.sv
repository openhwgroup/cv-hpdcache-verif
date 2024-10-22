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

module top;

    timeunit 1ns;
    timeprecision 1ps;

    // -----------------------------------------------------------------
    // Import/Include
    // -----------------------------------------------------------------
    `include "uvm_macros.svh"

    import uvm_pkg::*;
    import hpdcache_pkg::*;
    import hwpf_stride_pkg::*;
    import hpdcache_common_pkg::*;
    import hpdcache_test_pkg::*; 
    import memory_rsp_model_pkg::*;
    import pulse_gen_pkg::*;
    import axi2mem_pkg::*;

    typedef struct packed {
      logic                                   req_valid ;
      logic  [HPDCACHE_PA_WIDTH-1:0]          req_addr  ;
      logic                                   req_wrn   ; // 0=write, 1=read
      logic  [HPDCACHE_MEM_ID_WIDTH -1: 0]    req_id    ;
      logic  [HPDCACHE_MEM_ID_WIDTH -1: 0]    src_id    ;
      logic  [HPDCACHE_MEM_DATA_WIDTH-1:0]    req_data  ;
      logic  [HPDCACHE_MEM_DATA_WIDTH/8-1:0]  req_strb  ;
      logic                                   req_amo   ;
      mem_atomic_t			                  amo_op    ;
    } mem_req_t; 

    // -----------------------------------------------------------------
    // Clock/Reset signals
    // -----------------------------------------------------------------
    bit reset, flush_n;
    bit post_shutdown_phase;
    logic clk;
    logic rst_n, flush;
    xrtl_clock_vif clock_if( .clock(clk));

    xrtl_reset_vif #(1'b1,50,0) reset_if (.clk(clk),
                                          .reset(reset),
                                          .reset_n(rst_n), 
                                          .post_shutdown_phase(post_shutdown_phase));

    // interface thats gives a pulse 
    pulse_if                    flush_vif (.clk(clk),
                                           .rstn(rst_n));

    bp_vif     #( 1 )           m_read_bp_vif ( .clk( clk ), .rstn( rst_n ) );
    bp_vif     #( 1 )           m_write_req_bp_vif ( .clk( clk ), .rstn( rst_n ) );
    bp_vif     #( 1 )           m_write_data_bp_vif ( .clk( clk ), .rstn( rst_n ) );

    // -----------------------------------------------------------------
    // Core/Prefetcher signals
    // -----------------------------------------------------------------
    // Core req
    logic          core_req_valid[m_hpdcache_cfg.u.nRequesters] ;
    logic          core_req_ready[m_hpdcache_cfg.u.nRequesters] ;
    hpdcache_req_t core_req[m_hpdcache_cfg.u.nRequesters]       ;


    // Core rsp
    logic          core_rsp_valid[m_hpdcache_cfg.u.nRequesters] ;
    hpdcache_rsp_t core_rsp[m_hpdcache_cfg.u.nRequesters]       ;

    // -----------------------------------------------------------------
    // PREFETCHER
    // -----------------------------------------------------------------
    hwpf_stride_cfg_if  hwpf_stride_cfg_vif ( .clk( clk ), .rst_ni( rst_n ) );

    logic                  [NUM_HW_PREFETCH-1:0] hwpf_stride_base_set_i     ;
    hwpf_stride_base_t     [NUM_HW_PREFETCH-1:0] hwpf_stride_base_i         ;
    hwpf_stride_base_t     [NUM_HW_PREFETCH-1:0] hwpf_stride_base_o         ;

    logic                  [NUM_HW_PREFETCH-1:0] hwpf_stride_param_set_i    ;
    hwpf_stride_param_t    [NUM_HW_PREFETCH-1:0] hwpf_stride_param_i        ;
    hwpf_stride_param_t    [NUM_HW_PREFETCH-1:0] hwpf_stride_param_o        ;

    logic                  [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle_set_i ;
    hwpf_stride_throttle_t [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle_i     ;
    hwpf_stride_throttle_t [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle_o     ;

    hpdcache_nline_t    [NUM_HW_PREFETCH-1:0] snoop_addr_nline ; // contains all but the least significant bits of the address (nline offset)
    hpdcache_req_addr_t [NUM_HW_PREFETCH-1:0] snoop_addr ;       // contains all bits of addresse
    logic               [NUM_HW_PREFETCH-1:0] snoop_valid;

    // snoop interface 
    logic                  [NUM_SNOOP_PORTS-1:0] snoop_abort        ;
    hpdcache_req_offset_t  [NUM_SNOOP_PORTS-1:0] snoop_addr_offset  ;
    hpdcache_tag_t         [NUM_SNOOP_PORTS-1:0] snoop_addr_tag     ;
    logic                  [NUM_SNOOP_PORTS-1:0] snoop_phys_indexed ; 

    hpdcache_req_sid_t  hwpf_stride_hpdcache_req_sid   ;
    logic               hwpf_stride_hpdcache_req_valid ;
    logic               hwpf_stride_hpdcache_req_ready ;
    hpdcache_req_t      hwpf_stride_hpdcache_req       ;
    logic               hwpf_stride_hpdcache_rsp_valid ;
    hpdcache_rsp_t      hwpf_stride_hpdcache_rsp       ;
    logic               hwpf_stride_hpdcache_req_abort ;
    hpdcache_tag_t      hwpf_stride_hpdcache_req_tag   ;
    hpdcache_pma_t      hwpf_stride_hpdcache_req_pma   ;

    logic               core_req_abort[m_hpdcache_cfg.u.nRequesters] ;
    hpdcache_tag_t      core_req_tag[m_hpdcache_cfg.u.nRequesters]   ;
    hpdcache_pma_t      core_req_pma[m_hpdcache_cfg.u.nRequesters]   ;

    hwpf_stride_wrapper
    #(
       m_hpdcache_cfg, 

       NUM_HW_PREFETCH,
       NUM_SNOOP_PORTS,
       
       hpdcache_tag_t,
       hpdcache_req_offset_t,
       hpdcache_req_data_t,
       hpdcache_req_be_t,
       hpdcache_req_sid_t,
       hpdcache_req_tid_t,
       hpdcache_req_t,
       hpdcache_rsp_t

    ) hwpf_stride_wrapper_i (
        .clk_i  ( clk   ) ,
        .rst_ni ( rst_n ) ,

        // CSR
        .hwpf_stride_base_set_i     ( hwpf_stride_base_set_i     ) ,
        .hwpf_stride_base_i         ( hwpf_stride_base_i         ) ,
        .hwpf_stride_base_o         ( hwpf_stride_base_o         ) ,

        .hwpf_stride_param_set_i    ( hwpf_stride_param_set_i    ) ,
        .hwpf_stride_param_i        ( hwpf_stride_param_i        ) ,
        .hwpf_stride_param_o        ( hwpf_stride_param_o        ) ,

        .hwpf_stride_throttle_set_i ( hwpf_stride_throttle_set_i ) ,
        .hwpf_stride_throttle_i     ( hwpf_stride_throttle_i     ) ,
        .hwpf_stride_throttle_o     ( hwpf_stride_throttle_o     ) ,

        .hwpf_stride_status_o       ( hwpf_stride_cfg_vif.hwpf_stride_status ) ,
        // Snooping
        .snoop_valid_i ( snoop_valid ),

        .snoop_abort_i        (  snoop_abort )         , 
        .snoop_addr_offset_i  (  snoop_addr_offset )   ,
        .snoop_addr_tag_i     (  snoop_addr_tag )      ,
        .snoop_phys_indexed_i (  snoop_phys_indexed )  ,
        
        // D-Cache interface
        .hpdcache_req_sid_i   ( hwpf_stride_hpdcache_req_sid   ) ,
        .hpdcache_req_valid_o ( hwpf_stride_hpdcache_req_valid ) ,
        .hpdcache_req_ready_i ( hwpf_stride_hpdcache_req_ready ) ,
        .hpdcache_req_o       ( hwpf_stride_hpdcache_req       ) ,
        .hpdcache_req_abort_o ( hwpf_stride_hpdcache_req_abort ),
        .hpdcache_req_tag_o   ( hwpf_stride_hpdcache_req_tag   ),
        .hpdcache_req_pma_o   ( hwpf_stride_hpdcache_req_pma   ),
        .hpdcache_rsp_valid_i ( hwpf_stride_hpdcache_rsp_valid ) ,
        .hpdcache_rsp_i       ( hwpf_stride_hpdcache_rsp       )

    );

    // Get the snoop match signal to get when the hwpf_stride should start
    // operating
    assign hwpf_stride_cfg_vif.snoop_valid = snoop_valid ;
    assign hwpf_stride_cfg_vif.snoop_addr  = snoop_addr_nline  ;

    // Assign the configuration of each hwpf_stride module
    generate 
    for ( genvar k = 0 ; k < NUM_HW_PREFETCH ; k++ ) begin
      assign snoop_valid[k]                      = hpdcache_vif[k].core_req_valid_i && hpdcache_vif[k].core_req_ready_o ; 

      assign hwpf_stride_base_set_i[k]              = hwpf_stride_cfg_vif.base_set[k]                     ;
      // assign hwpf_stride_base_i[k].hw_prefetch_base = hwpf_stride_cfg_vif.hwpf_stride_cfg[k].hw_prefetch_base ;
      assign hwpf_stride_base_i[k].base_cline = hwpf_stride_cfg_vif.hwpf_stride_cfg[k].hw_prefetch_base[63:6]  ;
      assign hwpf_stride_base_i[k].unused     = hwpf_stride_cfg_vif.hwpf_stride_cfg[k].hw_prefetch_base[5:3]   ;
      assign hwpf_stride_base_i[k].cycle      = hwpf_stride_cfg_vif.hwpf_stride_cfg[k].hw_prefetch_base[2]        ;
      assign hwpf_stride_base_i[k].rearm      = hwpf_stride_cfg_vif.hwpf_stride_cfg[k].hw_prefetch_base[1]        ;
      assign hwpf_stride_base_i[k].enable     = hwpf_stride_cfg_vif.hwpf_stride_cfg[k].hw_prefetch_base[0]        ;
      // assign hwpf_stride_base_o         = hwpf_stride_cfg_vif.base_o        ;
      assign hwpf_stride_param_set_i[k]               = hwpf_stride_cfg_vif.param_set[k]               ;
      // assign hwpf_stride_param_i[k].hw_prefetch_param = hwpf_stride_cfg_vif.hwpf_stride_cfg[k].hw_prefetch_param  ;
      assign hwpf_stride_param_i[k].nblocks = hwpf_stride_cfg_vif.hwpf_stride_cfg[k].hw_prefetch_param[63:48]  ;
      assign hwpf_stride_param_i[k].nlines  = hwpf_stride_cfg_vif.hwpf_stride_cfg[k].hw_prefetch_param[47:32]  ;
      assign hwpf_stride_param_i[k].stride  = hwpf_stride_cfg_vif.hwpf_stride_cfg[k].hw_prefetch_param[31:0]   ;

      // assign hwpf_stride_param_o        = hwpf_stride_cfg_vif.param_o       ;
      assign hwpf_stride_throttle_set_i[k]                  = hwpf_stride_cfg_vif.throttle_set[k]              ;
      // assign hwpf_stride_throttle_i[k].hw_prefetch_throttle = hwpf_stride_cfg_vif.hwpf_stride_cfg[k].hw_prefetch_throttle     ;
      assign hwpf_stride_throttle_i[k].ninflight = hwpf_stride_cfg_vif.hwpf_stride_cfg[k].hw_prefetch_throttle[31:16]  ;
      assign hwpf_stride_throttle_i[k].nwait     = hwpf_stride_cfg_vif.hwpf_stride_cfg[k].hw_prefetch_throttle[15:0]   ;
      // assign hwpf_stride_throttle_o     = hwpf_stride_cfg_vif.throttle_o    ;
    end // for
    endgenerate 
   // --------------------------------------------------------------------------------- 
   // MISC signals 
   // --------------------------------------------------------------------------------- 
   misc_if hpdcache_misc_if(.clk(clk)); 

   // -----------------------------------------------------------------
   // Dache signals
   // -----------------------------------------------------------------
   hpdcache_if hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1:0] (.clk_i( clk ), .rst_ni( rst_n ) );
   dram_if   dram_vif   (.clk_i( clk ), .rst_ni( rst_n ) );
   conf_if   conf_vif   (.clk_i( clk ), .rst_ni( rst_n ) );
   perf_if   perf_vif   (.clk_i( clk ), .rst_ni( rst_n ) );

   // -----------------------------------------------------------------
   // Memory response model
   // -----------------------------------------------------------------
   memory_response_if#(
       .addr_width (HPDCACHE_PA_WIDTH), 
       .data_width (HPDCACHE_MEM_DATA_WIDTH), 
       .id_width   (HPDCACHE_MEM_ID_WIDTH)
   ) mem_rsp_if ( .clk( clk ), .rstn( rst_n ) );

   axi_if#(
       .wd_addr(HPDCACHE_PA_WIDTH), 
       .wd_data(HPDCACHE_MEM_DATA_WIDTH), 
       .wd_id(HPDCACHE_MEM_ID_WIDTH),
       .wd_user(1)
   ) axi2mem_if ( .clk( clk ), .rstn( rst_n ) );


   // Memory interface for cached and uncached read write
   memory_response_if#(
       .addr_width (HPDCACHE_PA_WIDTH), 
       .data_width (HPDCACHE_MEM_DATA_WIDTH), 
       .id_width   (HPDCACHE_MEM_ID_WIDTH)
   ) mem_rd_if ( .clk( clk ), .rstn( rst_n ) );

   memory_response_if#(
       .addr_width (HPDCACHE_PA_WIDTH), 
       .data_width (HPDCACHE_MEM_DATA_WIDTH), 
       .id_width   (HPDCACHE_MEM_ID_WIDTH)
   ) mem_wr_if ( .clk( clk ), .rstn( rst_n ) );


    // logic 
    hpdcache_mem_req_t               mem_req_read_o;
    hpdcache_mem_id_t                mem_req_read_base_id_i;
    hpdcache_mem_resp_r_t            mem_resp_read_i;

    hpdcache_mem_req_t               mem_req_write_o;
    hpdcache_mem_ext_req_t           mem_req_write_ext_o; //for dram monitor
    hpdcache_mem_id_t                mem_req_write_base_id_i;

    hpdcache_mem_req_w_t             mem_req_write_data_o;
    hpdcache_mem_resp_w_t            mem_resp_write_i;

    hpdcache_mem_req_t               mem_req_read_q[$];
    hpdcache_mem_req_t               mem_req_write_q[$];
    // -----------------------------------------------------------------
    // Assign process
    // -----------------------------------------------------------------
    genvar nreq;
    generate
      for(nreq=0 ;  nreq < m_hpdcache_cfg.u.nRequesters; nreq++ ) begin : CORE_SIG
      
        assign core_req_valid[nreq]                = hpdcache_vif[nreq].core_req_valid_i ;
        assign hpdcache_vif[nreq].core_req_ready_o = core_req_ready[nreq]                ;
        assign core_req[nreq]                      = hpdcache_vif[nreq].core_req_i       ;

        assign core_req_abort[nreq]   = hpdcache_vif[nreq].core_req_abort_i ;
        assign core_req_tag[nreq]     = hpdcache_vif[nreq].core_req_tag_i   ;
        assign core_req_pma[nreq]     = hpdcache_vif[nreq].core_req_pma_i   ;

        assign hpdcache_vif[nreq].core_rsp_valid_o = core_rsp_valid[nreq] ;
        assign hpdcache_vif[nreq].core_rsp_o       = core_rsp[nreq]       ;

      end
    endgenerate

   assign hwpf_stride_hpdcache_req_sid                            = hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_i.sid ;
   assign hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_valid_i            = hwpf_stride_hpdcache_req_valid;
   assign hwpf_stride_hpdcache_req_ready                          = hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_ready_o;
   // assign hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_i               = hwpf_stride_hpdcache_req ;
   assign hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_i.addr_offset      = hwpf_stride_hpdcache_req.addr_offset;
   assign hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_i.addr_tag         = hwpf_stride_hpdcache_req.addr_tag;
   assign hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_i.wdata            = hwpf_stride_hpdcache_req.wdata;
   assign hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_i.op               = hwpf_stride_hpdcache_req.op;
   assign hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_i.be               = hwpf_stride_hpdcache_req.be;
   assign hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_i.size             = hwpf_stride_hpdcache_req.size;
   assign hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_i.pma.uncacheable  = hwpf_stride_hpdcache_req.pma.uncacheable;
   assign hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_i.sid              = hpdcache_req_sid_t'(m_hpdcache_cfg.u.nRequesters-1);
   assign hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_i.tid              = hwpf_stride_hpdcache_req.tid;
   assign hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_req_i.need_rsp         = hwpf_stride_hpdcache_req.need_rsp;

   assign hwpf_stride_hpdcache_rsp_valid = hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_rsp_valid_o;
   assign hwpf_stride_hpdcache_rsp       = hpdcache_vif[m_hpdcache_cfg.u.nRequesters-1].core_rsp_o      ;

   assign flush                  = flush_vif.m_pulse_out; 
   assign axi2mem_if.ar_ready  = ~m_read_bp_vif.bp_out;  
   assign axi2mem_if.aw_ready  = ~m_write_req_bp_vif.bp_out;  
   assign axi2mem_if.w_ready   = ~m_write_data_bp_vif.bp_out;  
   // -----------------------------------------------------------------
   // DUT: HPDCACHE module
   // -----------------------------------------------------------------

  hpdcache #(
       m_hpdcache_cfg, 
       wbuf_timecnt_t,

    //  Request Interface Definitions
    //  {{{
       hpdcache_tag_t,
       hpdcache_data_word_t,
       hpdcache_data_be_t,
       hpdcache_req_offset_t,
       hpdcache_req_data_t,
       hpdcache_req_be_t,
       hpdcache_req_sid_t,
       hpdcache_req_tid_t,
       hpdcache_req_t,
       hpdcache_rsp_t,
    //  }}}

    //  Memory Interface Definitions
    //  {{{
      hpdcache_mem_addr_t,
      hpdcache_mem_id_t,
      hpdcache_mem_data_t,
      hpdcache_mem_be_t,
      hpdcache_mem_req_t,
      hpdcache_mem_req_w_t,
      hpdcache_mem_resp_r_t,
      hpdcache_mem_resp_w_t
    //  }}}
  ) dut (
    
    .clk_i                             (clk    ),
    .rst_ni                            ( rst_n ), 
    
    .wbuf_flush_i                      ( flush ), // wbuf_flush_i
    
    .core_req_valid_i                  ( core_req_valid ),
    .core_req_ready_o                  ( core_req_ready ),
    .core_req_i                        ( core_req       ),

    .core_req_abort_i                  ( core_req_abort ),
    .core_req_tag_i                    ( core_req_tag   ),
    .core_req_pma_i                    ( core_req_pma   ),

                                      
                                       //      Core response interface
    .core_rsp_valid_o                  ( core_rsp_valid ),
    .core_rsp_o                        ( core_rsp       ),
                                      
                                       //      Read interface
    .mem_req_read_ready_i         (axi2mem_if.ar_ready      ) ,
    .mem_req_read_valid_o         (axi2mem_if.ar_valid      ) ,
    .mem_req_read_o               (mem_req_read_o        ) ,
                                     
    .mem_resp_read_ready_o        (axi2mem_if.r_ready ),
    .mem_resp_read_valid_i        (axi2mem_if.r_valid ),
    .mem_resp_read_i              (mem_resp_read_i ),
                                    
                                       //      Write interface
    .mem_req_write_ready_i        (axi2mem_if.aw_ready   ) ,
    .mem_req_write_valid_o        (axi2mem_if.aw_valid   ) ,
    .mem_req_write_o              (mem_req_write_o    ) ,
                                      
    .mem_req_write_data_ready_i   (axi2mem_if.w_ready      ),
    .mem_req_write_data_valid_o   (axi2mem_if.w_valid      ),
    .mem_req_write_data_o         (mem_req_write_data_o ),
                                      
    .mem_resp_write_ready_o       (axi2mem_if.b_ready  ),
    .mem_resp_write_valid_i       (axi2mem_if.b_valid  ),
    .mem_resp_write_i             (mem_resp_write_i ),
                                      
    //      Performance events
    .evt_cache_write_miss_o            (perf_vif.evt_cache_write_miss_o ),
    .evt_cache_read_miss_o             (perf_vif.evt_cache_read_miss_o  ),
    .evt_uncached_req_o                (perf_vif.evt_uncached_req_o     ),
    .evt_cmo_req_o                     (perf_vif.evt_cmo_req_o          ),
    .evt_write_req_o                   (perf_vif.evt_write_req_o        ),
    .evt_read_req_o                    (perf_vif.evt_read_req_o         ),
    .evt_prefetch_req_o                (perf_vif.evt_granted_req_o      ),
    .evt_req_on_hold_o                 (perf_vif.evt_req_on_hold_o      ),
    .evt_rtab_rollback_o               (perf_vif.evt_rtab_rollback_o),
    .evt_stall_refill_o                (perf_vif.evt_stall_refill_o),
    .evt_stall_o                       (perf_vif.evt_stall_o),
                                      
    //      Status interface
    .wbuf_empty_o                      (perf_vif.wbuf_empty_o ),
                                      
    //      Configuration interface
    .cfg_enable_i                         (conf_vif.cfg_enable_i                      ),
    .cfg_wbuf_threshold_i                 (conf_vif.cfg_wbuf_threshold_i              ),
    .cfg_wbuf_reset_timecnt_on_write_i    (conf_vif.cfg_wbuf_reset_timecnt_on_write_i ),
    .cfg_wbuf_inhibit_write_coalescing_i  (conf_vif.cfg_wbuf_inhibit_write_coalescing_i),
    .cfg_wbuf_sequential_waw_i            (conf_vif.cfg_wbuf_sequential_waw_i         ),
    .cfg_prefetch_updt_plru_i             (conf_vif.cfg_hwpf_stride_updt_plru_i       ),
    .cfg_error_on_cacheable_amo_i         (conf_vif.cfg_error_on_cacheable_amo_i      ),
    .cfg_rtab_single_entry_i              (conf_vif.cfg_rtab_single_entry_i           ),
    .cfg_default_wb_i                     (conf_vif.cfg_default_wb_i)
   );

   //Binding with SVA using implicit port connection
   bind hpdcache hpdcache_SVA#(
       .hpdcacheCfg(HPDcacheCfg),
       .wbuf_timecnt_t        ( wbuf_timecnt_t),
       .hpdcache_tag_t        ( hpdcache_tag_t),
       .hpdcache_data_word_t  ( hpdcache_data_word_t),
       .hpdcache_data_be_t    ( hpdcache_data_be_t),
       .hpdcache_req_offset_t ( hpdcache_req_offset_t),
       .hpdcache_req_data_t   ( hpdcache_req_data_t),
       .hpdcache_req_be_t     ( hpdcache_req_be_t),
       .hpdcache_req_sid_t    ( hpdcache_req_sid_t),
       .hpdcache_req_tid_t    ( hpdcache_req_tid_t),
       .hpdcache_req_t        ( hpdcache_req_t),
       .hpdcache_rsp_t        ( hpdcache_rsp_t),
       .hpdcache_mem_addr_t   ( hpdcache_mem_addr_t),
       .hpdcache_mem_id_t     ( hpdcache_mem_id_t),
       .hpdcache_mem_data_t   ( hpdcache_mem_data_t),
       .hpdcache_mem_be_t     ( hpdcache_mem_be_t),
       .hpdcache_mem_req_t    ( hpdcache_mem_req_t),
       .hpdcache_mem_req_w_t  ( hpdcache_mem_req_w_t),
       .hpdcache_mem_resp_r_t ( hpdcache_mem_resp_r_t),
       .hpdcache_mem_resp_w_t ( hpdcache_mem_resp_w_t)
    //  }}}
  ) sva(.*);

   // bind dut.hpdcache_ctrl_i.st0_arb_i hpdcache_rrarb_sva#(.N(N)) sva(.*);
    bind dut.core_req_arbiter_i.req_arbiter_i   hpdcache_fxarb_sva#(.N(N)) sva(.*);
    bind hwpf_stride_wrapper_i.hwpf_stride_arb_i.hwpf_stride_req_arbiter_i hpdcache_rrarb_sva#(.N(N)) sva(.*);

 //   if (m_hpdcache_cfg.u.victimSel == 1) begin : hpdcache_victim_sel_plru_gen
 //       bind dut.hpdcache_ctrl_i.hpdcache_memctrl_i hpdcache_plru_sva#(
 //                                                                       .hpdcacheCfg(HPDcacheCfg),

 //                                                                       .hpdcache_nline_t       (hpdcache_nline_t),
 //                                                                       .hpdcache_tag_t         (hpdcache_tag_t),
 //                                                                       .hpdcache_set_t         (hpdcache_set_t),
 //                                                                       .hpdcache_word_t        (hpdcache_word_t),
 //                                                                       .hpdcache_way_vector_t  (hpdcache_way_vector_t),
 //                                                                       .hpdcache_dir_entry_t   (hpdcache_dir_entry_t),
 //                                                                      
 //                                                                       .hpdcache_data_word_t   (hpdcache_data_word_t),
 //                                                                       .hpdcache_data_be_t     (hpdcache_data_be_t),
 //                                                                                            
 //                                                                       .hpdcache_req_data_t    (hpdcache_req_data_t),
 //                                                                       .hpdcache_req_be_t      (hpdcache_req_be_t),
 //                                                                     
 //                                                                       .hpdcache_refill_data_t (hpdcache_refill_data_t),
 //                                                                       .hpdcache_refill_be_t   (hpdcache_refill_be_t) ) sva(.*);

 //       for(genvar i=0 ;  i< m_hpdcache_cfg.u.nRequesters; i++ ) begin
 //          plru_check : assert property (  @( posedge clk ) disable iff(!rst_n)
 //           dut.hpdcache_ctrl_i.hpdcache_memctrl_i.sva.m_bPLRU_table[i] == dut.hpdcache_ctrl_i.hpdcache_memctrl_i.victim_sel_i.gen_plru_victim_sel.plru_i.plru_q[i]) else
 //            `uvm_error("PLRU MISMATCH", $sformatf("Expected %0x(x), RECIEVED %0x(x), index %0d(d)",
 //                                         dut.hpdcache_ctrl_i.hpdcache_memctrl_i.sva.m_bPLRU_table[i],
 //                                         dut.hpdcache_ctrl_i.hpdcache_memctrl_i.victim_sel_i.gen_plru_victim_sel.plru_i.plru_q[i], i));
 //       end
 //   end

    // Mux inputs/output
    mem_req_t [1:0] lsu_mem_req;

    // Arbiter output
    logic [1:0]     lsu_mem_gnt;
    logic [1:0]     mem_reqs; 
    mem_req_t       arb_req;

//    assign dut.post_shutdown_phase      = post_shutdown_phase; 
//    assign mem_req_read_base_id_i  = HPDCACHE_READ_BASE_ID;
//    assign mem_req_write_base_id_i = HPDCACHE_WRITE_BASE_ID;

    // --------------------------------------------------------------------------------------
    // AXI to Dcache connections 
    // --------------------------------------------------------------------------------------
    assign axi2mem_if.ar_addr   =  mem_req_read_o.mem_req_addr;
    assign axi2mem_if.ar_len    =  mem_req_read_o.mem_req_len;
    assign axi2mem_if.ar_size   =  mem_req_read_o.mem_req_size;
    assign axi2mem_if.ar_id     =  mem_req_read_o.mem_req_id;
    assign axi2mem_if.ar_lock   = (mem_req_read_o.mem_req_command == HPDCACHE_MEM_ATOMIC &&
                                     mem_req_read_o.mem_req_atomic == HPDCACHE_MEM_ATOMIC_LDEX) ? 1: 0;
   // assign axi2mem_if.ar_atop   = mem_req_read_o.mem_req_atomic;

    assign axi2mem_if.ar_burst  = BURST_INCR;
    assign axi2mem_if.ar_cache  = CACHE_BUFFERABLE;
    assign axi2mem_if.ar_prot   = 'h0;
    assign axi2mem_if.ar_qos    = 'h0;
    assign axi2mem_if.ar_region = 'h0;
    assign axi2mem_if.ar_user   = (mem_req_read_o.mem_req_cacheable == 1'b0) ? 0: 1;

    assign mem_resp_read_i.mem_resp_r_data    = axi2mem_if.r_data;
    assign mem_resp_read_i.mem_resp_r_last    = axi2mem_if.r_last;
    assign mem_resp_read_i.mem_resp_r_id      = axi2mem_if.r_id;
    assign mem_resp_read_i.mem_resp_r_error   = (axi2mem_if.r_resp == RESP_OKAY ||axi2mem_if.r_resp == RESP_EXOKAY  ) ? HPDCACHE_MEM_RESP_OK: HPDCACHE_MEM_RESP_NOK;

    assign axi2mem_if.aw_addr        = mem_req_write_o.mem_req_addr;
    assign axi2mem_if.aw_len         = mem_req_write_o.mem_req_len;
    assign axi2mem_if.aw_size        = mem_req_write_o.mem_req_size;
    assign axi2mem_if.aw_id          = mem_req_write_o.mem_req_id;
    assign axi2mem_if.aw_atop[3]     = 1'b0;
    assign axi2mem_if.aw_atop[5:4]   = (mem_req_write_o.mem_req_command == HPDCACHE_MEM_ATOMIC && 
                                          mem_req_write_o.mem_req_atomic  == HPDCACHE_MEM_ATOMIC_SWAP) ? 2'b11 : 
                                         (mem_req_write_o.mem_req_command == HPDCACHE_MEM_ATOMIC && 
                                          mem_req_write_o.mem_req_atomic  != HPDCACHE_MEM_ATOMIC_SWAP) ? HPDCACHE_MEM_WRITE : AXI_ATOMIC_NONE;

    assign axi2mem_if.aw_atop[2:0]   = mem_req_write_o.mem_req_atomic;
    assign axi2mem_if.aw_lock        = (mem_req_write_o.mem_req_command == HPDCACHE_MEM_ATOMIC &&
                                          mem_req_write_o.mem_req_atomic == HPDCACHE_MEM_ATOMIC_STEX) ? 1: 0;

    assign axi2mem_if.w_strb = mem_req_write_data_o.mem_req_w_be;  ;
    assign axi2mem_if.w_data = mem_req_write_data_o.mem_req_w_data;    ;
    assign axi2mem_if.w_last = mem_req_write_data_o.mem_req_w_last;  ;
    assign axi2mem_if.w_user = (mem_req_write_o.mem_req_cacheable == 1'b0) ? 0: 1;;

    // ATOMIC signal
    assign  mem_resp_write_i.mem_resp_w_error = (axi2mem_if.b_resp == RESP_OKAY || axi2mem_if.b_resp == RESP_EXOKAY) ? HPDCACHE_MEM_RESP_OK: HPDCACHE_MEM_RESP_NOK;
    assign  mem_resp_write_i.mem_resp_w_id    = axi2mem_if.b_id;
    assign  mem_resp_write_i.mem_resp_w_is_atomic = (axi2mem_if.b_resp == RESP_EXOKAY) ? 1'b1: 1'b0;


    assign dram_vif.mem_req_write_data_ready_i = axi2mem_if.w_ready; 
    assign dram_vif.mem_req_write_data_valid_o = axi2mem_if.w_valid;
    assign dram_vif.mem_req_write_data_o       = mem_req_write_data_o;

   // assign mem_wr_if.src_id   = axi2mem_if.aw_id;
   // assign mem_rd_if.src_id   = axi2mem_if.ar_id;


    assign lsu_mem_req[0].req_valid     = mem_rd_if.req_valid;
    assign lsu_mem_req[0].req_addr      = mem_rd_if.req_addr;
    assign lsu_mem_req[0].req_wrn       = mem_rd_if.req_wrn ;
    assign lsu_mem_req[0].req_id        = mem_rd_if.req_id  ;
    assign lsu_mem_req[0].src_id        = mem_rd_if.src_id  ;
    assign lsu_mem_req[0].req_data      = mem_rd_if.req_data ;
    assign lsu_mem_req[0].req_strb      = mem_rd_if.req_strb ;
    assign lsu_mem_req[0].req_amo       = mem_rd_if.req_amo  ;
    assign lsu_mem_req[0].amo_op        = mem_rd_if.amo_op ;
//    assign mem_rd_if.req_ready_bp        = 1'b1; 
    

    assign lsu_mem_req[1].req_valid     = mem_wr_if.req_valid;
    assign lsu_mem_req[1].req_addr      = mem_wr_if.req_addr;
    assign lsu_mem_req[1].req_wrn       = mem_wr_if.req_wrn ;
    assign lsu_mem_req[1].req_id        = mem_wr_if.req_id  ;
    assign lsu_mem_req[1].src_id        = mem_wr_if.src_id  ;
    assign lsu_mem_req[1].req_data      = mem_wr_if.req_data ;
    assign lsu_mem_req[1].req_strb      = mem_wr_if.req_strb ;
    assign lsu_mem_req[1].req_amo       = mem_wr_if.req_amo  ;
    assign lsu_mem_req[1].amo_op        = mem_wr_if.amo_op ;
//    assign mem_wr_if.req_ready_bp        = 1'b1; 

    assign mem_reqs[0] = mem_rd_if.req_valid; 
    assign mem_reqs[1] = mem_wr_if.req_valid; 

    assign mem_rd_if.req_ready                    = lsu_mem_gnt[0] & mem_rsp_if.req_ready;
    assign mem_wr_if.req_ready                    = lsu_mem_gnt[1] & mem_rsp_if.req_ready;
    // ----------------------------------------------------------
    // Round-robin arbiter
    // Arbiter is needed since memory has only one interface 
    // ----------------------------------------------------------
    hpdcache_rrarb #(.N(2)) valid_arbiter_i
    (
        .clk_i (clk),
        .rst_ni (rst_n),
        .req_i          (mem_reqs),
        .gnt_o          (lsu_mem_gnt),
        .ready_i        (mem_rsp_if.req_ready)
    );

    // One-hot multiplexor
    hpdcache_mux #(
        .NINPUT         (2),
        .DATA_WIDTH     ($bits(mem_req_t)),
        .ONE_HOT_SEL    (1'b1)
    ) lsu_req_mux_i (
        .data_i         (lsu_mem_req),
        .sel_i          (lsu_mem_gnt),
        .data_o         (arb_req)
    );

    // -------------------------------------------------
    //  Memory request assign + atomics
    // -------------------------------------------------
    always_comb begin: mem_req
        mem_rsp_if.req_valid =  arb_req.req_valid;
        mem_rsp_if.req_addr  =  arb_req.req_addr;
        mem_rsp_if.req_id    =  arb_req.req_id;
        mem_rsp_if.src_id    =  arb_req.src_id;
        mem_rsp_if.req_wrn   =  arb_req.req_wrn;
        mem_rsp_if.req_data  =  arb_req.req_data;
        mem_rsp_if.req_strb  =  arb_req.req_strb;
        mem_rsp_if.req_amo   =  arb_req.req_amo;
        mem_rsp_if.amo_op    =  arb_req.amo_op;
        mem_rsp_if.req_ready = mem_rsp_if.req_ready_bp;
    end


    // -------------------------------------------------
    // read miss uses upto 127 ids for the miss  
    // -------------------------------------------------
    always_comb begin: read_resp
       mem_rd_if.rd_res_valid   =  mem_rsp_if.rd_res_valid;
       mem_rd_if.rd_res_data    =  mem_rsp_if.rd_res_data;
       mem_rd_if.rd_res_err     = (mem_rsp_if.rd_res_err == 0) ? 0: 1;
       mem_rd_if.rd_res_id      =  mem_rsp_if.rd_res_id;
       mem_rd_if.rd_res_addr    =  mem_rsp_if.rd_res_addr;
	   mem_rd_if.rd_res_ex_fail  = mem_rsp_if.rd_res_ex_fail;	
       mem_rd_if.wr_res_valid   =  0; 
    end

    always_comb begin: write_resp
       mem_wr_if.wr_res_valid    = mem_rsp_if.wr_res_valid;
       mem_wr_if.wr_res_err      = (mem_rsp_if.wr_res_err == 0) ? 0: 1;
       mem_wr_if.wr_res_id       = mem_rsp_if.wr_res_id;
       mem_wr_if.wr_res_addr     = mem_rsp_if.wr_res_addr;
	   mem_wr_if.wr_res_ex_fail  = mem_rsp_if.wr_res_ex_fail;	
       mem_wr_if.rd_res_valid    = 0;
    end


    always_comb begin: read_req_mon
      dram_vif.mem_req_read_ready_i   = axi2mem_if.ar_ready;
      dram_vif.mem_req_read_valid_o   = axi2mem_if.ar_valid; 
      dram_vif.mem_req_read_o         = mem_req_read_o;
      dram_vif.mem_req_read_base_id_i = mem_req_read_base_id_i;
    end

    always_comb begin: wbuf_write_req_mon
      dram_vif.mem_req_write_ready_i   = axi2mem_if.aw_ready;
      dram_vif.mem_req_write_valid_o   = axi2mem_if.aw_valid; 
      dram_vif.mem_req_write_o         = mem_req_write_o;
      dram_vif.mem_req_write_base_id_i = mem_req_write_base_id_i;
    end

    always_comb begin: wbuf_write_req_ext_mon
      dram_vif.mem_req_write_valid_int_o                      = lsu_mem_req[1].req_valid; 
      dram_vif.mem_req_write_int_o.valid                      = lsu_mem_req[1].req_valid;   
      dram_vif.mem_req_write_int_o.mem_req.mem_req_addr       = lsu_mem_req[1].req_addr;  
      dram_vif.mem_req_write_int_o.mem_req.mem_req_id         = lsu_mem_req[1].req_id;  
      dram_vif.mem_req_write_int_o.mem_req.mem_req_cacheable  = (lsu_mem_req[1].req_id ==  {HPDCACHE_MEM_ID_WIDTH{1'b1}}) ? 0: 1;  
      dram_vif.mem_req_write_int_o.mem_req.mem_req_command    = (lsu_mem_req[1].req_wrn == 0 && lsu_mem_req[1].req_amo == 0 ) ? HPDCACHE_MEM_WRITE :
                                                                     (lsu_mem_req[1].req_wrn == 0 && lsu_mem_req[1].req_amo == 1 ) ? HPDCACHE_MEM_ATOMIC : HPDCACHE_MEM_READ;  
      dram_vif.mem_req_write_int_o.valid                      = lsu_mem_req[1].req_valid;   
      dram_vif.mem_req_write_int_o.mem_data                   = lsu_mem_req[1].req_data; 
      dram_vif.mem_req_write_int_o.mem_be                     = lsu_mem_req[1].req_strb;
      case(lsu_mem_req[1].amo_op)
        MEM_ATOMIC_ADD:  dram_vif.mem_req_write_int_o.mem_req.mem_req_atomic = HPDCACHE_MEM_ATOMIC_ADD; 	 		
        MEM_ATOMIC_CLR:  dram_vif.mem_req_write_int_o.mem_req.mem_req_atomic = HPDCACHE_MEM_ATOMIC_CLR;      
        MEM_ATOMIC_SET:  dram_vif.mem_req_write_int_o.mem_req.mem_req_atomic = HPDCACHE_MEM_ATOMIC_SET; 	 		
        MEM_ATOMIC_EOR:  dram_vif.mem_req_write_int_o.mem_req.mem_req_atomic = HPDCACHE_MEM_ATOMIC_EOR;      		
        MEM_ATOMIC_SMAX: dram_vif.mem_req_write_int_o.mem_req.mem_req_atomic = HPDCACHE_MEM_ATOMIC_SMAX;	 
        MEM_ATOMIC_SMIN: dram_vif.mem_req_write_int_o.mem_req.mem_req_atomic = HPDCACHE_MEM_ATOMIC_SMIN;     		
        MEM_ATOMIC_UMAX: dram_vif.mem_req_write_int_o.mem_req.mem_req_atomic = HPDCACHE_MEM_ATOMIC_UMAX;	 		
        MEM_ATOMIC_UMIN: dram_vif.mem_req_write_int_o.mem_req.mem_req_atomic = HPDCACHE_MEM_ATOMIC_UMIN;     
        MEM_ATOMIC_SWAP: dram_vif.mem_req_write_int_o.mem_req.mem_req_atomic = HPDCACHE_MEM_ATOMIC_SWAP;		
        MEM_ATOMIC_LDEX: dram_vif.mem_req_write_int_o.mem_req.mem_req_atomic = HPDCACHE_MEM_ATOMIC_LDEX;	
        MEM_ATOMIC_STEX: dram_vif.mem_req_write_int_o.mem_req.mem_req_atomic = HPDCACHE_MEM_ATOMIC_STEX;
      endcase
    end

    // -------------------------------------------------
    // read miss uses upto 127 ids for the miss  
    // -------------------------------------------------
    always_comb begin: read_resp_mon
        dram_vif.mem_resp_read_valid_int_i        = axi2mem_if.r_valid;
        dram_vif.mem_resp_read_ready_o            = axi2mem_if.r_ready;
        dram_vif.mem_resp_read_int_i              = mem_resp_read_i;
    end

    // -------------------------------------------------
    // wbuf write uses upto 127 ids for the miss  
    // -------------------------------------------------
    always_comb begin: wbuf_write_resp_mon
        dram_vif.mem_resp_write_valid_i            = axi2mem_if.b_valid;
        dram_vif.mem_resp_write_ready_o            = axi2mem_if.b_ready;
        dram_vif.mem_resp_write_i                  = mem_resp_write_i;
    end


//    assign dram_vif.mem_req_read_ready_i       = lsu_mem_gnt[0] & mem_rsp_if.req_ready;
    assign dram_vif.mem_req_write_ready_int_i  = lsu_mem_gnt[1] & mem_rsp_if.req_ready;

   // -----------------------------------------------------------------
   // Pass interface to UVM database + start the test
   // -----------------------------------------------------------------
   for(genvar k=0 ;  k< m_hpdcache_cfg.u.nRequesters; k++ ) begin : HPDCACHE_REQ
     initial uvm_config_db #( virtual hpdcache_if )::set(null, "*", $sformatf("hpdcache_agent_%0d", k) , hpdcache_vif[k] ) ;
   end

   initial begin
       $timeformat(-12,0," ps", 7);
       uvm_config_db #( virtual dram_if )::set(null, "*", "DRAM_IF" , dram_vif ) ;
       uvm_config_db #( virtual perf_if )::set(null, "*", "PERF_IF" , perf_vif ) ;
       uvm_config_db #( virtual conf_if )::set(null, "*", "CONF_IF" , conf_vif ) ;
       uvm_config_db #( virtual misc_if )::set(uvm_root::get(), "*", "MISC_IF",  hpdcache_misc_if);
       uvm_config_db #( virtual hwpf_stride_cfg_if )::set(null, "*", "PREFETCHER_IF" , hwpf_stride_cfg_vif ) ;
       uvm_config_db #( virtual xrtl_reset_vif #( 1'b1,50,0) )::set(uvm_root::get(), "*", "hpdcache_reset_driver", reset_if );
       uvm_config_db #( virtual pulse_if)::set(uvm_root::get(), "*", "hpdcache_flush_driver", flush_vif );
       uvm_config_db #( virtual xrtl_clock_vif)::set(uvm_root::get() , "*" , "clock_driver" , clock_if);
       uvm_config_db #( virtual bp_vif #(1))::set(uvm_root::get(), "*", "bp_read_agent", m_read_bp_vif);
       uvm_config_db #( virtual bp_vif #(1))::set(uvm_root::get(), "*", "bp_write_req_agent", m_write_req_bp_vif);
       uvm_config_db #( virtual bp_vif #(1))::set(uvm_root::get(), "*", "bp_write_data_agent", m_write_data_bp_vif);

        uvm_config_db #(virtual memory_response_if#(
            HPDCACHE_PA_WIDTH, 
            HPDCACHE_MEM_DATA_WIDTH, 
            HPDCACHE_MEM_ID_WIDTH
        ))::set(uvm_root::get( ), "*", "mem_rsp_model" , mem_rsp_if ) ;

        uvm_config_db #(virtual axi_if#(
            HPDCACHE_PA_WIDTH, 
            HPDCACHE_MEM_DATA_WIDTH, 
            HPDCACHE_MEM_ID_WIDTH, 1
        ))::set(uvm_root::get( ), "*", "axi2mem_req" , axi2mem_if ) ;

        uvm_config_db #(virtual memory_response_if#(
            HPDCACHE_PA_WIDTH, 
            HPDCACHE_MEM_DATA_WIDTH, 
            HPDCACHE_MEM_ID_WIDTH
        ))::set(uvm_root::get( ), "*", "axi2mem_req_rd" , mem_rd_if ) ;

        uvm_config_db #(virtual memory_response_if#(
            HPDCACHE_PA_WIDTH, 
            HPDCACHE_MEM_DATA_WIDTH, 
            HPDCACHE_MEM_ID_WIDTH
        ))::set(uvm_root::get( ), "*", "axi2mem_req_wr" , mem_wr_if ) ;


        run_test();
   end

  // -----------------------------------------------------------------
  // Simple initial to show that the time is passing in the log
  // -----------------------------------------------------------------
  initial begin
    forever begin
      #10000;
      $display("[Time Info] : Time Snapshot at %10d", $time);
    end  
  end

endmodule : top
