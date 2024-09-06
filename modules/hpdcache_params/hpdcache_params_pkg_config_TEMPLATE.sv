/*
 *  Copyright 2024 CEA*
 *  *Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 *  Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 *  may not use this file except in compliance with the License, or, at your
 *  option, the Apache License version 2.0. You may obtain a copy of the
 *  License at
 *
 *  https://solderpad.org/licenses/SHL-2.1/
 *
 *  Unless required by applicable law or agreed to in writing, any work
 *  distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 *  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 *  License for the specific language governing permissions and limitations
 *  under the License.
 */
package hpdcache_params_pkg;
    //  Definition of global constants for the HPDcache data and directory
    //  {{{
    localparam int unsigned PARAM_PA_WIDTH = $PARAM_PA_WIDTH;

    //  HPDcache number of sets
    localparam int unsigned PARAM_SETS = $PARAM_SETS;

    //  HPDcache number of ways
    localparam int unsigned PARAM_WAYS = $PARAM_WAYS;

    //  HPDcache word width (bits)
    localparam int unsigned PARAM_WORD_WIDTH = $PARAM_WORD_WIDTH;

    //  HPDcache cache-line width (bits)
    localparam int unsigned PARAM_CL_WORDS = $PARAM_CL_WORDS;

    //  HPDcache number of words in the request data channels (request and response)
    localparam int unsigned PARAM_REQ_WORDS = $PARAM_REQ_WORDS;

    //  HPDcache request transaction ID width (bits)
    localparam int unsigned PARAM_REQ_TRANS_ID_WIDTH = $PARAM_REQ_TRANS_ID_WIDTH;

    //  HPDcache request source ID width (bits)
    localparam int unsigned PARAM_REQ_SRC_ID_WIDTH = $PARAM_REQ_SRC_ID_WIDTH;

    //  HPDcache victim selection policy
    localparam int unsigned PARAM_VICTIM_SEL = $PARAM_VICTIM_SEL;
    //  }}}

    //  Definition of constants and types for HPDcache data memory
    //  {{{
    localparam int unsigned PARAM_DATA_WAYS_PER_RAM_WORD = $PARAM_DATA_WAYS_PER_RAM_WORD;

    localparam int unsigned PARAM_DATA_SETS_PER_RAM = $PARAM_DATA_SETS_PER_RAM;

    //  HPDcache DATA RAM macros implement write byte enable
    //  -  Write byte enable (1'b1)
    //  -  Write bit mask (1'b0)
    localparam bit PARAM_DATA_RAM_WBYTEENABLE = 0;

    //  Define the number of memory contiguous words that can be accessed
    //  simultaneously from the cache.
    //  -  This limits the maximum width for the data channel from requesters
    //  -  This impacts the refill latency (more ACCESS_WORDS -> less REFILL LATENCY)
    localparam int unsigned PARAM_ACCESS_WORDS = $PARAM_ACCESS_WORDS;
    //  }}}

    //  Definition of constants and types for the Miss Status Holding Register (MSHR)
    //  {{{
    //  HPDcache MSHR number of sets
    localparam int unsigned PARAM_MSHR_SETS = $PARAM_MSHR_SETS;

    //  HPDcache MSHR number of ways
    localparam int unsigned PARAM_MSHR_WAYS = $PARAM_MSHR_WAYS;

    //  HPDcache MSHR number of ways in the same SRAM word
    localparam int unsigned PARAM_MSHR_WAYS_PER_RAM_WORD = $PARAM_MSHR_WAYS_PER_RAM_WORD;

    //  HPDcache MSHR number of sets in the same SRAM
    localparam int unsigned PARAM_MSHR_SETS_PER_RAM = $PARAM_MSHR_SETS_PER_RAM;

    //  HPDcache MSHR macros implement write byte enable
    //  -  Write byte enable (1'b1)
    //  -  Write bit mask (1'b0)
    localparam bit PARAM_MSHR_RAM_WBYTEENABLE = 0;

    //  HPDcache MSHR whether uses FFs or SRAM
    localparam bit PARAM_MSHR_USE_REGBANK = 0;

    //  HPDcache feedthrough FIFOs from the refill handler to the core
    localparam bit PARAM_REFILL_CORE_RSP_FEEDTHROUGH = 1;
    //  }}}

       //  HPDcache depth of the refill FIFO
    localparam int PARAM_REFILL_FIFO_DEPTH = 2;

    //  Definition of constants and types for the Write Buffer (WBUF)
    //  {{{
    //  HPDcache Write-Buffer number of entries in the directory
    localparam int unsigned PARAM_WBUF_DIR_ENTRIES = $PARAM_WBUF_DIR_ENTRIES;

    //  HPDcache Write-Buffer number of entries in the data buffer
    localparam int unsigned PARAM_WBUF_DATA_ENTRIES = $PARAM_WBUF_DATA_ENTRIES;

    //  HPDcache Write-Buffer number of words per entry
    localparam int unsigned PARAM_WBUF_WORDS = $PARAM_WBUF_WORDS;

    //  HPDcache Write-Buffer threshold counter width (in bits)
    localparam int unsigned PARAM_WBUF_TIMECNT_WIDTH = $PARAM_WBUF_TIMECNT_WIDTH;

    //  HPDCACHE feedthrough FIFOs from the write-buffer to the NoC
    localparam bit PARAM_WBUF_SEND_FEEDTHROUGH = 0;
    //  }}}

    //  Definition of constants and types for the Replay Table (RTAB)
    //  {{{
    localparam int PARAM_RTAB_ENTRIES = $PARAM_RTAB_ENTRIES;
    //  }}}
    
    // Orginaly define in hpdcache_common_pkg.sv file. Added her to be able generated these parameters with the param_sweeper tools
    localparam int unsigned HPDCACHE_MEM_ID_WIDTH   = $HPDCACHE_MEM_ID_WIDTH;
    localparam int unsigned HPDCACHE_MEM_DATA_WIDTH = $HPDCACHE_MEM_DATA_WIDTH; 

    
endpackage
