// ----------------------------------------------------------------------------
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
//  Description : Common functions  
// ----------------------------------------------------------------------------
package hpdcache_common_pkg;
  
  import uvm_pkg::*;
  import hpdcache_pkg::*;
  import hwpf_stride_pkg::*;
  `include "uvm_macros.svh"
  `include "hpdcache_typedef.svh"

    // Paramters from old package of HPDCACHE  (they are now passed in the top
    // module instance) 
    //
        //  Definition of global constants for the HPDcache data and directory
    //  {{{

    //  HPDcache physical address width (bits)
    localparam int unsigned HPDCACHE_PA_WIDTH = hpdcache_params_pkg::PARAM_PA_WIDTH;

    //  HPDcache number of sets
    localparam int unsigned HPDCACHE_SETS = hpdcache_params_pkg::PARAM_SETS;

    //  HPDcache number of ways
    localparam int unsigned HPDCACHE_WAYS = hpdcache_params_pkg::PARAM_WAYS;

    //  HPDcache word width (bits)
    localparam int unsigned HPDCACHE_WORD_WIDTH = hpdcache_params_pkg::PARAM_WORD_WIDTH;

    //  HPDcache cache-line width (bits)
    localparam int unsigned HPDCACHE_CL_WORDS = hpdcache_params_pkg::PARAM_CL_WORDS;

    //  HPDcache number of words in the request data channels (request and response)
    localparam int unsigned HPDCACHE_REQ_WORDS = hpdcache_params_pkg::PARAM_REQ_WORDS;

    //  HPDcache request transaction ID width (bits)
    localparam int unsigned HPDCACHE_REQ_TRANS_ID_WIDTH = hpdcache_params_pkg::PARAM_REQ_TRANS_ID_WIDTH;

    //  HPDcache request source ID width (bits)
    localparam int unsigned HPDCACHE_REQ_SRC_ID_WIDTH = hpdcache_params_pkg::PARAM_REQ_SRC_ID_WIDTH;
    //  }}}

    //  Definition of constants and types for HPDcache directory memory
    //  {{{
    localparam int unsigned HPDCACHE_CL_WIDTH       = HPDCACHE_CL_WORDS*HPDCACHE_WORD_WIDTH;
    localparam int unsigned HPDCACHE_OFFSET_WIDTH   = $clog2(HPDCACHE_CL_WIDTH/8);
    localparam int unsigned HPDCACHE_NLINE_WIDTH    = HPDCACHE_PA_WIDTH - HPDCACHE_OFFSET_WIDTH;
    localparam int unsigned HPDCACHE_SET_WIDTH      = $clog2(HPDCACHE_SETS);
    localparam int unsigned HPDCACHE_TAG_WIDTH      = HPDCACHE_NLINE_WIDTH - HPDCACHE_SET_WIDTH;
    localparam int unsigned HPDCACHE_WORD_IDX_WIDTH = $clog2(HPDCACHE_CL_WORDS);


    localparam int unsigned HPDCACHE_VICTIM_SEL = hpdcache_params_pkg::PARAM_VICTIM_SEL;

    typedef logic unsigned [  HPDCACHE_OFFSET_WIDTH-1:0] hpdcache_offset_t;
    typedef logic unsigned [   HPDCACHE_NLINE_WIDTH-1:0] hpdcache_nline_t;
    typedef logic unsigned [     HPDCACHE_SET_WIDTH-1:0] hpdcache_set_t;
    typedef logic unsigned [     HPDCACHE_TAG_WIDTH-1:0] hpdcache_tag_t;
    typedef logic unsigned [  $clog2(HPDCACHE_WAYS)-1:0] hpdcache_way_t;
    typedef logic unsigned [          HPDCACHE_WAYS-1:0] hpdcache_way_vector_t;
    typedef logic unsigned [HPDCACHE_WORD_IDX_WIDTH-1:0] hpdcache_word_t;

    localparam int unsigned HPDCACHE_DIR_RAM_DEPTH       = HPDCACHE_SETS;
    localparam int unsigned HPDCACHE_DIR_RAM_ADDR_WIDTH  = $clog2(HPDCACHE_DIR_RAM_DEPTH);

    typedef logic [HPDCACHE_DIR_RAM_ADDR_WIDTH-1:0] hpdcache_dir_addr_t;

    function automatic hpdcache_way_t hpdcache_way_vector_to_index(input hpdcache_way_vector_t way);
        for (int unsigned i = 0; i < HPDCACHE_WAYS; i++) begin
            if (way[i]) return hpdcache_way_t'(i);
        end
        return 0;
    endfunction
    //  }}}

    //  Definition of constants and types for HPDcache data memory
    //  {{{
    localparam int unsigned HPDCACHE_DATA_WAYS_PER_RAM_WORD =
        hpdcache_params_pkg::PARAM_DATA_WAYS_PER_RAM_WORD;

    localparam int unsigned HPDCACHE_DATA_SETS_PER_RAM = 
        hpdcache_params_pkg::PARAM_DATA_SETS_PER_RAM;

    //  HPDcache DATA RAM implements write byte enable
    localparam bit HPDCACHE_DATA_RAM_WBYTEENABLE =
        hpdcache_params_pkg::PARAM_DATA_RAM_WBYTEENABLE;

    //  Define the number of memory contiguous words that can be accessed
    //  simultaneously from the cache.
    //  -  This limits the maximum width for the data channel from requesters
    //  -  This impacts the refill latency
    localparam int unsigned HPDCACHE_ACCESS_WORDS = hpdcache_params_pkg::PARAM_ACCESS_WORDS;


    localparam int unsigned HPDCACHE_DATA_RAM_WIDTH        =
            HPDCACHE_DATA_WAYS_PER_RAM_WORD*HPDCACHE_WORD_WIDTH;
    localparam int unsigned HPDCACHE_DATA_RAM_Y_CUTS       = HPDCACHE_WAYS/HPDCACHE_DATA_WAYS_PER_RAM_WORD;
    localparam int unsigned HPDCACHE_DATA_RAM_X_CUTS       = HPDCACHE_ACCESS_WORDS;
    localparam int unsigned HPDCACHE_DATA_RAM_ACCESS_WIDTH = HPDCACHE_ACCESS_WORDS*HPDCACHE_WORD_WIDTH;
    localparam int unsigned HPDCACHE_DATA_RAM_ENTR_PER_SET = HPDCACHE_CL_WORDS/HPDCACHE_ACCESS_WORDS;
    localparam int unsigned HPDCACHE_DATA_RAM_DEPTH        = HPDCACHE_SETS*HPDCACHE_DATA_RAM_ENTR_PER_SET;
    localparam int unsigned HPDCACHE_DATA_RAM_ADDR_WIDTH   = $clog2(HPDCACHE_DATA_RAM_DEPTH);

    typedef logic [                     HPDCACHE_WORD_WIDTH-1:0]      hpdcache_data_word_t;
    typedef logic [                   HPDCACHE_WORD_WIDTH/8-1:0]      hpdcache_data_be_t;
    typedef logic [                HPDCACHE_DATA_RAM_Y_CUTS-1:0]      hpdcache_data_ram_row_idx_t;
    typedef logic [ $clog2(HPDCACHE_DATA_WAYS_PER_RAM_WORD)-1:0]      hpdcache_data_ram_way_idx_t;

    typedef logic [HPDCACHE_DATA_RAM_ADDR_WIDTH-1:0]                  hpdcache_data_ram_addr_t;
    typedef hpdcache_data_word_t[HPDCACHE_DATA_WAYS_PER_RAM_WORD-1:0] hpdcache_data_ram_data_t;
    typedef hpdcache_data_be_t  [HPDCACHE_DATA_WAYS_PER_RAM_WORD-1:0] hpdcache_data_ram_be_t;

    typedef hpdcache_data_ram_data_t
        [HPDCACHE_DATA_RAM_Y_CUTS-1:0]
        [HPDCACHE_DATA_RAM_X_CUTS-1:0]
        hpdcache_data_entry_t;

    typedef hpdcache_data_ram_be_t
        [HPDCACHE_DATA_RAM_Y_CUTS-1:0]
        [HPDCACHE_DATA_RAM_X_CUTS-1:0]
        hpdcache_data_be_entry_t;

    typedef logic
        [HPDCACHE_DATA_RAM_X_CUTS-1:0]
        hpdcache_data_row_enable_t;

    typedef hpdcache_data_row_enable_t
        [HPDCACHE_DATA_RAM_Y_CUTS-1:0]
        hpdcache_data_enable_t;

    typedef hpdcache_data_ram_addr_t
        [HPDCACHE_DATA_RAM_Y_CUTS-1:0]
        [HPDCACHE_DATA_RAM_X_CUTS-1:0]
        hpdcache_data_addr_t;
    //  }}}

    //  Definition of interface with miss handler
    //  {{{
    localparam int unsigned HPDCACHE_REFILL_DATA_WIDTH = HPDCACHE_DATA_RAM_ACCESS_WIDTH;

    //    Use feedthrough FIFOs from the refill handler to the core. This
    //    reduces the latency (by one cycle) but adds an additional timing path
    localparam bit HPDCACHE_REFILL_CORE_RSP_FEEDTHROUGH =
        hpdcache_params_pkg::PARAM_REFILL_CORE_RSP_FEEDTHROUGH;

    //    Depth of the FIFO on the refill memory interface.
    localparam int unsigned HPDCACHE_REFILL_FIFO_DEPTH = hpdcache_params_pkg::PARAM_REFILL_FIFO_DEPTH;

    typedef hpdcache_data_word_t[HPDCACHE_ACCESS_WORDS-1:0] hpdcache_refill_data_t;
    typedef hpdcache_data_be_t  [HPDCACHE_ACCESS_WORDS-1:0] hpdcache_refill_be_t;
    //  }}}

    //  Definition of interface with requesters
    //  {{{
    localparam int unsigned HPDCACHE_REQ_DATA_WIDTH = HPDCACHE_REQ_WORDS*HPDCACHE_WORD_WIDTH;
    localparam int unsigned HPDCACHE_REQ_DATA_BYTES = HPDCACHE_REQ_DATA_WIDTH/8;
    localparam int unsigned HPDCACHE_REQ_WORD_INDEX_WIDTH = $clog2(HPDCACHE_REQ_WORDS);
    localparam int unsigned HPDCACHE_REQ_BYTE_OFFSET_WIDTH = $clog2(HPDCACHE_REQ_DATA_BYTES);
    localparam int unsigned HPDCACHE_REQ_OFFSET_WIDTH = HPDCACHE_PA_WIDTH - HPDCACHE_TAG_WIDTH;

    typedef logic                       [HPDCACHE_PA_WIDTH-1:0] hpdcache_req_addr_t;
    typedef logic               [HPDCACHE_REQ_OFFSET_WIDTH-1:0] hpdcache_req_offset_t;
    typedef hpdcache_data_word_t       [HPDCACHE_REQ_WORDS-1:0] hpdcache_req_data_t;
    typedef hpdcache_data_be_t         [HPDCACHE_REQ_WORDS-1:0] hpdcache_req_be_t;
    typedef logic               [HPDCACHE_REQ_SRC_ID_WIDTH-1:0] hpdcache_req_sid_t;
    typedef logic             [HPDCACHE_REQ_TRANS_ID_WIDTH-1:0] hpdcache_req_tid_t;

    //      Definition of interfaces
    //      {{{
    //          Request Interface
    typedef struct packed
    {
        hpdcache_req_offset_t addr_offset;
        hpdcache_req_data_t   wdata;
        hpdcache_req_op_t     op;
        hpdcache_req_be_t     be;
        hpdcache_req_size_t   size;
        hpdcache_req_sid_t    sid;
        hpdcache_req_tid_t    tid;
        logic                 need_rsp;

        //  only valid in case of physically indexed requests
        logic                 phys_indexed;
        hpdcache_tag_t        addr_tag;
        hpdcache_pma_t        pma;
    } hpdcache_req_t;

    //          Response Interface
    typedef struct packed
    {
        hpdcache_req_data_t   rdata;
        hpdcache_req_sid_t    sid;
        hpdcache_req_tid_t    tid;
        logic                 error;
        logic                 aborted;
    } hpdcache_rsp_t;
    //      }}}


    function automatic hpdcache_tag_t hpdcache_get_req_addr_tag(input hpdcache_req_addr_t addr);
        return addr[(HPDCACHE_OFFSET_WIDTH + HPDCACHE_SET_WIDTH) +: HPDCACHE_TAG_WIDTH];
    endfunction

    function automatic hpdcache_set_t hpdcache_get_req_addr_set(input hpdcache_req_addr_t addr);
        return addr[HPDCACHE_OFFSET_WIDTH +: HPDCACHE_SET_WIDTH];
    endfunction

    function automatic hpdcache_word_t hpdcache_get_req_addr_word(input hpdcache_req_addr_t addr);
        return addr[$clog2(HPDCACHE_WORD_WIDTH/8) +: HPDCACHE_WORD_IDX_WIDTH];
    endfunction

    function automatic hpdcache_offset_t hpdcache_get_req_addr_offset(input hpdcache_req_addr_t addr);
        return addr[0 +: HPDCACHE_OFFSET_WIDTH];
    endfunction

    function automatic hpdcache_nline_t hpdcache_get_req_addr_nline(input hpdcache_req_addr_t addr);
        return addr[HPDCACHE_OFFSET_WIDTH +: HPDCACHE_NLINE_WIDTH];
    endfunction

    function automatic hpdcache_req_offset_t hpdcache_get_req_addr_offset_and_set(input hpdcache_req_addr_t addr);
        return addr[0 +: (HPDCACHE_OFFSET_WIDTH + HPDCACHE_SET_WIDTH)];
    endfunction

    function automatic hpdcache_set_t hpdcache_get_req_offset_set(input hpdcache_req_offset_t offset);
        return offset[HPDCACHE_OFFSET_WIDTH +: HPDCACHE_SET_WIDTH];
    endfunction

    function automatic hpdcache_word_t hpdcache_get_req_offset_word(input hpdcache_req_offset_t offset);
        return offset[$clog2(HPDCACHE_WORD_WIDTH/8) +: HPDCACHE_WORD_IDX_WIDTH];
    endfunction

    //      }}}
    //  }}}

    //  Definition of constants and types for the Miss Status Holding Register (MSHR)
    //  {{{

    //  HPDcache MSHR number of sets
    localparam int unsigned HPDCACHE_MSHR_SETS =
        hpdcache_params_pkg::PARAM_MSHR_SETS;

    //  HPDcache MSHR number of ways
    localparam int unsigned HPDCACHE_MSHR_WAYS =
        hpdcache_params_pkg::PARAM_MSHR_WAYS;

    //  HPDcache MSHR number of ways in the same SRAM word
    localparam int unsigned HPDCACHE_MSHR_WAYS_PER_RAM_WORD =
        hpdcache_params_pkg::PARAM_MSHR_WAYS_PER_RAM_WORD;

    //  HPDcache MSHR number of sets in the same SRAM
    localparam int unsigned HPDCACHE_MSHR_SETS_PER_RAM =
        hpdcache_params_pkg::PARAM_MSHR_SETS_PER_RAM;

    //  HPDcache MSHR implements write byte enable
    localparam bit HPDCACHE_MSHR_RAM_WBYTEENABLE =
        hpdcache_params_pkg::PARAM_MSHR_RAM_WBYTEENABLE;
    localparam bit HPDCACHE_MSHR_USE_REGBANK =
        hpdcache_params_pkg::PARAM_MSHR_USE_REGBANK;

    localparam int unsigned HPDCACHE_MSHR_SET_WIDTH =
            (HPDCACHE_MSHR_SETS > 1) ? $clog2(HPDCACHE_MSHR_SETS) : 1;
    localparam int unsigned HPDCACHE_MSHR_WAY_WIDTH =
            (HPDCACHE_MSHR_WAYS > 1) ? $clog2(HPDCACHE_MSHR_WAYS) : 1;
    localparam int unsigned HPDCACHE_MSHR_TAG_WIDTH =
            (HPDCACHE_MSHR_SETS > 1) ? HPDCACHE_NLINE_WIDTH - HPDCACHE_MSHR_SET_WIDTH :
                                       HPDCACHE_NLINE_WIDTH;

    typedef logic unsigned [HPDCACHE_MSHR_SET_WIDTH-1:0] mshr_set_t;
    typedef logic unsigned [HPDCACHE_MSHR_TAG_WIDTH-1:0] mshr_tag_t;
    typedef logic unsigned [HPDCACHE_MSHR_WAY_WIDTH-1:0] mshr_way_t;
    //  }}}



    function automatic hpdcache_mem_size_t get_hpdcache_mem_size(int unsigned bytes);
        if      (bytes ==   0) return 0;
        else if (bytes <=   2) return 1;
        else if (bytes <=   4) return 2;
        else if (bytes <=   8) return 3;
        else if (bytes <=  16) return 4;
        else if (bytes <=  32) return 5;
        else if (bytes <=  64) return 6;
        else if (bytes <= 128) return 7;
        else begin
`ifndef HPDCACHE_ASSERT_OFF
            assert (1) $error("hpdcache: unsupported number of bytes");
`endif
            return 0;
        end
    endfunction
    //  }}}

    //  Definition of constants and types for the Write Buffer (WBUF)
    //  {{{
    localparam int unsigned HPDCACHE_WBUF_DIR_ENTRIES =
        hpdcache_params_pkg::PARAM_WBUF_DIR_ENTRIES;

    localparam int unsigned HPDCACHE_WBUF_DATA_ENTRIES =
        hpdcache_params_pkg::PARAM_WBUF_DATA_ENTRIES;

    localparam int unsigned HPDCACHE_WBUF_WORDS =
        hpdcache_params_pkg::PARAM_WBUF_WORDS;

    localparam int unsigned HPDCACHE_WBUF_TIMECNT_WIDTH =
        hpdcache_params_pkg::PARAM_WBUF_TIMECNT_WIDTH;

    //    Use feedthrough FIFOs from the write-buffer to the NoC. This reduces
    //    the latency (by one cycle) but adds an additional timing path
    localparam bit HPDCACHE_WBUF_SEND_FEEDTHROUGH =
        hpdcache_params_pkg::PARAM_WBUF_SEND_FEEDTHROUGH;

    localparam int unsigned HPDCACHE_WBUF_DATA_WIDTH     = HPDCACHE_REQ_DATA_WIDTH*
                                                           HPDCACHE_WBUF_WORDS;
    localparam int unsigned HPDCACHE_WBUF_DATA_PTR_WIDTH = $clog2(HPDCACHE_WBUF_DATA_ENTRIES);
    localparam int unsigned HPDCACHE_WBUF_DIR_PTR_WIDTH  = $clog2(HPDCACHE_WBUF_DIR_ENTRIES);

    typedef hpdcache_req_addr_t                                 wbuf_addr_t;
    typedef hpdcache_nline_t                                    wbuf_match_t;
    typedef hpdcache_req_data_t                                 wbuf_data_t;
    typedef hpdcache_req_be_t                                   wbuf_be_t;
    typedef wbuf_data_t[HPDCACHE_WBUF_WORDS-1:0]                wbuf_data_buf_t;
    typedef wbuf_be_t  [HPDCACHE_WBUF_WORDS-1:0]                wbuf_be_buf_t;
    typedef logic unsigned   [ HPDCACHE_WBUF_TIMECNT_WIDTH-1:0] wbuf_timecnt_t;
    typedef logic unsigned   [ HPDCACHE_WBUF_DIR_PTR_WIDTH-1:0] wbuf_dir_ptr_t;
    typedef logic unsigned   [HPDCACHE_WBUF_DATA_PTR_WIDTH-1:0] wbuf_data_ptr_t;
    //  }}}

    //  Definition of constants and types for the Replay Table (RTAB)
    //  {{{
    localparam int HPDCACHE_RTAB_ENTRIES = hpdcache_params_pkg::PARAM_RTAB_ENTRIES;

    typedef logic [$clog2(HPDCACHE_RTAB_ENTRIES)-1:0] rtab_ptr_t;
    //  }}}


    localparam int unsigned HPDCACHE_BYTE_PER_WORD = HPDCACHE_WORD_WIDTH/8;
    localparam int unsigned NUM_MEM_WBUF_WORDS     = HPDCACHE_CL_WORDS; 
    localparam int unsigned REQ_WBUF_RATIO         = HPDCACHE_WBUF_DATA_WIDTH/HPDCACHE_REQ_DATA_WIDTH;

`ifdef CONFIG1_HPC
    localparam int unsigned HPDCACHE_MEM_ID_WIDTH   = 8;
    localparam int unsigned HPDCACHE_MEM_DATA_WIDTH = 512; 
    localparam int unsigned NREQUESTERS             = 8 ;
`elsif CONFIG2_HPC
    localparam int unsigned HPDCACHE_MEM_ID_WIDTH   = 8;
    localparam int unsigned HPDCACHE_MEM_DATA_WIDTH = 64; 
    localparam int unsigned NREQUESTERS             = 4 ;
`elsif CONFIG3_EMBEDDED
    localparam int unsigned HPDCACHE_MEM_ID_WIDTH   = 4;
    localparam int unsigned HPDCACHE_MEM_DATA_WIDTH = 128; 
    localparam int unsigned NREQUESTERS             = 4 ;
`elsif CONFIG4_EMBEDDED
    localparam int unsigned HPDCACHE_MEM_ID_WIDTH   = 3;
    localparam int unsigned HPDCACHE_MEM_DATA_WIDTH = 32;
    localparam int unsigned NREQUESTERS             = 4 ;
`else
    localparam int unsigned HPDCACHE_MEM_ID_WIDTH   = 8;
    localparam int unsigned HPDCACHE_MEM_DATA_WIDTH = HPDCACHE_CL_WORDS*HPDCACHE_WORD_WIDTH;
    localparam int unsigned NREQUESTERS             = 4 ;
`endif
    
    localparam int unsigned HPDCACHE_MEM_LOAD_NUM  = ( HPDCACHE_WORD_WIDTH*HPDCACHE_CL_WORDS/HPDCACHE_MEM_DATA_WIDTH == 0) ? 1: HPDCACHE_WORD_WIDTH*HPDCACHE_CL_WORDS/HPDCACHE_MEM_DATA_WIDTH;


    typedef logic [HPDCACHE_PA_WIDTH-1:0]            hpdcache_mem_addr_t;
    typedef logic [HPDCACHE_MEM_ID_WIDTH-1:0]        hpdcache_mem_id_t;
    typedef logic [HPDCACHE_MEM_DATA_WIDTH-1:0]      hpdcache_mem_data_pkg_t;
    typedef logic [HPDCACHE_MEM_DATA_WIDTH/8-1:0]    hpdcache_mem_be_pkg_t;

    `HPDCACHE_TYPEDEF_MEM_REQ_T(hpdcache_mem_req_t, hpdcache_mem_addr_t, hpdcache_mem_id_t);
    `HPDCACHE_TYPEDEF_MEM_RESP_R_T(hpdcache_mem_resp_r_t, hpdcache_mem_id_t, hpdcache_mem_data_pkg_t);
    `HPDCACHE_TYPEDEF_MEM_REQ_W_T(hpdcache_mem_req_w_t, hpdcache_mem_data_pkg_t, hpdcache_mem_be_pkg_t);
    `HPDCACHE_TYPEDEF_MEM_RESP_W_T(hpdcache_mem_resp_w_t, hpdcache_mem_id_t);

    typedef logic [HPDCACHE_MEM_DATA_WIDTH*HPDCACHE_MEM_LOAD_NUM-1:0]      hpdcache_mem_data_t;
    typedef logic [HPDCACHE_MEM_DATA_WIDTH*HPDCACHE_MEM_LOAD_NUM/8-1:0]    hpdcache_mem_be_t;
 //   typedef logic [63:0] hwpf_stride_param_t;

    typedef struct packed {
        hpdcache_req_offset_t addr_offset;
        hpdcache_req_data_t   wdata;
        hpdcache_req_op_t     op;
        hpdcache_req_be_t     be;
        hpdcache_req_size_t   size;
        hpdcache_req_sid_t    sid;
        hpdcache_req_tid_t    tid;
        logic                 need_rsp;

        //  only valid in case of physically indexed requests
        logic                 phys_indexed;
        hpdcache_tag_t        addr_tag;
        hpdcache_pma_t        pma;
        
        logic                   abort;
        hpdcache_req_addr_t     addr;
        logic                   second_cycle;
    } hpdcache_req_mon_t;

    typedef struct packed {
        hpdcache_req_addr_t    addr;      
        hpdcache_req_data_t    rdata;
        hpdcache_req_sid_t     sid;
        hpdcache_req_tid_t     tid;
        logic                error;           
    } hpdcache_ext_rsp_t;

    typedef struct packed {
        hpdcache_mem_resp_r_t  mem_rsp;
        hpdcache_mem_addr_t    mem_req_addr;        
    } hpdcache_mem_ext_resp_r_t;

    typedef struct packed {
        hpdcache_mem_resp_w_t  mem_rsp;
        hpdcache_mem_addr_t    mem_req_addr;        
    } hpdcache_mem_ext_resp_w_t;

    typedef struct packed {
        hpdcache_mem_req_t        mem_req;
        hpdcache_mem_id_t         base_id;
        hpdcache_mem_data_t       mem_data;    
        hpdcache_mem_be_t         mem_be;
        logic                     valid;
    } hpdcache_mem_ext_req_t;

    typedef struct packed {
        hpdcache_word_t           word;
        hpdcache_req_data_t       data;    
        hpdcache_req_be_t         be;
        logic                   load_inflight;
        logic                   store_inflight;
    } hpdcache_pipeline_store_t;

  // print hpdcache req
  function void print_hpdcache_req_t(hpdcache_req_mon_t R, string S);
      `uvm_info(S, $sformatf("OP=%0s SID=%0x(x), TID=%0x(x), ADDR=%0x(x) SET=%0d(d), TAG=%0x(x), WORD=%0x(x) DATA=%0x(x) BE=%0x(x) SIZE=%0x(x) NEED_RSP=%0x(x) PHYS_IDX=%0x(x) UNCACHEABLE=%0x(x) WRITE POLICY=%s", 
                                           R.op, 
                                           R.sid, 
                                           R.tid, 
                                           R.addr, 
                                           hpdcache_get_req_addr_set(R.addr), 
                                           hpdcache_get_req_addr_tag(R.addr),
                                           hpdcache_get_req_addr_word(R.addr),
                                           R.wdata, 
                                           R.be, 
                                           R.size, 
                                           R.need_rsp,
                                           R.phys_indexed,
                                           R.pma.uncacheable,
                                           R.pma.wr_policy_hint), UVM_LOW);
    
  endfunction 

  // print hpdcache rsp
  function void print_hpdcache_ext_rsp_t(hpdcache_ext_rsp_t R, string S);
     `uvm_info(S, $sformatf("RSP SID=%0x(x), TID=%0x(x), ADDR=%0x(x) SET=%0d(d), TAG=%0x(x), DATA=%0x(x) ERROR=%0x(x)", 
        R.sid,
        R.tid,
        R.addr, 
        hpdcache_get_req_addr_set(R.addr), 
        hpdcache_get_req_addr_tag(R.addr),
        R.rdata,
        R.error), UVM_LOW);

  endfunction 

  // print hpdcache rsp
  function void print_hpdcache_rsp_t(hpdcache_rsp_t R, string S);
     `uvm_info(S, $sformatf("RSP SID=%0x(x), TID=%0x(x), DATA=%0x(x) ERROR=%0x(x)", 
        R.sid,
        R.tid,
        R.rdata,
        R.error), UVM_LOW);

  endfunction 

 
  function void print_hpdcache_mem_resp_r_t(hpdcache_mem_ext_resp_r_t R, string S);

 
        `uvm_info(S, $sformatf("ID=%0x(x), SET=%0d(d), TAG=%0x(x), WORD=%0x(x)  ERROR=%0x(x), LAST=%0x(x) DATA=%0x(x)", 
                                             R.mem_rsp.mem_resp_r_id, 
                                             hpdcache_get_req_addr_set(R.mem_req_addr), 
                                             hpdcache_get_req_addr_tag(R.mem_req_addr),
                                             hpdcache_get_req_addr_word(R.mem_req_addr),
                                             R.mem_rsp.mem_resp_r_error, 
                                             R.mem_rsp.mem_resp_r_last, 
                                             R.mem_rsp.mem_resp_r_data), UVM_LOW)
  endfunction 

  function void print_hpdcache_mem_resp_w_t(hpdcache_mem_ext_resp_w_t R, string S);

 
        `uvm_info(S, $sformatf("ID=%0x(x), SET=%0d(d), TAG=%0x(x), WORD=%0x(x)  ERROR=%0x(x), ATOMIC=%0x(x)", 
                                             R.mem_rsp.mem_resp_w_id, 
                                             hpdcache_get_req_addr_set(R.mem_req_addr), 
                                             hpdcache_get_req_addr_tag(R.mem_req_addr),
                                             hpdcache_get_req_addr_word(R.mem_req_addr),
                                             R.mem_rsp.mem_resp_w_error, 
                                             R.mem_rsp.mem_resp_w_is_atomic), UVM_LOW)
  endfunction 

  function void print_hpdcache_mem_req_t(hpdcache_mem_req_t R, string S);
  
        `uvm_info(S, $sformatf("ID=%0x(x), ADDR=%0x(x) SET=%0d(d), TAG=%0x(x), WORD=%0x(x) SIZE=%0d(d) LEN=%0d(d), CMD=%0s ATOMIC=%0s CACHEABLE=%0x(x)", 
                                             R.mem_req_id, 
                                             R.mem_req_addr, 
                                             hpdcache_get_req_addr_set(R.mem_req_addr), 
                                             hpdcache_get_req_addr_tag(R.mem_req_addr), 
                                             hpdcache_get_req_addr_word(R.mem_req_addr),
                                             R.mem_req_size, 
                                             R.mem_req_len, 
                                             R.mem_req_command, 
                                             R.mem_req_atomic, 
                                             R.mem_req_cacheable), UVM_LOW)
  endfunction

  function void print_hpdcache_mem_ext_req_t(hpdcache_mem_ext_req_t R, string S);
  
        `uvm_info(S, $sformatf("ID=%0x(x), ADDR=%0x(x) SET=%0d(d), TAG=%0x(x), WORD=%0x(x)  Data=%0x(x) BE=%0x(x) SIZE=%0d(d) LEN=%0d(d), CMD=%0s ATOMIC=%0s CACHEABLE=%0x(x)", 
                                             R.mem_req.mem_req_id, 
                                             R.mem_req.mem_req_addr, 
                                             hpdcache_get_req_addr_set(R.mem_req.mem_req_addr), 
                                             hpdcache_get_req_addr_tag(R.mem_req.mem_req_addr), 
                                             hpdcache_get_req_addr_word(R.mem_req.mem_req_addr),
                                             R.mem_data,
                                             R.mem_be,
                                             R.mem_req.mem_req_size, 
                                             R.mem_req.mem_req_len, 
                                             R.mem_req.mem_req_command, 
                                             R.mem_req.mem_req_atomic, 
                                             R.mem_req.mem_req_cacheable), UVM_LOW)
  endfunction

  
    typedef enum logic [1:0] {
        SET_MAY_BE_IN_HPDCACHE      = 2'b00, // in case of eviction
        SET_IN_HPDCACHE             = 2'b01,
        SET_NOT_IN_HPDCACHE         = 2'b10,
        SET_INVALID               = 2'b11
      } set_status_e;

    typedef logic unsigned [HPDCACHE_REQ_DATA_WIDTH-1:0]   core_req_data_t;
    typedef logic unsigned [HPDCACHE_REQ_DATA_WIDTH/8-1:0] core_req_be_t;


    typedef struct packed {
        int                cnt;
        logic              is_atomic;
        hpdcache_mem_id_t  id;
        hpdcache_mem_error_e error;
    } hpdcache_mem_write_ext_rsp_t;

    localparam int unsigned HPDCACHE_MISS_READ_BASE_ID = 0; 
    localparam int unsigned HPDCACHE_UC_READ_BASE_ID   = 128; 

    localparam int unsigned HPDCACHE_WBUF_WRITE_BASE_ID = 0; 
    localparam int unsigned HPDCACHE_UC_WRITE_BASE_ID   = 128; 

    localparam int unsigned NUM_CACHEABILITY_TABLE = 4 ;
    localparam int unsigned NUM_HW_PREFETCH        = 4 ;
    localparam int unsigned NUM_SNOOP_PORTS        = 4 ;
    localparam int unsigned CACHE_LINE_BYTES       = 64 ;
    // To configure the memory partition VIP 
    localparam int unsigned NUM_MEM_REGION         = NREQUESTERS + 8; 

    typedef struct packed {
        logic [63:0] hw_prefetch_base;
        logic [63:0] hw_prefetch_param;
        logic [31:0] hw_prefetch_throttle;
        logic [63:0] hw_prefetch_snoop;
    } hwpf_stride_cfg_t;


  localparam  hpdcache_user_cfg_t m_hpdcache_user_cfg = '{
      nRequesters              : NREQUESTERS,
      paWidth                  : HPDCACHE_PA_WIDTH,
      wordWidth                : HPDCACHE_WORD_WIDTH,
      sets                     : HPDCACHE_SETS, 
      ways                     : HPDCACHE_WAYS,
      clWords                  : HPDCACHE_CL_WORDS,
      reqWords                 : HPDCACHE_REQ_WORDS,
      reqTransIdWidth          : HPDCACHE_REQ_TRANS_ID_WIDTH,
      reqSrcIdWidth            : HPDCACHE_REQ_SRC_ID_WIDTH,
      victimSel                : hpdcache_params_pkg::PARAM_VICTIM_SEL,
      dataWaysPerRamWord       : HPDCACHE_DATA_WAYS_PER_RAM_WORD,
      dataSetsPerRam           : HPDCACHE_DATA_SETS_PER_RAM,
      dataRamByteEnable        : HPDCACHE_DATA_RAM_WBYTEENABLE,
      accessWords              : HPDCACHE_ACCESS_WORDS,
      mshrSets                 : HPDCACHE_MSHR_SETS,
      mshrWays                 : HPDCACHE_MSHR_WAYS,
      mshrWaysPerRamWord       : HPDCACHE_MSHR_WAYS_PER_RAM_WORD,
      mshrSetsPerRam           : HPDCACHE_MSHR_SETS_PER_RAM,
      mshrRamByteEnable        : HPDCACHE_MSHR_RAM_WBYTEENABLE,
      mshrUseRegbank           : HPDCACHE_MSHR_USE_REGBANK,
      refillCoreRspFeedthrough : HPDCACHE_REFILL_CORE_RSP_FEEDTHROUGH,
      refillFifoDepth          : HPDCACHE_REFILL_FIFO_DEPTH,
      wbufDirEntries           : HPDCACHE_WBUF_DIR_ENTRIES,
      wbufDataEntries          : HPDCACHE_WBUF_DATA_ENTRIES,
      wbufWords                : HPDCACHE_WBUF_WORDS,
      wbufTimecntWidth         : HPDCACHE_WBUF_TIMECNT_WIDTH,
      rtabEntries              : HPDCACHE_RTAB_ENTRIES,
      flushEntries             : 8,
      flushFifoDepth           : 4,
      memAddrWidth             : HPDCACHE_PA_WIDTH,
      memIdWidth               : HPDCACHE_MEM_ID_WIDTH,
      memDataWidth             : HPDCACHE_MEM_DATA_WIDTH,
      wtEn                     : 1, 
      wbEn                     : 1 
    };

  localparam  hpdcache_cfg_t m_hpdcache_cfg = hpdcacheBuildConfig(m_hpdcache_user_cfg);
  
//  localparam  hpdcache_cfg_t m_hpdcache_cfg = '{
//
//        u                : m_hpdcache_user_cfg,
//
//        clWidth          : m_hpdcache_user_cfg.clWords * m_hpdcache_user_cfg.wordWidth,
//        clOffsetWidth    : $clog2(clWidth / 8),
//        clWordIdxWidth   : $clog2(m_hpdcache_user_cfg.clWords),
//        wordByteIdxWidth : $clog2(m_hpdcache_user_cfg.wordWidth / 8),
//        setWidth         : $clog2(m_hpdcache_user_cfg.sets),
//        nlineWidth       : m_hpdcache_user_cfg.paWidth - clOffsetWidth,
//        tagWidth         : nlineWidth - setWidth,
//        reqWordIdxWidth  : $clog2(m_hpdcache_user_cfg.reqWords),
//        reqOffsetWidth   : m_hpdcache_user_cfg.paWidth - tagWidth,
//        reqDataWidth     : m_hpdcache_user_cfg.reqWords * m_hpdcache_user_cfg.wordWidth,
//        reqDataBytes     : reqDataWidth/8,
//
//        mshrSetWidth     : (m_hpdcache_user_cfg.mshrSets > 1) ? $clog2(m_hpdcache_user_cfg.mshrSets) : 1,
//        mshrWayWidth     : (m_hpdcache_user_cfg.mshrWays > 1) ? $clog2(m_hpdcache_user_cfg.mshrWays) : 1,
//
//        wbufDataWidth    : reqDataWidth*m_hpdcache_user_cfg.wbufWords,
//        wbufDirPtrWidth  : $clog2(m_hpdcache_user_cfg.wbufDirEntries),
//        wbufDataPtrWidth : $clog2(m_hpdcache_user_cfg.wbufDataEntries),
//
//        accessWidth = m_hpdcache_user_cfg.accessWords * m_hpdcache_user_cfg.wordWidth
//    };
endpackage : hpdcache_common_pkg
