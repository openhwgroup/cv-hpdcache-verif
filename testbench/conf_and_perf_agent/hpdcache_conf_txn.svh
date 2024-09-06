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
//  Description : DCache configuration transaction used in the driver to drive the requests
// ----------------------------------------------------------------------------

// -----------------------------------------------------------------------
// Class hpdcache_conf_txn
//
// Contains fields that are sent to the scoreboard for further analysis
// -----------------------------------------------------------------------
class hpdcache_conf_txn extends uvm_object;
   `uvm_object_utils( hpdcache_conf_txn)

    //          Request Interface
    rand logic                          m_cfg_enable;
    rand wbuf_timecnt_t                 m_cfg_wbuf_threshold;
    rand logic                          m_cfg_wbuf_reset_timecnt_on_write;
    rand logic                          m_cfg_wbuf_sequential_waw;
    rand logic                          m_cfg_wbuf_inhibit_write_coalescing;
    rand logic                          m_cfg_hwpf_stride_updt_plru;
    rand hpdcache_req_sid_t             m_cfg_hwpf_stride_sid;
    rand logic                          m_cfg_error_on_cacheable_amo;
    rand logic                          m_cfg_rtab_single_entry;
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_conf_txn");
        super.new(name);
        this.hpdcache_configuration_coverage = new();
    endfunction

    // ------------------------------------------------------------------------
    // convert2string
    // ------------------------------------------------------------------------
    virtual function string convert2string;
        string s;
        s = super.convert2string();
        return s;
    endfunction: convert2string
       
    // constraint m_cfg_wbuf_threshold_c              {m_cfg_wbuf_threshold == 0;};
    // constraint m_cfg_wbuf_reset_timecnt_on_write_c {m_cfg_wbuf_reset_timecnt_on_write == 0;};
    // constraint m_cfg_wbuf_sequential_waw_c         {m_cfg_wbuf_sequential_waw == 0;};
    // constraint m_cfg_hwpf_stride_updt_plru_c          {m_cfg_hwpf_stride_updt_plru == 0;};
    // constraint m_cfg_hwpf_stride_sid_c                {m_cfg_hwpf_stride_sid == 0;};
     constraint m_cfg_error_on_cacheable_amo_c      {m_cfg_error_on_cacheable_amo == 0;};
    // constraint m_cfg_rtab_single_entry_c           {m_cfg_rtab_single_entry == 0;};
  
 //   constraint cfg_wbuf_inhibit_write_coalescing_c {m_cfg_wbuf_inhibit_write_coalescing == 1;};
   constraint m_cfg_enable_c    {m_cfg_enable == 1;};
   covergroup hpdcache_configuration_coverage;  

     cfg_wbuf_threshold                 : coverpoint  m_cfg_wbuf_threshold;
     cfg_wbuf_reset_timecnt_on_write    : coverpoint  m_cfg_wbuf_reset_timecnt_on_write;
     cfg_wbuf_sequential_waw            : coverpoint  m_cfg_wbuf_sequential_waw;
     cfg_hwpf_stride_updt_plru             : coverpoint  m_cfg_hwpf_stride_updt_plru;
     cfg_hwpf_stride_sid                   : coverpoint  m_cfg_hwpf_stride_sid;
     cfg_error_on_cacheable_amo         : coverpoint  m_cfg_error_on_cacheable_amo;
     cfg_rtab_single_entry              : coverpoint  m_cfg_rtab_single_entry;

   endgroup

   
  // API to get the minumum of the numbers 
  function int unsigned get_min(int unsigned a, int unsigned b);
    int unsigned ret;

    ret = a;
    if (a > b) ret = b; 

    return ret; 
  endfunction
endclass: hpdcache_conf_txn


// -----------------------------------------------------------------------
class hpdcache_conf_zero_threshold_no_reset_timecnt extends hpdcache_conf_txn;
   `uvm_object_utils( hpdcache_conf_zero_threshold_no_reset_timecnt)

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_conf_zero_threshold_no_reset_timecnt");
        super.new(name);
    endfunction


    constraint wbuf_reset_timecnt_on_write_c {m_cfg_wbuf_reset_timecnt_on_write == 0;};
    constraint cfg_wbuf_threshold_c          {m_cfg_wbuf_threshold == 0;};

endclass: hpdcache_conf_zero_threshold_no_reset_timecnt


// -----------------------------------------------------------------------
class hpdcache_conf_high_threshold_reset_timecnt extends hpdcache_conf_txn;
   `uvm_object_utils( hpdcache_conf_high_threshold_reset_timecnt)

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_conf_high_threshold_reset_timecnt");
        super.new(name);
    endfunction


    constraint wbuf_reset_timecnt_on_write_c {m_cfg_wbuf_reset_timecnt_on_write == 1;};
    constraint cfg_wbuf_threshold_c          {m_cfg_wbuf_threshold == 7;};

endclass: hpdcache_conf_high_threshold_reset_timecnt

class hpdcache_conf_random_threshold_no_reset_timecnt extends hpdcache_conf_txn;
   `uvm_object_utils( hpdcache_conf_random_threshold_no_reset_timecnt)

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_conf_random_threshold_no_reset_timecnt");
        super.new(name);
    endfunction


    constraint wbuf_reset_timecnt_on_write_c {m_cfg_wbuf_reset_timecnt_on_write == 0;};

endclass: hpdcache_conf_random_threshold_no_reset_timecnt

// -----------------------------------------------------------------------
class hpdcache_conf_random_threshold_reset_timecnt extends hpdcache_conf_txn;
   `uvm_object_utils( hpdcache_conf_random_threshold_reset_timecnt)

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_conf_random_threshold_reset_timecnt");
        super.new(name);
    endfunction


    constraint wbuf_reset_timecnt_on_write_c {m_cfg_wbuf_reset_timecnt_on_write == 1;};

endclass: hpdcache_conf_random_threshold_reset_timecnt

class hpdcache_conf_bPLRU extends hpdcache_conf_txn;
   `uvm_object_utils(hpdcache_conf_bPLRU )
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_conf_bPLRU");
        super.new(name);
    endfunction


    constraint cfg_hwpf_stride_updt_plru_c {m_cfg_hwpf_stride_updt_plru == 1;};
endclass
// -----------------------------------------------------------------------
// Class hpdcache_conf_performance_txn
//
// Contains fields that are sent to the scoreboard for further analysis
// -----------------------------------------------------------------------
class hpdcache_conf_performance_txn extends hpdcache_conf_txn;
   `uvm_object_utils( hpdcache_conf_performance_txn)

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_conf_performance_txn");
        super.new(name);
    endfunction

    // ------------------------------------------------------------------------
    // convert2string
    // ------------------------------------------------------------------------
    virtual function string convert2string;
        string s;
        s = super.convert2string();
        return s;
    endfunction: convert2string
       
    constraint m_cfg_wbuf_threshold_min_c          {m_cfg_wbuf_threshold >= 1;};
    constraint m_cfg_wbuf_threshold_max_c          {m_cfg_wbuf_threshold < get_min(HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);};
    constraint m_cfg_wbuf_reset_timecnt_on_write_c {m_cfg_wbuf_reset_timecnt_on_write == 1;};
    constraint m_cfg_wbuf_sequential_waw_c         {m_cfg_wbuf_sequential_waw == 0;};
    constraint m_cfg_rtab_single_entry_c           {m_cfg_rtab_single_entry == 0;};
    constraint cfg_wbuf_inhibit_write_coalescing_c {m_cfg_wbuf_inhibit_write_coalescing == 0;};
    constraint m_cfg_enable_c                      {m_cfg_enable == 1;};
endclass: hpdcache_conf_performance_txn


