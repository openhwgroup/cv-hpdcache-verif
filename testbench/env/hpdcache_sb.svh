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
//  Description : Scoreboard
// ----------------------------------------------------------------------------


// --------------------------------
// Shadow Memory 
// --------------------------------

class hpdcache_req_with_ts extends uvm_object;
  `uvm_object_utils(hpdcache_req_with_ts);


  hpdcache_req_data_t    m_data;
  hpdcache_word_t        m_word;  
  hpdcache_req_be_t      m_be;
  hpdcache_req_be_t      m_be_in_waiting;
  int                    m_cnt;
  hpdcache_set_t         m_set;
  hpdcache_tag_t         m_tag;
  bit [1:0]              is_closed;
  time                   timestamp; 
  // ------------------------------------------------------------------------
  // Constructor
  // ------------------------------------------------------------------------
  function new( string name = "cc cache" );
    super.new(name);
    m_data = 0;
    m_word = 0;  
    m_be   = 0;
    m_cnt  = 0;
    m_set  = 0;
    m_tag  = 0;
    is_closed = 0;
    timestamp = 0; 
  endfunction: new

endclass


class hpdcache_c extends uvm_object;
  `uvm_object_utils(hpdcache_c);

  // Data is stored in a set
  hpdcache_mem_data_t    data;
  hpdcache_tag_t         tag;

  // Error per byte is stored 
  hpdcache_mem_be_t      error; 

  // status, hit/miss/may be 
  set_status_e      status;

  // Dcache configuration

  // ------------------------------------------------------------------------
  // Constructor
  // ------------------------------------------------------------------------
  function new( string name = "cc cache" );
    super.new(name);
  endfunction: new

endclass

// -------------------------
// SCOREBOARD 
// -------------------------
class hpdcache_sb#(int NREQUESTERS = 1)  extends uvm_scoreboard;

  `uvm_component_param_utils(hpdcache_sb#(NREQUESTERS) )

  //localparam NUM_MEM_WBUF_WORDS   = HPDCACHE_MEM_DATA_WIDTH/HPDCACHE_WBUF_DATA_WIDTH;
  // localparam MEM_REQ_RATIO        = HPDCACHE_REQ_WORDS;
  // -----------------------------------------------------------------------
  // Analysis Ports
  // -----------------------------------------------------------------------
  // Receives the request sent to the DUV
  uvm_tlm_analysis_fifo #(hpdcache_mem_req_t)      af_mem_req;
  uvm_tlm_analysis_fifo #(hpdcache_mem_ext_req_t)  af_mem_ext_req;

  // Receives the response sent by the DUV
  uvm_tlm_analysis_fifo #(hpdcache_mem_resp_r_t)   af_mem_read_rsp;
  uvm_tlm_analysis_fifo #(hpdcache_mem_resp_w_t)   af_mem_write_rsp;

  // Receives the load request sent by the DUV
  uvm_tlm_analysis_fifo #(hpdcache_req_mon_t)      af_hpdcache_req[NREQUESTERS];
  // Receives the load response sent to the DUV
  uvm_tlm_analysis_fifo #(hpdcache_rsp_t)     af_hpdcache_rsp[NREQUESTERS];

  // -----------------------------------------------------------------------
  // Performance Monitor
  // -----------------------------------------------------------------------
  perf_monitor_c  m_perf_monitor;
 
  // -----------------------------------------------------------------------
  // Dcache Conf
  // -----------------------------------------------------------------------
  hpdcache_conf_txn                    m_hpdcache_conf;
  // -----------------------------------------------------------------------
  // Shadow Dcache: NOT USED
  // Queue represents the number of ways
  // (since we cannot predict exactly the eviction, we may have to store more data)
  // bit PLRU table 
  // -----------------------------------------------------------------------
  hpdcache_c                           m_hpdcache[HPDCACHE_SETS][$];
  hpdcache_c                           m_tag_dir[HPDCACHE_SETS][HPDCACHE_WAYS];
  bit [HPDCACHE_WAYS -1: 0]            m_bPLRU_table[HPDCACHE_SETS];
  // -----------------------------------------------------
  // Shadow of memory rsp model
  // A copy of memory is maintained in the env 
  // to be able to simplify the memory coherency issues 
  // -----------------------------------------------------
  memory_c#(HPDCACHE_MEM_DATA_WIDTH*HPDCACHE_MEM_LOAD_NUM)     m_memory[bit [HPDCACHE_PA_WIDTH -1: 0]];
  // -----------------------------------------------------------------------
  // Dcache/memory  Request queue  
  // -----------------------------------------------------------------------
  hpdcache_req_mon_t                       m_hpdcache_req_with_rsp[NREQUESTERS][hpdcache_req_tid_t][$];
  hpdcache_req_mon_t                       m_hpdcache_req_uncached[$];
  hpdcache_req_mon_t                       m_hpdcache_req[$];
  hpdcache_mem_req_t                       m_read_req[hpdcache_mem_id_t];
  hpdcache_mem_ext_req_t                   m_write_req[hpdcache_mem_id_t];

  // --------------------------------------------------------------------------------
  // On read data is read from the memory shadow and stored in this variable
  // --------------------------------------------------------------------------------
  bit[HPDCACHE_MEM_DATA_WIDTH*HPDCACHE_MEM_LOAD_NUM -1 :0]  m_load_data[hpdcache_set_t][hpdcache_tag_t][$];
  bit[HPDCACHE_MEM_DATA_WIDTH*HPDCACHE_MEM_LOAD_NUM -1 :0]  m_single_load_data;

  // -----------------------------------------------------------------------
  // Associative array to store reservation bit of LR/SC 
  // The associative has add as key and it stores the byte which has reserved
  // -----------------------------------------------------------------------
  hpdcache_mem_be_t                               mem_be_res;
  hpdcache_mem_be_t                               m_load_reservation[hpdcache_req_addr_t]; 

  // -----------------------------------------------------------------------
  // Pass a handle of memory response model to the sb 
  // -----------------------------------------------------------------------
  memory_response_model #(HPDCACHE_PA_WIDTH, 
                          HPDCACHE_MEM_DATA_WIDTH, 
                          HPDCACHE_MEM_ID_WIDTH) m_mem_rsp_model;



  // ----------------------------------------------
  // This classe configures the top of HPDCACHE
  // Par ex: requeters, etc
  // ----------------------------------------------
  hpdcache_top_cfg               m_top_cfg;

  // ----------------------------------------------------------------------
  // Keeps the cnt of store request before a memory write request is made 
  // Cache may merge multiple store request to make one memory write request 
  // ----------------------------------------------------------------------
  int                     m_hpdcache_store_cnt[hpdcache_set_t][hpdcache_tag_t]; 
  // ---------------------------------------------------------------------
  // Keeps the cnt of write requests on the memory interface 
  // ---------------------------------------------------------------------
  int                     m_mem_write_cnt;

  // Following variables are used to predict PLRU in the case of AMO 
  bit                     m_rd_amo_rsp_rcv;
  bit                     m_wr_amo_rsp_rcv;
  // ---------------------------------------------------------------------
  // These variables predict the error rsp of a hpdcache request
  // ---------------------------------------------------------------------
  bit                     m_error[hpdcache_set_t][hpdcache_tag_t]; 
  bit                     m_error_amo[hpdcache_set_t][hpdcache_tag_t]; 
  bit                     m_sc_status[hpdcache_set_t][hpdcache_tag_t]; 
  // -----------------------------------------------------------------------
  // Counters for the number of requests/responses analyzed by the scoreboard
  // -----------------------------------------------------------------------
  int m_hpdcache_req_counter;
  int m_hpdcache_rsp_counter;

  int m_mem_req_counter;
  int m_read_rsp_counter;
  int m_write_rsp_counter;

  int m_first_trans_cycle;
  int m_last_trans_cycle;
  int m_global_cycle_count;

  event reset_asserted;
  event reset_deasserted;
  event e_new_hpdcache_req[NREQUESTERS]; 
  event e_cmo_check_done[NREQUESTERS];

  // ------------------------
  // Performance counter 
  // ------------------------
  int   cnt_cache_write_miss;
  int   cnt_cache_read_miss;
  int   cnt_uncached_req;
  int   cnt_cmo_req;
  int   cnt_pref_req;
  int   cnt_pref_err_req;
  int   cnt_write_req;
  int   cnt_read_req;
  int   cnt_granted_req;
  int   cnt_req_on_hold;

  virtual xrtl_clock_vif      vif;
  hpdcache_req_mon_t          new_req;


  //---------------------------------------------------------------------------
  // Coverage items
  //---------------------------------------------------------------------------
  hpdcache_mem_command_e   cov_prev_mem_cmd, cov_new_mem_cmd;
  hpdcache_req_mon_t       cov_prev_hpdcache_req, cov_new_hpdcache_req;
  hpdcache_req_op_t        cov_prev_hpdcache_op, cov_new_hpdcache_op;
  hpdcache_mem_size_t      cov_rd_miss_size, cov_rd_uc_size;
  hpdcache_mem_size_t      cov_wr_wbuf_size, cov_wr_uc_size;
  hpdcache_mem_size_t      cov_atomic_size;
  hpdcache_mem_atomic_e    cov_atomic_cmd; 
  hpdcache_mem_command_e   cov_mem_cmd; 
  hpdcache_mem_id_t        cov_mem_id; 
  bit                      cov_mem_cacheable;
  bit                      cov_prev_hpdcache_op_need_rsp, cov_new_hpdcache_op_need_rsp;
  bit                      cov_prev_op_error;
  int                      cov_wr_merge_cnt;
  hpdcache_set_t           prev_mem_set, prev_hpdcache_set;
  hpdcache_tag_t           prev_mem_tag, prev_hpdcache_tag;
  hpdcache_word_t          cov_sc_pass_word;  
  bit                      cov_cfg_error_on_cacheable_amo;

  bit                      cov_rsp_error_check;
  bit                      cov_rsp_amo_error_check;
  bit                      cov_rsp_load_data_check;
  bit                      cov_rsp_amo_data_check;
  bit                      cov_rsp_sc_data_fail_check;
  bit                      cov_rsp_sc_data_pass_check;

  bit                      cov_tag_dir_hit_check;
  bit                      cov_tag_dir_miss_check;
  bit                      cov_bplru_algo_check;

  bit                      cov_mem_access_read_check;
  bit                      cov_mem_access_lr_check;
  bit                      cov_mem_access_write_uncacheable_check;
  bit                      cov_mem_access_amo_check;
  bit                      cov_mem_addr_check;
  bit                      cov_mem_byte_enable_write_uncacheable_check;
  bit                      cov_mem_data_write_uncacheable_check;
  bit                      cov_mem_byte_enable_amo_check;
  bit                      cov_mem_data_amo_check;
  bit                      cov_mem_cacheable_check; // not done yet 

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);

    this.b2b_mem_cmd_coverage                = new();
    this.b2b_hpdcache_req_op_coverage          = new();
    this.cfg_error_on_cacheable_amo_coverage = new();
    this.sc_pass_word_coverage               = new();
    this.wr_wbuf_size_coverage               = new();
    this.rd_miss_size_coverage               = new();
    this.mem_command_coverage                = new();
    this.mem_id_coverage                     = new();
    this.wr_merge_cnt_coverage               = new();
    this.mem_atomic_coverage                 = new();
  endfunction: new

  // -------------------------------------------------------------------------
  // Build phase
  // -------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    af_mem_req       = new("af_mem_req");
    af_mem_ext_req   = new("af_mem_ext_req");
    af_mem_read_rsp  = new("af_mem_read_rsp");
    af_mem_write_rsp = new("af_mem_write_rsp");
 
    for ( int r = 0 ; r < NREQUESTERS ; r++ ) begin
      af_hpdcache_req[r]   = new($sformatf("af_hpdcache_req_%0d", r));
      af_hpdcache_rsp[r]   = new($sformatf("af_hpdcache_rsp_%0d", r));
    end
    m_perf_monitor = perf_monitor_c::type_id::create("m_perf_monitor", this );

    `uvm_info("SCOREBOARD", "Build stage complete.", UVM_LOW)
  endfunction: build_phase

  // ------------------------------------------------------------------------
  // Pre reset phase
  // ------------------------------------------------------------------------
  virtual task pre_reset_phase(uvm_phase phase);
    -> reset_asserted;
    `uvm_info("SCOREBOARD", "Pre Reset stage complete.", UVM_LOW)
  endtask : pre_reset_phase

  // ------------------------------------------------------------------------
  // Reset phase
  // ------------------------------------------------------------------------
  task reset_phase(uvm_phase phase );
    super.reset_phase(phase);

    m_hpdcache_req_counter  = 0;
    m_hpdcache_rsp_counter  = 0;
    m_first_trans_cycle     = 0; 

    m_mem_req_counter   = 0;
    m_read_rsp_counter  = 0;
    m_write_rsp_counter = 0;
    m_mem_write_cnt     = 0;

    cnt_cache_write_miss = 0; 
    cnt_cache_read_miss  = 0;  
    cnt_uncached_req     = 0;     
    cnt_cmo_req          = 0;          
    cnt_pref_req          = 0;          
    cnt_pref_err_req          = 0;          
    cnt_write_req        = 0;        
    cnt_read_req         = 0;         
    cnt_granted_req      = 0;     
    cnt_req_on_hold      = 0;      
    m_rd_amo_rsp_rcv     = 0;
    m_wr_amo_rsp_rcv     = 0;

    m_memory.delete();

    af_mem_req.flush();
    af_mem_ext_req.flush();
    af_mem_read_rsp.flush();

    m_hpdcache_req.delete();
    m_hpdcache_req_uncached.delete();
    m_read_req.delete();
    m_write_req.delete();
    m_load_reservation.delete(); 

    for ( int r = 0 ; r < NREQUESTERS ; r++ ) begin
      af_hpdcache_req[r].flush();
      af_hpdcache_rsp[r].flush();

      m_hpdcache_req_with_rsp[r].delete();
     
    end


    for ( int s = 0 ; s < HPDCACHE_SETS ; s++ ) begin
      m_hpdcache[s].delete();
      m_load_data[s].delete();
      m_error[s].delete(); 
      m_error_amo[s].delete(); 
      m_sc_status[s].delete(); 
      m_hpdcache_store_cnt[s].delete();
      m_bPLRU_table[s] = 0;

      for ( int w = 0 ; w < HPDCACHE_WAYS ; w++ ) begin 
        m_tag_dir[s][w] = hpdcache_c::type_id::create($sformatf("hpdcache_node_%0d_%0d", s, w), this); 
        m_tag_dir[s][w].status = SET_NOT_IN_HPDCACHE; 
      end
    end
    m_load_data.delete();
    m_error.delete(); 
    m_error_amo.delete(); 
    m_sc_status.delete(); 
    m_hpdcache_store_cnt.delete();


    m_perf_monitor.reset_open_transactions( );

    `uvm_info("SCOREBOARD", "Reset stage complete.", UVM_LOW)
  endtask: reset_phase

  // ------------------------------------------------------------------------
  // Post reset phase
  // ------------------------------------------------------------------------
  virtual task post_reset_phase(uvm_phase phase);
    `uvm_info("SCOREBOARD", "Post Reset stage complete.", UVM_LOW)
  endtask : post_reset_phase


  // -------------------------------------------------------------------------
  // Run phase
  // -------------------------------------------------------------------------
  virtual task main_phase(uvm_phase phase);
    super.main_phase(phase);
    fork
      global_cycle_counter();
      get_mem_req();
      get_mem_ext_req();
      get_mem_read_rsp();
      get_mem_write_rsp();
      for ( int r = 0 ; r < NREQUESTERS ; r++ ) begin
        automatic int i = r;
        fork begin
          get_hpdcache_rsp(i);
        end join_none
      end
      for ( int r = 0 ; r < NREQUESTERS ; r++ ) begin
        automatic int i = r;
        fork begin
          get_hpdcache_req(i);
        end join_none
      end
    join_none

    `uvm_info("HPDCACHE SB", "Main Phase Completed", UVM_LOW);
  endtask: main_phase

  // -------------------------------------------------------------------------
  // Run phase
  // -------------------------------------------------------------------------
  // -------------------------------------------------------------------------
  // Dcache request
  // -------------------------------------------------------------------------
  virtual task get_hpdcache_req(int i);
    hpdcache_req_mon_t   req;
    hpdcache_set_t       set;
    hpdcache_tag_t       tag;
    hpdcache_word_t      word;
    int                  wbuf_word;
    hpdcache_req_with_ts node;
    int                req_word;
    int                offset;
    core_req_data_t    req_data;
    core_req_data_t    mem_data;
    hpdcache_req_addr_t  addr;
    bit                carry = 0;
    int                last_one_strb;
    int                tag_dir_index = -1; 
    hpdcache_req_with_ts node2;
    hpdcache_req_with_ts node1;
    int                found_init; 
    int                found_open; 
    int                found_closed; 
    int                index; 

    forever begin

      af_hpdcache_req[i].get(req);
      m_rd_amo_rsp_rcv = 0;
      m_wr_amo_rsp_rcv = 0;
      // ----------------------------------------------------------------
      // To check the hpdcache responses 
      // Once the hpdcache response is observed the request is poped from
      // this list to check the response 
      // -----------------------------------------------------------------

      if(req.phys_indexed == 0 ) begin 
        if(req.second_cycle == 0) begin
          if(req.need_rsp == 1 ) m_hpdcache_req_with_rsp[i][req.tid].push_back(req);
          continue; 
        end
      end else begin
       if(req.need_rsp == 1 ) m_hpdcache_req_with_rsp[i][req.tid].push_back(req);
      end

      new_req = req;
      print_hpdcache_req_t(req, $sformatf("SB HPDCACHE REQ %0d",i) );
      cnt_granted_req++; 
      // ---------------------------------------------------------
      // Get set and tag from the request address
      // Get the aligned address
      // Get the word at memory interface 
      // ---------------------------------------------------------
      set    = hpdcache_get_req_addr_set (req.addr);
      tag    = hpdcache_get_req_addr_tag (req.addr);
      word   = hpdcache_get_req_addr_word(req.addr);
      wbuf_word = word; //REQ_WBUF_RATIO; 
      addr   = req.addr;
      offset = req.addr[HPDCACHE_OFFSET_WIDTH -1 :0];
      addr[HPDCACHE_OFFSET_WIDTH -1 :0] = 0;


      // =================================================== 
      
      // =================================================== 

      // --------------------------------------------------
      // PLRU cache hit miss prediction 
      // Only done in some directed test 
      // to avoid conflit between req and refill response 
      // --------------------------------------------------
      tag_dir_index = -1;
      if(m_top_cfg.m_bPLRU_enable == 1 & req.pma.uncacheable == 0) begin
      
          case ( req.op )
            HPDCACHE_REQ_CMO_FENCE    :  begin  // FENCE
               `uvm_info("SB HPDCACHE CMO FENCE", "CMO fence command is sent", UVM_MEDIUM);
            end
            HPDCACHE_REQ_CMO_INVAL_NLINE, HPDCACHE_REQ_CMO_FLUSH_INVAL_NLINE: begin 
              for ( int w = 0 ; w < HPDCACHE_WAYS ; w++ ) begin 
                if(m_tag_dir[set][w].tag == tag)  begin 
                  m_tag_dir[set][w].status = SET_INVALID;
                  `uvm_info("SB CACHE PLRU INVALID CMO", $sformatf("SET=%0d(d), TAG=%0x(x) Invalidated", set, tag), UVM_HIGH );
                  break;
                end
              end
            end
            HPDCACHE_REQ_CMO_INVAL_ALL, HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL: 
            begin
             for ( int s = 0 ; s < HPDCACHE_SETS ; s++ ) begin 
               for ( int w = 0 ; w < HPDCACHE_WAYS ; w++ ) begin 
                 m_tag_dir[s][w].status = SET_INVALID; 
               end
             end
             `uvm_info("SB CACHE PLRU INVALID ALL CMO", $sformatf("SET=%0d(d), TAG=%0x(x) Invalidated", set, tag), UVM_HIGH );
            end
            HPDCACHE_REQ_CMO_PREFETCH:
            begin
             tag_dir_index   = get_index_from_tag_dir(set, tag);

             // It is a hit
             // just update plru 
             if(tag_dir_index >= 0) begin 
               `uvm_info("SB CACHE HIT PLRU", $sformatf("TAG %0x(x) is a hit", tag), UVM_HIGH );
               cache_hit_update_bPLRU(set, tag_dir_index);
               m_tag_dir[set][tag_dir_index].tag    = tag;
               m_tag_dir[set][tag_dir_index].status = SET_IN_HPDCACHE;
             end
            end
            default: 
            if (!is_cmo(req.op)) begin
              tag_dir_index   = get_index_from_tag_dir(set, tag);

              // It is a hit
              // just update plru 
              if(tag_dir_index >= 0) begin 
                `uvm_info("SB CACHE HIT PLRU", $sformatf("TAG %0x(x) is a hit", tag), UVM_HIGH );
                if(!is_amo(req.op)) begin
                  cache_hit_update_bPLRU(set, tag_dir_index);
                  m_tag_dir[set][tag_dir_index].tag    = tag;
                  m_tag_dir[set][tag_dir_index].status = SET_IN_HPDCACHE;
                end
              end
            end
          endcase
      end

      //-------------------------------------------------------
      // Coverage back to back dcach req at same addr
      // Cover only in the case of 1 requester 
      // 2nd is for hwpf_stride
      //-------------------------------------------------------
      if(m_top_cfg.m_num_requesters == 2) begin 
        cov_new_hpdcache_op          = req.op;
        cov_new_hpdcache_op_need_rsp = req.need_rsp; 

        if(prev_hpdcache_set == set && prev_hpdcache_tag == tag)   begin 

           b2b_hpdcache_req_op_coverage.sample();
           

        end
        cfg_error_on_cacheable_amo_coverage.sample();

        cov_prev_hpdcache_op          = req.op;
        cov_prev_hpdcache_op_need_rsp = req.need_rsp; 
        prev_hpdcache_set             = set;
        prev_hpdcache_tag             = tag;

        if(m_error.exists(set) && m_error[set].exists(tag) && m_error_amo.exists(set) && m_error_amo[set].exists(tag)) begin
          cov_prev_op_error = m_error[set][tag] | m_error_amo[set][tag];
        end else begin
          cov_prev_op_error = 1'b0;
        end

      end
      //-------------------------------------------------------
      word = wbuf_word; // Word at memory 

      m_hpdcache_req.push_back(req);

      //-------------------------------------------------------
      // initialize counter
      //-------------------------------------------------------
      if(! (m_hpdcache_store_cnt.exists(set) && m_hpdcache_store_cnt[set].exists(tag))) m_hpdcache_store_cnt[set][tag] = 0; 

      // Events used to synchronised properly the end of CMOs requests 
    //  ->e_new_hpdcache_req[i];
    //  
    //  @e_cmo_check_done[i];


      // =================================================== 



      // =================================================== 
      // ERROR BIT CHECK: CMOS 
      // --------------------------------------------------
      // Prediction of error for CMOs
      // CMOs request with uncacheable == 1 is an error 
      // --------------------------------------------------
      if(is_cmo (req.op) ==  1) begin
        if(req.pma.uncacheable == 1) m_error[set][tag] = 1'b1; 
        else                     m_error[set][tag] = 1'b0;
      end



      // =================================================== 
      //  AMO SB 
      // =================================================== 
      word = word / HPDCACHE_REQ_WORDS;
      req_word  = word;
     // if(HPDCACHE_MEM_DATA_WIDTH == HPDCACHE_WORD_WIDTH)  req_word = 0;
      // -------------------------------------------------------------
      // store at the same word address changes the lock
      // status 
      // -------------------------------------------------------------
      mem_be_res = 'h0;
      foreach (req.be[i, j]) begin
        if (req.be[i][j] == 1'b1) begin 
          mem_be_res[j + i*HPDCACHE_WORD_WIDTH/8 + (req_word)*HPDCACHE_REQ_DATA_WIDTH/8] = 1'b1;
        end else begin                     
          mem_be_res[j + i*HPDCACHE_WORD_WIDTH/8 +  (req_word)*HPDCACHE_REQ_DATA_WIDTH/8] = 1'b0;
        end
      end

      mem_be_res = 'h0;
      for(int i = offset; i < offset + 2**req.size; i++) begin
        mem_be_res[i] = 1'b1;
      end

      `uvm_info("SB HPDCACHE LR SC check", $sformatf("ADDR=%0x(x) word=%0d(d) offset=%0d(d) size = %0d(d)", mem_be_res, req_word, offset, 2**req.size), UVM_FULL);

      if (req.op == HPDCACHE_REQ_STORE) begin
        if( m_load_reservation.exists(addr)) begin 
          if(check_lr_sc_reservation(addr, mem_be_res)) begin
            m_load_reservation.delete(addr);
            `uvm_info("SB HPDCACHE UNSET LR", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", addr, set, tag, offset), UVM_FULL);
          end else begin
            `uvm_info("SB HPDCACHE NOT UNSET LR", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", addr, set, tag, offset), UVM_FULL);
          end
        end
      end
      `include "hpdcache_amo_sb.svh"
      `include "hpdcache_load_store_pref_sb.svh"

      // ===================================================

      if(m_hpdcache_req_counter == 0) m_first_trans_cycle = m_global_cycle_count; 
      m_hpdcache_req_counter++;
     
      m_last_trans_cycle = m_global_cycle_count;

      `uvm_info("SB CACHE REQ COUNTER", $sformatf("Counter %0d(d) ", m_hpdcache_req_counter), UVM_HIGH );
    end // Forever
  endtask

  // -------------------------------------------------------------------------
  // Collect store response sent by the DUT
  // -------------------------------------------------------------------------
  virtual task get_hpdcache_rsp(int i);
    hpdcache_req_mon_t     req;
    hpdcache_rsp_t     rsp;
    hpdcache_ext_rsp_t  rsp_ext;
    hpdcache_word_t    word;
    hpdcache_set_t     set;
    hpdcache_tag_t     tag;
    int              idx[$];
    core_req_data_t  data;
    core_req_data_t  resp_data;
    core_req_be_t    error;
    hpdcache_req_addr_t addr;
    hpdcache_offset_t   offset;
    bit               check_set;

    forever begin

      af_hpdcache_rsp[i].get(rsp);


      if ( m_hpdcache_req_with_rsp[i].exists(rsp.tid) ) begin

        // ----------------------------------------------
        // Assigning data just for printing correctly
        // ----------------------------------------------
        req       = m_hpdcache_req_with_rsp[i][rsp.tid].pop_front();
        req.wdata = rsp.rdata;

        // ----------------------------------------
        // rsp_ext is used to print the details 
        // ----------------------------------------
        rsp_ext.sid    = rsp.sid;
        rsp_ext.tid    = rsp.tid;
        rsp_ext.error  = rsp.error;
        rsp_ext.rdata  = rsp.rdata;
        rsp_ext.addr   = req.addr;

        print_hpdcache_ext_rsp_t(rsp_ext, $sformatf("SB HPDCACHE RSP %0d",i) );

        // ---------------------------------------------------------
        // get set and tag from the request address
        // ---------------------------------------------------------
        set    = hpdcache_get_req_addr_set(req.addr);
        tag    = hpdcache_get_req_addr_tag(req.addr);
        word   = hpdcache_get_req_addr_word(req.addr);
        offset = hpdcache_get_req_addr_offset(req.addr);

        addr   = req.addr;
        offset = req.addr[HPDCACHE_OFFSET_WIDTH -1 :0];
        addr[HPDCACHE_OFFSET_WIDTH -1 :0] = 0;

        word = word / HPDCACHE_REQ_WORDS; // aligning the word

        // -------------------------------------------------------------
        // Error bit check NON AMOS
        // In the case of STORE cacheable error bit is alwasy 0 for the
        // moment
        // -------------------------------------------------------------
        cov_rsp_error_check = 0;
        cov_rsp_amo_error_check = 0;
        if ( (req.op == HPDCACHE_REQ_LOAD ) || (is_cmo(req.op) ==  1'b1) || (req.op == HPDCACHE_REQ_STORE && req.pma.uncacheable == 1)) begin

          if ( m_error[set][tag] != rsp.error) begin
            `uvm_error("SB HPDCACHE ERROR ERROR", $sformatf("SET=%0d(d), TAG=%0x(x), Expected : %0b(b), RECIEVED : %0b(b)", set, tag, m_error[set][tag], rsp.error));
          end else begin
            `uvm_info("SB HPDCACHE ERROR MATCH", $sformatf("Error Expected : %0b(b), RECIEVED : %0b(b)", m_error[set][tag], rsp.error), UVM_DEBUG);
            cov_rsp_error_check = 1;
            cov_rsp_error: cover(cov_rsp_error_check);
          end
      //    m_error[set][tag]     = 1'b0; 
        end else if (req.op == HPDCACHE_REQ_STORE && req.pma.uncacheable == 0) begin
 //         // In the case of cacheable store(WT),  error is always 0
          if((req.pma.wr_policy_hint == HPDCACHE_WR_POLICY_WT) || (req.pma.wr_policy_hint == HPDCACHE_WR_POLICY_AUTO) & (m_hpdcache_conf.m_cfg_default_wb_i == 0)) m_error[set][tag]     = 1'b0; 
          if ( m_error[set][tag] != rsp.error) begin
            `uvm_error("SB HPDCACHE ERROR ERROR", $sformatf("SET=%0d(d), TAG=%0x(x),  Expected : %0b(b), RECIEVED : %0b(b)", set, tag, m_error[set][tag], rsp.error));
          end else begin
            `uvm_info("SB HPDCACHE ERROR MATCH", $sformatf("Error Expected : %0b(b), RECIEVED : %0b(b)", m_error[set][tag], rsp.error), UVM_DEBUG);
          end
       // end else if (req.op == RESERVED) begin
       //   if(rsp.error != 1'b1) `uvm_error("SB HPDCACHE ERROR ERROR", $sformatf("SET=%0d(d), TAG=%0x(x),  Expected : %0b(b), RECIEVED : %0b(b)", set, tag, 1'b1, rsp.error));
        end else begin
          if (!( req.op == HPDCACHE_REQ_STORE)) begin
            if ( m_error_amo[set][tag] != rsp.error) begin
              `uvm_error("SB HPDCACHE ERROR ERROR", $sformatf("SET=%0d(d), TAG=%0x(x),  Expected : %0b(b), RECIEVED : %0b(b)", set, tag, m_error_amo[set][tag], rsp.error));
            end else begin
              `uvm_info("SB HPDCACHE ERROR MATCH", $sformatf("Error Expected : %0b(b), RECIEVED : %0b(b)", m_error_amo[set][tag], rsp.error), UVM_DEBUG);
              cov_rsp_amo_error_check = 1;
              cov_rsp_amo_error: cover(cov_rsp_amo_error_check);
            end
            m_error_amo[set][tag] = 1'b0; 
          end
        end

        if((m_top_cfg.m_bPLRU_enable == 1) & (req.op == HPDCACHE_REQ_LOAD) & (req.pma.uncacheable == 0) & (rsp.error ==  0)) begin
          check_set = 0;
          cov_tag_dir_hit_check = 0;
          for(int way = 0; way < HPDCACHE_WAYS; way++) begin
            `uvm_info("SB CACHE PLRU HIT SEARCH", $sformatf("Set %0x(x) Tag %0x(x) STATUS %s", set,  m_tag_dir[set][way].tag, m_tag_dir[set][way].status), UVM_DEBUG);
            if((m_tag_dir[set][way].tag == tag) & (m_tag_dir[set][way].status == SET_IN_HPDCACHE)) begin
              check_set = 1;
              cov_tag_dir_hit_check = 1;
              cov_tag_dir_hit: cover(cov_tag_dir_hit_check);
            end
          end
          if(check_set == 0) begin
            `uvm_error("SB CACHE PLRU HIT ERROR", $sformatf("Set %0x(x) Tag %0x(x)", set, tag ));
          end
        end

        // -------------------------------------------------
        // Check data if load rsp
        // Or a valid AMO request 
        // -------------------------------------------------
        if (   (req.op == HPDCACHE_REQ_LOAD ) || (is_cmo(req.op)) ||
              !(req.op == HPDCACHE_REQ_AMO_SC || req.op == HPDCACHE_REQ_STORE || req.op == HPDCACHE_REQ_LOAD) &&
             (!(m_hpdcache_conf.m_cfg_error_on_cacheable_amo == 1 && req.pma.uncacheable == 0) ) ) begin

       
          // ----------------------------------------
          // Do not verify data in the case of CMOs
          // ----------------------------------------
          if(!(is_cmo(req.op))) begin
            data      = m_load_data[set][tag].pop_front()[(word)*HPDCACHE_REQ_DATA_WIDTH +: HPDCACHE_REQ_DATA_WIDTH];
            error = 'h0;
            if(m_memory.exists(addr)) // if invall comes at the same time, this may not exists
            error     = m_memory[addr].error[(word)*HPDCACHE_REQ_DATA_WIDTH/8 +: HPDCACHE_REQ_DATA_WIDTH/8];

            `uvm_info("SB HPDCACHE LOAD/AMO RSP", $sformatf("OP=%0s ADDR=%0x(x) SET=%0d(d), TAG=%0x(x)  Offset=%0d(d) WORD=%0d(d) DATA=%0x(x) ERROR=%0x(x) ERROR=%0x(x)",req.op, addr, set, tag, offset, word, data, error, m_memory[addr].error), UVM_DEBUG);
            resp_data = rsp.rdata;
            idx.delete();

            // ---------------------------------
            // Compare data only if error rrp == 0
            // Ignore if DATA is corrupted 
            // ---------------------------------
            cov_rsp_load_data_check = 0;
            cov_rsp_amo_data_check = 0;
            if(rsp.error == 0) begin
               
              // ------------------------------------
              // Check only for the bytes demanded
              // ------------------------------------
              foreach(req.be[i,j]) begin
                if(( req.be[i][j]) ) begin
                  // ----------------------------------- 
                  // If data is corrupted do not check 
                  // ----------------------------------- 
                  if(error[j+i*HPDCACHE_WORD_WIDTH/8] == 0) begin
                    if ( resp_data[j*8+i*HPDCACHE_WORD_WIDTH +: 8] != data[j*8+i*HPDCACHE_WORD_WIDTH +: 8] ) begin
                      `uvm_error("SB HPDCACHE DATA ERROR", $sformatf("ADDR=%0x(x), SET=%0d(d), TAG=%0x(x) BYTE=%0d(d) ACC DATA=%0x(x) EXP DATA=%0x(x)", req.addr, set, tag, j+i*HPDCACHE_WORD_WIDTH/8, resp_data[j*8+i*HPDCACHE_WORD_WIDTH +: 8], data[j*8+i*HPDCACHE_WORD_WIDTH +: 8]));
                    end else begin
                      `uvm_info("SB HPDCACHE DATA MATCH", $sformatf("ADDR=%0x(x), SET=%0d(d), TAG=%0x(x) BYTE=%0d(d) ACC DATA=%0x(x) EXP DATA=%0x(x)", req.addr, set, tag, j+i*HPDCACHE_WORD_WIDTH/8, resp_data[j*8+i*HPDCACHE_WORD_WIDTH +: 8], data[j*8+i*HPDCACHE_WORD_WIDTH +: 8]), UVM_MEDIUM);

                      if(req.op == HPDCACHE_REQ_LOAD) begin 
                        cov_rsp_load_data_check = 1;
                        cov_rsp_load_data: cover(cov_rsp_load_data_check);
                      end else begin
                        cov_rsp_amo_data_check = 1;
                        cov_rsp_amo_data: cover(cov_rsp_amo_data_check);
                      end
                    end
                  end else begin
                      `uvm_info("SB HPDCACHE DATA IGNORED", $sformatf("ADDR=%0x(x), SET=%0d(d), TAG=%0x(x) BYTE=%0d(d) ACC DATA=%0x(x) EXP DATA=%0x(x)", req.addr, set, tag, j+i*HPDCACHE_WORD_WIDTH/8, resp_data[j*8+i*HPDCACHE_WORD_WIDTH +: 8], data[j*8+i*HPDCACHE_WORD_WIDTH +: 8]), UVM_MEDIUM);
                  end

                end // if
              end // for

            end //  if ERROR 
          end // If CMO
        end else if (req.op == HPDCACHE_REQ_AMO_SC) begin
          resp_data = rsp.rdata; 
        
          cov_rsp_sc_data_fail_check = 0;
          cov_rsp_sc_data_pass_check = 0;
          if(m_hpdcache_conf.m_cfg_error_on_cacheable_amo == 0) begin
            if (m_sc_status[set][tag] == 1 ) begin
              if(resp_data == 0 ) `uvm_error("SB HPDCACHE SC DATA ERROR", $sformatf("ADDR=%0x(x), SET=%0d(d), TAG=%0x(x) ACC DATA=%0x(x) is wrong", req.addr, set, tag, resp_data));
              cov_rsp_sc_data_fail_check = 1;
              cov_rsp_sc_data_fail: cover(cov_rsp_sc_data_fail_check);
            end else begin
              if(resp_data > 0  ) `uvm_error("SB HPDCACHE SC DATA ERROR", $sformatf("ADDR=%0x(x), SET=%0d(d), TAG=%0x(x) ACC DATA=%0x(x) is wrong", req.addr, set, tag, resp_data));
              cov_rsp_sc_data_pass_check = 1;
              cov_rsp_sc_data_pass: cover(cov_rsp_sc_data_pass_check);
            end
          end
        end else begin
          `uvm_info("SB HPDCACHE STORE/AMO RSP", $sformatf("OP=%0s SET=%0d(d), TAG=%0x(x)  Offset=%0d(d) DATA=%0x(x)",req.op, set, tag, offset, data), UVM_MEDIUM);
        end

        // -------------------------------------------------------------
        // IF the following flag is set 
        // Dcache should send an error for amo requests on cacheable
        // section of memory 
        // -------------------------------------------------------------
        if(m_hpdcache_conf.m_cfg_error_on_cacheable_amo == 1 && req.pma.uncacheable == 0) begin
          if(! (req.op == HPDCACHE_REQ_LOAD ||req.op == HPDCACHE_REQ_STORE || (is_cmo(req.op) == 1) )) begin
            if(rsp.error == 0) begin
              `uvm_error("SB HPDCACHE ERROR ERROR", $sformatf("ADDR=%0x(x), SET=%0d(d), TAG=%0x(x) BYTE=%0d(d) ACC ERROR=%0x(x) EXP ERROR=%0x(x)", req.addr, set, tag, i, rsp.error, 1'b1 ));
            end
          end
        end

      end else begin //m_hpdcache_req_with_rsp[i].exists(rsp.tid)
        `uvm_error("SB HPDCACHE UNSOLISITED RSP", $sformatf("Response ID=%0x(x), does not exists", rsp.tid));
      end
      m_hpdcache_rsp_counter++;
    end // Forever
  endtask

  // -------------------------------------------------------------------------
  // Memory model read request
  // -------------------------------------------------------------------------
  virtual task get_mem_req();
    hpdcache_mem_req_t     req;
    hpdcache_req_mon_t     dc_req;
    hpdcache_set_t         set;
    hpdcache_tag_t         tag;
    int                tag_dir_index = -1; 

    forever begin

      af_mem_req.get(req);
      print_hpdcache_mem_req_t(req, "SB MEM REQ");

     
      // req counters 
      if((req.mem_req_command ==  HPDCACHE_MEM_ATOMIC) && !((req.mem_req_atomic == HPDCACHE_MEM_ATOMIC_LDEX) || (req.mem_req_atomic == HPDCACHE_MEM_ATOMIC_STEX)))
        m_mem_req_counter = m_mem_req_counter+2;
      else 
        m_mem_req_counter = m_mem_req_counter+1;
      // ---------------------------------------------------------
      // get set and tag from the request address
      // ---------------------------------------------------------
      set    = hpdcache_get_req_addr_set(req.mem_req_addr);
      tag    = hpdcache_get_req_addr_tag(req.mem_req_addr);


      cov_mem_id        = req.mem_req_id;
      cov_mem_cmd       = req.mem_req_command;
      cov_mem_cacheable = req.mem_req_cacheable;

      mem_command_coverage.sample();
      mem_id_coverage.sample();
      // ---------------------------------------------------------
      // Coverage: mem command and atomic operations  
      // ---------------------------------------------------------
      cov_new_mem_cmd    = req.mem_req_command;

      if(prev_mem_set == set && prev_mem_tag == tag)  b2b_mem_cmd_coverage.sample();

      cov_prev_mem_cmd        = req.mem_req_command;
      prev_mem_set            = set;
      prev_mem_tag            = tag;

      // ---------------------------------------------------------
      // Predict the cache miss
      // ATOMIC is always miss
      // ---------------------------------------------------------
      cov_tag_dir_miss_check = 0;
      if ( req.mem_req_cacheable == 1 && req.mem_req_command == HPDCACHE_MEM_READ && m_top_cfg.m_bPLRU_enable == 1 ) begin
        for (int way = 0; way < HPDCACHE_WAYS; way++) begin
          if((m_tag_dir[set][way].status == SET_IN_HPDCACHE) & (m_tag_dir[set][way].tag == tag)) begin
           `uvm_error("SB CACHE MISS ERROR", $sformatf("TAG %0x(x) should be a hit", tag) );
          end
        end
        cov_tag_dir_miss_check = 1;
        cov_tag_dir_miss: cover(cov_tag_dir_miss_check);
        `uvm_info("SB CACHE MISS", $sformatf("TAG %0x(x) is a miss", tag), UVM_HIGH );
      end
      // -------------------------------------------------------------------------------

      if ( req.mem_req_cacheable == 0 && (req.mem_req_command == HPDCACHE_MEM_READ ||req.mem_req_command ==  HPDCACHE_MEM_ATOMIC && req.mem_req_atomic == HPDCACHE_MEM_ATOMIC_LDEX)) begin

        // ---------------------------------------------------------
        // get set and tag from the request address
        // ---------------------------------------------------------
        set    = hpdcache_get_req_addr_set(req.mem_req_addr);
        tag    = hpdcache_get_req_addr_tag(req.mem_req_addr);
        // --------------------------------------------------------------
        // Pop the request only in the case of read 
        // The case of AMOs and Write is taken care of in another loop
        // --------------------------------------------------------------
        dc_req = m_hpdcache_req_uncached.pop_front(); 
        cov_mem_access_read_check = 0;
        cov_mem_access_lr_check = 0;

        if ( ! (dc_req.op == HPDCACHE_REQ_LOAD || dc_req.op == HPDCACHE_REQ_AMO_LR || (dc_req.op == HPDCACHE_REQ_CMO_PREFETCH ) ) ) begin
          `uvm_error("SB WRONG MEM ACCESS", $sformatf("HPDCACHE SET=%0d(d), TAG=%0x(x), REQ=%0s MEM_REQ=%0s", set, tag, dc_req.op, req.mem_req_command));
        end else begin 
          `uvm_info("SB MEM ACCESS MATCH", $sformatf("HPDCACHE SET=%0d(d), TAG=%0x(x), REQ=%0s MEM_REQ=%0s",set, tag,  dc_req.op, req.mem_req_command), UVM_DEBUG);
          if(dc_req.op == HPDCACHE_REQ_LOAD)   begin 
            cov_mem_access_read_check = 1;
            cov_mem_access_read: cover(cov_mem_access_read_check);
          end
          if(dc_req.op == HPDCACHE_REQ_AMO_LR) begin 
            cov_mem_access_lr_check = 1;
            cov_mem_access_lr: cover(cov_mem_access_lr_check);
          end
        end

      end

      // ---------------------------------------
      // Store the read/atomic req txn in a queue
      // To be used when the response is received
      // ---------------------------------------
      if ( ( req.mem_req_command == HPDCACHE_MEM_READ ) || ( req.mem_req_command==HPDCACHE_MEM_ATOMIC ) ) begin
        if( req.mem_req_command==HPDCACHE_MEM_ATOMIC) req.mem_req_cacheable       = ~dc_req.pma.uncacheable;
        m_read_req[req.mem_req_id]  = req;
        `uvm_info("SB MEME ATMOIC CACHEABLE", $sformatf("REQ %0x(x) MEM RES %0x(x)", dc_req.pma.uncacheable, m_read_req[req.mem_req_id].mem_req_cacheable), UVM_FULL);
      end

      if ( req.mem_req_command == HPDCACHE_MEM_WRITE ) m_mem_write_cnt++; 
      `uvm_info("DEBUG CNT MEM WRT REQ", $sformatf("mem cnt %0d(d) req cnt %0d(d)", m_mem_write_cnt, m_hpdcache_store_cnt[set][tag]), UVM_DEBUG);

      if (req.mem_req_cacheable == 1 ) begin
        if(req.mem_req_command == HPDCACHE_MEM_WRITE ) begin 
          cov_wr_wbuf_size   = req.mem_req_size;
          `uvm_info("DEBUG MEM REQ CMD", $sformatf("mem cnt %0d(d) req cnt %0d(d)", m_mem_write_cnt, m_hpdcache_store_cnt[set][tag]), UVM_DEBUG);
          wr_wbuf_size_coverage.sample();
          cnt_cache_write_miss++; 
        end

        if(req.mem_req_command == HPDCACHE_MEM_READ  ) begin 
          cov_rd_miss_size   = req.mem_req_size;
          `uvm_info("DEBUG MEM REQ CMD", $sformatf("mem cnt %0d(d) req cnt %0d(d)", m_mem_write_cnt, m_hpdcache_store_cnt[set][tag]), UVM_DEBUG);
          rd_miss_size_coverage.sample();
          cnt_cache_read_miss++;  
        end
      end

    end
  endtask

  // -------------------------------------------------------------------------
  // Memory model write request with data and byte enable
  // ext = extension -> meta data + data 
  // -------------------------------------------------------------------------
  virtual task get_mem_ext_req();
    hpdcache_mem_ext_req_t req;

    hpdcache_req_mon_t     dc_req;
    hpdcache_set_t         set;
    hpdcache_tag_t         tag;
    int                    wbuf_word;
    hpdcache_word_t        word;
    hpdcache_mem_be_t      mem_be;
    hpdcache_mem_be_t      mem_be_lr;
    hpdcache_mem_data_t    mem_data;
    hpdcache_mem_data_t    req_data;
    hpdcache_mem_data_t    req_data_bis;
    hpdcache_mem_data_t    new_req_data;
    hpdcache_req_with_ts   dc_req_store; 
    hpdcache_req_addr_t        addr;
    int                        offset;
  
    forever begin

      af_mem_ext_req.get(req);
      print_hpdcache_mem_ext_req_t(req, "SB MEM EXT REQ");


      // ---------------------------------------------------------
      // get set and tag from the request address
      // ---------------------------------------------------------
      set           = hpdcache_get_req_addr_set(req.mem_req.mem_req_addr);
      tag           = hpdcache_get_req_addr_tag(req.mem_req.mem_req_addr);
      new_req_data  = 'h0;
      // -----------------------------------
      // Verification of uncacheable sequences
      // -----------------------------------
      cov_mem_access_amo_check = 0;
      cov_mem_access_write_uncacheable_check = 0;
      cov_mem_data_write_uncacheable_check = 0;
      cov_mem_byte_enable_write_uncacheable_check = 0;
      cov_mem_data_amo_check = 0;
      if ( req.mem_req.mem_req_cacheable == 0 ) begin


        if(req.mem_req.mem_req_command == HPDCACHE_MEM_ATOMIC ) begin
          cov_atomic_cmd  = req.mem_req.mem_req_atomic; 
          cov_atomic_size = req.mem_req.mem_req_size;
          mem_atomic_coverage.sample();
        end
        // ---------------------------------------------------------
        // Get the cache request  
        // ---------------------------------------------------------
        dc_req = m_hpdcache_req_uncached.pop_front(); 
        word   = hpdcache_get_req_addr_word(dc_req.addr) / HPDCACHE_REQ_WORDS;// >> 1;
        mem_be_lr    = 'h0;
        foreach (dc_req.be[i, j]) begin
          if (dc_req.be[i][j] == 1'b1) begin 
            mem_be_lr[j + i*HPDCACHE_WORD_WIDTH/8 + (word)*HPDCACHE_REQ_DATA_WIDTH/8] = 1'b1;
            mem_data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = dc_req.wdata[i][j*8 +: 8];
          end else begin                         
            mem_be_lr[j + i*HPDCACHE_WORD_WIDTH/8 +  (word)*HPDCACHE_REQ_DATA_WIDTH/8] = 1'b0;
            req_data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = 'h0;
          end
        end
       
        if(HPDCACHE_MEM_DATA_WIDTH == HPDCACHE_WORD_WIDTH)  word = 0;

        mem_be    = 'h0;
        mem_data  = 'h0;
        req_data  = 'h0;
        req_data[(word)*HPDCACHE_REQ_DATA_WIDTH  +: HPDCACHE_REQ_DATA_WIDTH]       = req.mem_data[(word)*HPDCACHE_REQ_DATA_WIDTH +: HPDCACHE_REQ_DATA_WIDTH];
            

        `uvm_info("SB MEM ACCESS BE", $sformatf("HPDCACHE SET=%0d(d), TAG=%0x(x), REQ=%0s MEM_BE=%0x", set, tag, dc_req.op, dc_req.be), UVM_DEBUG);

        foreach (dc_req.be[i, j]) begin
          if (dc_req.be[i][j] == 1'b1) begin 
            mem_be[j + i*HPDCACHE_WORD_WIDTH/8 + (word)*HPDCACHE_REQ_DATA_WIDTH/8] = 1'b1;
            mem_data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = dc_req.wdata[i][j*8 +: 8];
          end else begin                         
            mem_be[j + i*HPDCACHE_WORD_WIDTH/8 +  (word)*HPDCACHE_REQ_DATA_WIDTH/8] = 1'b0;
            req_data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = 'h0;
          end
        end


        // -------------------------------------------------
        // get aligned addresse 
        // -------------------------------------------------
        addr   = req.mem_req.mem_req_addr; //ext_read_rsp.mem_req_addr + flit_cnt*(HPDCACHE_MEM_DATA_WIDTH/8);
        offset = addr[HPDCACHE_OFFSET_WIDTH -1 :0];
        addr[HPDCACHE_OFFSET_WIDTH -1 :0] = 0;

        if((req.mem_req.mem_req_command == HPDCACHE_MEM_ATOMIC)) begin
           // -------------------------------------------------------------
           // Any kind of store/amo(except LR/SC) at the same word address changes the lock
           // status 
           // -------------------------------------------------------------
           if(req.mem_req.mem_req_atomic  != HPDCACHE_MEM_ATOMIC_STEX) begin
             if( m_load_reservation.exists(addr)) begin 
               if(check_lr_sc_reservation(addr, mem_be_lr)) begin
                 m_load_reservation.delete(addr);
                 `uvm_info("SB HPDCACHE UNSET LR", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", addr, set, tag, offset), UVM_FULL);
               end else begin
                 `uvm_info("SB HPDCACHE NOT UNSET LR", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", addr, set, tag, offset), UVM_FULL);
               end
             end
           end
        end

        // ----------------------------------------------------------
        // Check if reqquest type is correct at the memory interface
        // ----------------------------------------------------------
        if ( dc_req.op == HPDCACHE_REQ_STORE ) begin
          if ( req.mem_req.mem_req_command != HPDCACHE_MEM_WRITE ) begin
            `uvm_error("SB WRONG MEM ACCESS", $sformatf("HPDCACHE SET=%0d(d), TAG=%0x(x), REQ=%0s MEM_REQ=%0s", set, tag, dc_req.op, req.mem_req.mem_req_command));
          end else begin
            `uvm_info("SB MEM ACCESS MATCH", $sformatf("HPDCACHE SET=%0d(d), TAG=%0x(x), REQ=%0s MEM_REQ=%0s", set, tag, dc_req.op, req.mem_req.mem_req_command), UVM_DEBUG);
            m_hpdcache_store_cnt[set][tag] = 0;
            cov_mem_access_write_uncacheable_check = 1;
            cov_mem_access_write_uncacheable: cover(cov_mem_access_write_uncacheable_check);
          end
          if(mem_be != req.mem_be) begin
            `uvm_error("SB WRONG MEM BE", $sformatf("HPDCACHE SET=%0d(d), TAG=%0x(x), REQ BE=%0x MEM_REQ BE=%0x", set, tag, mem_be, req.mem_be));
          end else begin                                                                                                  
            `uvm_info("SB MEM BE MATCH", $sformatf("HPDCACHE REQ  SET=%0d(d), TAG=%0x(x), BE=%0x MEM_REQ BE=%0x", set, tag, mem_be, req.mem_be), UVM_DEBUG);

            cov_mem_byte_enable_write_uncacheable_check = 1;
            cov_mem_byte_enable_write_uncacheable: cover(cov_mem_byte_enable_write_uncacheable_check);
          end
          if(mem_data != req_data) begin
            `uvm_error("SB WRONG MEM DATA", $sformatf("HPDCACHE SET=%0d(d), TAG=%0x(x), REQ DATA=%0x MEM_REQ DATA=%0x", set, tag, req_data, mem_data));
          end else begin
            `uvm_info("SB MEM DATA MATCH", $sformatf("HPDCACHE REQ  SET=%0d(d), TAG=%0x(x), REQ DATA=%0x MEM_REQ DATA=%0x", set, tag, req_data, mem_data), UVM_DEBUG);
            cov_mem_data_write_uncacheable_check = 1;
            cov_mem_data_write_uncacheable: cover(cov_mem_data_write_uncacheable_check);
          end
        end else if (dc_req.op ==  HPDCACHE_REQ_AMO_SC  || 
            dc_req.op ==  HPDCACHE_REQ_AMO_SWAP|| 
            dc_req.op ==  HPDCACHE_REQ_AMO_ADD || 
            dc_req.op ==  HPDCACHE_REQ_AMO_AND || 
            dc_req.op ==  HPDCACHE_REQ_AMO_OR  || 
            dc_req.op ==  HPDCACHE_REQ_AMO_XOR || 
            dc_req.op ==  HPDCACHE_REQ_AMO_MAX || 
            dc_req.op ==  HPDCACHE_REQ_AMO_MAXU|| 
            dc_req.op ==  HPDCACHE_REQ_AMO_MIN || 
            dc_req.op ==  HPDCACHE_REQ_AMO_MINU ) begin 


           if ( req.mem_req.mem_req_command != HPDCACHE_MEM_ATOMIC ) begin
             `uvm_error("SB WRONG MEM ACCESS", $sformatf("HPDCACHE SET=%0d(d), TAG=%0x(x), REQ=%0s MEM_REQ=%0s", set, tag, dc_req.op, req.mem_req.mem_req_command));
           end else begin
             `uvm_info("SB MEM ACCESS MATCH", $sformatf("HPDCACHE SET=%0d(d), TAG=%0x(x), REQ=%0s MEM_REQ=%0s", set, tag, dc_req.op, req.mem_req.mem_req_command), UVM_DEBUG);
             cov_mem_access_amo_check = 1;
             cov_mem_access_amo: cover(cov_mem_access_amo_check);
           end
           if(mem_be != req.mem_be) begin
             `uvm_error("SB WRONG MEM BE", $sformatf("HPDCACHE SET=%0d(d), TAG=%0x(x), REQ BE=%0x MEM_REQ BE=%0x", set, tag, mem_be, req.mem_be));
           end else begin                                                                                                  
             `uvm_info("SB MEM BE MATCH", $sformatf("HPDCACHE REQ  SET=%0d(d), TAG=%0x(x), BE=%0x MEM_REQ BE=%0x", set, tag, mem_be, req.mem_be), UVM_DEBUG);
             cov_mem_byte_enable_amo_check = 1;
             cov_mem_byte_enable: cover(cov_mem_byte_enable_amo_check);
           end
           if(dc_req.op ==  HPDCACHE_REQ_AMO_AND) begin 
             foreach(req.mem_be[i]) if(req.mem_be[i]) mem_data[8*i +: 8] = ~mem_data[8*i +: 8];
           end
           if(mem_data != req_data) begin
             `uvm_error("SB WRONG MEM DATA", $sformatf("HPDCACHE SET=%0d(d), TAG=%0x(x), REQ DATA=%0x MEM_REQ DATA=%0x", set, tag, req_data, mem_data));
           end else begin
             `uvm_info("SB MEM DATA MATCH", $sformatf("HPDCACHE REQ  SET=%0d(d), TAG=%0x(x), REQ DATA=%0x MEM_REQ DATA=%0x", set, tag, req_data, mem_data), UVM_DEBUG);
             cov_mem_data_amo_check = 1;
             cov_mem_data_amo: cover(cov_mem_data_amo_check);
           end
        end else begin
          `uvm_info("SB MEM ACCESS MATCH", $sformatf("HPDCACHE SET=%0d(d), TAG=%0x(x), REQ=%0s MEM_REQ=%0s", set, tag, dc_req.op, req.mem_req.mem_req_command), UVM_DEBUG);
        end
      end
      // ---------------------------------------
      // Store the req txn in a queue
      // --------------------------------------
      if(req.mem_req.mem_req_command == HPDCACHE_MEM_WRITE)  begin 
        m_write_req[req.mem_req.mem_req_id] = req;
      end
      if(req.mem_req.mem_req_command == HPDCACHE_MEM_ATOMIC) begin 
        req.mem_req.mem_req_cacheable = ~dc_req.pma.uncacheable;
        m_write_req[req.mem_req.mem_req_id] = req;
      end

      `uvm_info("DEBUG CNT MEM WRT EXT REQ", $sformatf("mem cnt %0d(d) req cnt %0d(d)", m_mem_write_cnt, m_hpdcache_store_cnt[set][tag]), UVM_DEBUG);
    end // Forever 
  endtask

  // -------------------------------------------------------------------------
  // get read miss response
  // update the cache
  //
  // -------------------------------------------------------------------------
  virtual task get_mem_read_rsp();
    hpdcache_mem_ext_resp_r_t  ext_read_rsp;
    hpdcache_mem_resp_r_t      read_rsp;
    hpdcache_set_t             set;
    hpdcache_tag_t             tag;
    hpdcache_req_mon_t         dc_req;
    hpdcache_req_addr_t        addr;
    int                        tag_dir_index; 
    hpdcache_c                 new_node;
    int                        flit_cnt;
    int                        offset;
    int                        offset_aligned;
    int                        size; 

    flit_cnt = 0;
    forever begin
      af_mem_read_rsp.get( read_rsp );

      // USED for PLRU prediction 
      m_rd_amo_rsp_rcv = 0;
      // -------------------------------------
      // Print the correspoind request
      // Print the response
      // -------------------------------------
      ext_read_rsp.mem_rsp      = read_rsp;
      
      ext_read_rsp.mem_req_addr = m_read_req[read_rsp.mem_resp_r_id].mem_req_addr;
      print_hpdcache_mem_resp_r_t(ext_read_rsp, "SB MEM READ RSP");

      if(read_rsp.mem_resp_r_last == 1) flit_cnt = 0;
      else flit_cnt++; 

      // -------------------------------------------------
      // get aligned addresse 
      // -------------------------------------------------
      addr   = ext_read_rsp.mem_req_addr + flit_cnt*(HPDCACHE_MEM_DATA_WIDTH/8);
      offset = addr[HPDCACHE_OFFSET_WIDTH -1 :0];
      addr[HPDCACHE_OFFSET_WIDTH -1 :0] = 0;

      // ---------------------------------------------------------
      // get set and tag from the request address
      // ---------------------------------------------------------
      set = hpdcache_get_req_addr_set(ext_read_rsp.mem_req_addr);
      tag = hpdcache_get_req_addr_tag(ext_read_rsp.mem_req_addr);


      if(m_read_req[read_rsp.mem_resp_r_id].mem_req_command == HPDCACHE_MEM_ATOMIC) begin
        // -------------------------------------------------------------------------------
        // USED for PLRU/LR/SC: Flag that rd amo is received
        m_rd_amo_rsp_rcv = 1;
        if(m_read_req[read_rsp.mem_resp_r_id].mem_req_atomic  == HPDCACHE_MEM_ATOMIC_LDEX) m_wr_amo_rsp_rcv = 1; // no write rsp in the case of LDEX
      end

      // Remove the reservation as soon as LDEX is observed
      if(m_read_req[read_rsp.mem_resp_r_id].mem_req_atomic  == HPDCACHE_MEM_ATOMIC_LDEX)
        foreach(m_load_reservation[i]) m_load_reservation.delete(i);
      // ---------------------------------------------------------
      // Read has responded with an error 
      // Mark data to be corrupted
      // ---------------------------------------------------------
      if(read_rsp.mem_resp_r_error == HPDCACHE_MEM_RESP_NOK) begin

        if(m_memory.exists(addr)) foreach(m_memory[addr].error[i]) m_memory[addr].error[i] = 1'b1; 

        // --------------------------------------------------------
        // If LR response is an error 
        // Cancel the reservation 
        // --------------------------------------------------------
        if(m_read_req[read_rsp.mem_resp_r_id].mem_req_command == HPDCACHE_MEM_ATOMIC) begin 

          m_error_amo[set][tag] = 1'b1;
        //  if(m_read_req[read_rsp.mem_resp_r_id].mem_req_atomic  == HPDCACHE_MEM_ATOMIC_LDEX) begin 
        //    m_load_reservation.delete(addr);
        //  end

        end else begin
          m_error[set][tag]     = 1'b1;
        //  m_error_amo[set][tag] = 1'b0;
        end
        m_rd_amo_rsp_rcv = 0;
        m_wr_amo_rsp_rcv = 0;
      end else begin

//        if(m_read_req[read_rsp.mem_resp_r_id].mem_req_command == HPDCACHE_MEM_ATOMIC) m_error_amo[set][tag] = 1'b0;
        if(m_read_req[read_rsp.mem_resp_r_id].mem_req_command == HPDCACHE_MEM_READ)   m_error[set][tag]     = 1'b0;  
        // -------------------------------------------------------------------------------

        // -----------------------------
        // Update tag dir 
        // Update bPLRU
        // -----------------------------
        if(m_read_req[read_rsp.mem_resp_r_id].mem_req_command == HPDCACHE_MEM_READ  & m_read_req[read_rsp.mem_resp_r_id].mem_req_cacheable == 1 & read_rsp.mem_resp_r_last == 1) begin 
          m_memory[addr].error = 'h0;
          if(m_top_cfg.m_bPLRU_enable == 1 & m_read_req[read_rsp.mem_resp_r_id].mem_req_cacheable == 1) begin 
            tag_dir_index = -1;
            for (int way = 0; way < HPDCACHE_WAYS; way++) begin
              `uvm_info("sb cache hit plru search", $sformatf("status %s tag %0x(x) is a hit", m_tag_dir[set][way].status, m_tag_dir[set][way].tag), UVM_DEBUG );
              if(m_tag_dir[set][way].status == SET_INVALID || m_tag_dir[set][way].status == SET_NOT_IN_HPDCACHE) begin 
                tag_dir_index = way;
                break;
              end
            end

            if(tag_dir_index <0) tag_dir_index = cache_miss_update_bPLRU(set);
            else cache_hit_update_bPLRU(set, tag_dir_index);
            `uvm_info("SB PLRU CACHE LINE EVICTED", $sformatf("INDEX %0d(d) STATUS %s TAG %0x", tag_dir_index, m_tag_dir[set][tag_dir_index].status, m_tag_dir[set][tag_dir_index].tag), UVM_HIGH );
            m_tag_dir[set][tag_dir_index].tag    = tag;
            m_tag_dir[set][tag_dir_index].status = SET_IN_HPDCACHE;
          end
        end
      end
    
      // ----------------------------------------------------------------------
      // Update PLRU in case of both read and write responses are recieved 
      // In the case of a miss nothing is done 
      // in the case of a hit PLRU is updated
      // -----------------------------------------------------------------------
      if(m_read_req[read_rsp.mem_resp_r_id].mem_req_command == HPDCACHE_MEM_ATOMIC) begin

        if(m_rd_amo_rsp_rcv == 1 & m_wr_amo_rsp_rcv == 1) begin
          if(m_top_cfg.m_bPLRU_enable == 1) begin
            tag_dir_index = -1;
            for (int way = 0; way < HPDCACHE_WAYS; way++) begin
              `uvm_info("sb cache hit plru amo search", $sformatf("status %s tag %0x(x) is a hit", m_tag_dir[set][way].status, m_tag_dir[set][way].tag), UVM_DEBUG );
              if(m_tag_dir[set][way].status == SET_IN_HPDCACHE & (m_tag_dir[set][way].tag == tag)) begin 
                tag_dir_index = way;
                break;
              end
            end

            if(tag_dir_index >= 0) cache_hit_update_bPLRU(set, tag_dir_index);
            m_rd_amo_rsp_rcv = 0;
            m_wr_amo_rsp_rcv = 0;
          end
          size = m_read_req[read_rsp.mem_resp_r_id].mem_req_size;
           // Cancel LR if needed
           // -------------------------------------------------------------
           // Any kind of store/amo(except LR/SC) at the same word address changes the lock
           // status 
           // -------------------------------------------------------------
           if( m_load_reservation.exists(addr)) begin 
             if(check_lr_sc_reservation(addr, mem_be_res)) begin
               m_load_reservation.delete(addr);
               `uvm_info("SB HPDCACHE UNSET LR", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", addr, set, tag, offset), UVM_FULL);
             end else begin
               `uvm_info("SB HPDCACHE NOT UNSET LR", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", addr, set, tag, offset), UVM_FULL);
             end
           end
           // set reservation
           if(m_read_req[read_rsp.mem_resp_r_id].mem_req_atomic  == HPDCACHE_MEM_ATOMIC_LDEX) begin
            
             offset_aligned = (offset >> 3) << 3;
             `uvm_info("SB HPDCACHE SET LR Before Offset", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x) Offset=%0d(d) be %0x(x)", addr, set, tag, offset, mem_be_res), UVM_FULL);
             for(int i = offset_aligned; i < offset_aligned+8; i++) mem_be_res[i] = 1'b1;
             m_load_reservation[addr] = mem_be_res;
             `uvm_info("SB HPDCACHE SET LR Before Offset", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x) Offset=%0d(d) be %0x(x)", addr, set, tag, offset, mem_be_res), UVM_FULL);

           end
        end

      end else begin
        m_rd_amo_rsp_rcv = 0;
      end

      m_read_rsp_counter++;
    end
  endtask: get_mem_read_rsp

  virtual task get_mem_write_rsp();
    hpdcache_mem_resp_w_t     write_rsp;
    hpdcache_mem_ext_resp_w_t ext_write_rsp;
    hpdcache_set_t             set;
    hpdcache_tag_t             tag;
    hpdcache_req_addr_t        addr;
    hpdcache_word_t            word;
    int                        tag_dir_index;
    int                        offset;
    int                        size; 

    forever begin
      af_mem_write_rsp.get(write_rsp);

      // -------------------------------------
      // Print the correspoind request
      // Print the response
      // -------------------------------------
      ext_write_rsp.mem_rsp      = write_rsp;
      ext_write_rsp.mem_req_addr = m_write_req[write_rsp.mem_resp_w_id].mem_req.mem_req_addr;

      print_hpdcache_mem_resp_w_t(ext_write_rsp, "SB MEM WRITE RSP");

      // -------------------------------------------------
      // get aligned addresse 
      // -------------------------------------------------
      addr   = ext_write_rsp.mem_req_addr;
      offset = addr[HPDCACHE_OFFSET_WIDTH -1 :0];
      addr[HPDCACHE_OFFSET_WIDTH -1 :0] = 0;
      // ---------------------------------------------------------------------------------------------------
      // ---------------------------------------------------------
      // get set and tag from the request address
      // ---------------------------------------------------------
      set  = hpdcache_get_req_addr_set(ext_write_rsp.mem_req_addr);
      tag  = hpdcache_get_req_addr_tag(ext_write_rsp.mem_req_addr);
      word = hpdcache_get_req_addr_word(ext_write_rsp.mem_req_addr);

      //adjust the cache word to memory word
      word = word / (HPDCACHE_MEM_DATA_WIDTH/ HPDCACHE_WORD_WIDTH);
      // ---------------------------------------------------------
      // Write has responded with an error 
      // Mark data to be corrupted
      //
      // In the case of write cacheable 
      // do not set the m_error = 1 as, in this case cache has already
      // responded before sending the request to memory interface
      //
      // ---------------------------------------------------------


      if(m_write_req[write_rsp.mem_resp_w_id].mem_req.mem_req_command == HPDCACHE_MEM_ATOMIC) m_wr_amo_rsp_rcv = 1;

      foreach(m_write_req[write_rsp.mem_resp_w_id].mem_be[i]) begin
        if(write_rsp.mem_resp_w_error == HPDCACHE_MEM_RESP_NOK) begin
          
          m_wr_amo_rsp_rcv = 0;
          m_rd_amo_rsp_rcv = 0;

          if(m_write_req[write_rsp.mem_resp_w_id].mem_req.mem_req_command == HPDCACHE_MEM_ATOMIC) begin 
            m_error_amo[set][tag] = 1'b1;
          end else begin
            // ------------------------------------------------
            // If cacheable, req response has alreayd arrived.
            // ------------------------------------------------
            if(m_write_req[write_rsp.mem_resp_w_id].mem_req.mem_req_cacheable == 0)  m_error[set][tag]     = 1'b1;
           // else  m_error[set][tag]     = 1'b1;
          end

          // ------------------------------------------------
          // Mark data as corrupted
          // ------------------------------------------------
          if(m_write_req[write_rsp.mem_resp_w_id].mem_be[i] == 1) begin 
            if(m_memory.exists(addr)) m_memory[addr].error[i + word*HPDCACHE_MEM_DATA_WIDTH/8] = 1; 
          end

        end else begin

          if(m_write_req[write_rsp.mem_resp_w_id].mem_req.mem_req_command == HPDCACHE_MEM_WRITE ) begin
            m_error[set][tag] = 1'b0;  
            if(m_write_req[write_rsp.mem_resp_w_id].mem_be[i] == 1) begin 
              if(m_memory.exists(addr)) begin
                m_memory[addr].error[i + word*HPDCACHE_MEM_DATA_WIDTH/8] = 0;
//                m_memory[addr].data[8*i + word*HPDCACHE_MEM_DATA_WIDTH +: 8] = m_write_req[write_rsp.mem_resp_w_id].mem_data[8*i + word*HPDCACHE_MEM_DATA_WIDTH +:8];
//                `uvm_info("SB HPDCACHE MEM STORE", $sformatf("SET=%0d(d), TAG=%0x(x) WORD=%0d(d) Offset=%0d(d) DATA=%0x(x) MEM=%0x(x)", set, tag, word, offset, m_memory[addr].data, m_write_req[write_rsp.mem_resp_w_id].mem_data), UVM_MEDIUM);
              end
            end
          end

        end
      end


      if(m_write_req[write_rsp.mem_resp_w_id].mem_req.mem_req_command == HPDCACHE_MEM_ATOMIC && 
         m_write_req[write_rsp.mem_resp_w_id].mem_req.mem_req_atomic  == HPDCACHE_MEM_ATOMIC_STEX) begin 
       m_rd_amo_rsp_rcv = 1; // Only write rsp in this case 
       // IF AMO response is not correct
       if(write_rsp.mem_resp_w_is_atomic == 0) begin

         m_wr_amo_rsp_rcv = 0;
         m_rd_amo_rsp_rcv = 0;
         m_sc_status[set][tag] = 1'b1;
         // ------------------------------------------------
         // Mark data as corrupted
         // ------------------------------------------------
         foreach(m_write_req[write_rsp.mem_resp_w_id].mem_be[i]) begin
           if(m_write_req[write_rsp.mem_resp_w_id].mem_be[i] == 1) begin
             // If invall comes at the same time this node may not exists
             if(m_memory.exists(addr)) m_memory[addr].error[i + word*HPDCACHE_MEM_DATA_WIDTH/8] = 1;  
           end
         end
     
       end else begin
         m_sc_status[set][tag] = 1'b0;
       end 
      end

      // ----------------------------------------------------------------------
      // Update PLRU in case of both read and write responses are recieved 
      // In the case of a miss nothing is done 
      // in the case of a hit PLRU is updated
      // -----------------------------------------------------------------------
      if(m_rd_amo_rsp_rcv == 1 & m_wr_amo_rsp_rcv == 1) begin
        if(m_write_req[write_rsp.mem_resp_w_id].mem_req.mem_req_command == HPDCACHE_MEM_ATOMIC & m_top_cfg.m_bPLRU_enable == 1) begin
          tag_dir_index = -1;
          for (int way = 0; way < HPDCACHE_WAYS; way++) begin
            `uvm_info("sb cache hit plru amo search", $sformatf("status %s tag %0x(x) is a hit", m_tag_dir[set][way].status, m_tag_dir[set][way].tag), UVM_DEBUG );
            if(m_tag_dir[set][way].status == SET_IN_HPDCACHE & (m_tag_dir[set][way].tag == tag)) begin 
              tag_dir_index = way;
              break;
            end
          end

          if(tag_dir_index >= 0) cache_hit_update_bPLRU(set, tag_dir_index);
          m_rd_amo_rsp_rcv = 0;
          m_wr_amo_rsp_rcv = 0;
        end

      end

      `uvm_info("SB MEM WRITE RSP DEBUG", $sformatf("ID=%0x(x) ADDR=%0x(x) SET=%0d(d), TAG=%0x(x) ERROR=%0x(x)", write_rsp.mem_resp_w_id, addr, set, tag, m_memory[addr].error), UVM_DEBUG);

      if(m_write_req[write_rsp.mem_resp_w_id].mem_req.mem_req_command == HPDCACHE_MEM_WRITE ) begin
        m_mem_write_cnt--;
      end
      `uvm_info("DEBUG CNT MEM WRT RSP", $sformatf("mem cnt %0d(d) req cnt %0d(d)", m_mem_write_cnt, m_hpdcache_store_cnt[set][tag]), UVM_DEBUG);
      m_write_rsp_counter++;
    end
  endtask: get_mem_write_rsp

  task global_cycle_counter();
     forever begin
       vif.wait_n_clocks(1);
       m_global_cycle_count++;
     end //forever 
  endtask : global_cycle_counter

  // ------------------------------------------------------------
  function int get_index_from_tag_dir(hpdcache_set_t set, hpdcache_tag_t tag);
    int index; 

    index = -1; 
    for (int way = 0; way < HPDCACHE_WAYS; way++) begin
      if((m_tag_dir[set][way].status == SET_IN_HPDCACHE) & (m_tag_dir[set][way].tag == tag)) begin 
        index = way;
        `uvm_info("SB CACHE HIT PLRU SEARCH", $sformatf("status %s set %0d(d) tag %0x(x) index %0d(d)", m_tag_dir[set][index].status, set, m_tag_dir[set][index].tag, index), UVM_DEBUG );
        break;
      end
    end
    return index; 
  endfunction

  // ------------------------------------------------------------
  // CACHE HIT: update PLRU 
  // CACHE MISS: Updat PLRU And get the index 
  // ------------------------------------------------------------
  function void cache_hit_update_bPLRU(hpdcache_set_t set, int index);
     `uvm_info("SB PLRU BEFORE UPDATE", $sformatf("PLRU %0x(x) set %0d(d) %0d(d)", m_bPLRU_table[set], set, index), UVM_HIGH );
     if(($countones(m_bPLRU_table[set]) == HPDCACHE_WAYS - 1) & (m_bPLRU_table[set][index] == 1'b0)) begin 
       m_bPLRU_table[set] = 'h0;
     end
     m_bPLRU_table[set][index] = 1'b1; 
     `uvm_info("SB PLRU UPDATE", $sformatf("PLRU %0x(x) set %0d(d) %0d(d)", m_bPLRU_table[set], set, index), UVM_HIGH );
  endfunction

  function int cache_miss_update_bPLRU(hpdcache_set_t set);
     int index;
     for (int way = 0; way < HPDCACHE_WAYS; way++) begin
       if(m_bPLRU_table[set][way] == 1'b0)  begin 
         index = way;
         break;
       end
     end

     if($countones(m_bPLRU_table[set]) == HPDCACHE_WAYS - 1) begin 
       m_bPLRU_table[set] = 'h0;
     end
     m_bPLRU_table[set][index] = 1'b1; 

     `uvm_info("SB PLRU UPDATE", $sformatf("PLRU %0x(x) set %0d(d), index %0d(d)", m_bPLRU_table[set], set, index), UVM_HIGH );
     return index; 
  endfunction
  // ---------------------------------------------------
  // If address doesnt exists
  // create a new node in memory model 
  // The data should be same in the memory model
  // and Shadow memory in the SB
  // ---------------------------------------------------
  function void create_and_init_memory_node(hpdcache_req_addr_t addr, int num_burst = 1);

    memory_c#(HPDCACHE_MEM_DATA_WIDTH*HPDCACHE_MEM_LOAD_NUM)         new_node;     // contains addr and intruction
    hpdcache_req_addr_t                          burst_addr;

    if(!m_memory.exists(addr)) begin

	  new_node   = new("new memory node");
      if(!new_node.randomize())  `uvm_fatal( "HPDCACHE RSP_DELAY", "Response delay randomization failed" )
      m_memory[addr] = new_node;

      for(int i = 0; i < num_burst; i++) begin
        burst_addr = addr + (HPDCACHE_MEM_DATA_WIDTH/8)*i;
        `uvm_info("SB MEME CREATENEW MEME NODE DEBUG", $sformatf("ADDR=%0x(x) DATA=%0x(x)", burst_addr, m_memory[addr].data[i*HPDCACHE_MEM_DATA_WIDTH +: HPDCACHE_MEM_DATA_WIDTH]), UVM_DEBUG);

         // Add the same node in the memory response model
         m_mem_rsp_model.add_memory_node(burst_addr, m_memory[addr].data[i*HPDCACHE_MEM_DATA_WIDTH +: HPDCACHE_MEM_DATA_WIDTH]);

      end
    end
  endfunction

  function void delete_memory_node(hpdcache_req_addr_t addr);
    `uvm_info("SB MEME DELETE NODE DEBUG", $sformatf("ADDR=%0x(x)", addr), UVM_DEBUG);
    if(m_memory.exists(addr)) begin
      m_memory.delete(addr);
      m_mem_rsp_model.delete_memory_node(addr);
    end
  endfunction

  function bit check_lr_sc_reservation(hpdcache_req_addr_t a, hpdcache_mem_be_t b);
    hpdcache_mem_be_t be = m_load_reservation[a];
    `uvm_info("SB HPDCACHE LR SC check", $sformatf("ADDR=%0x(x) SET=%0x(x) ", be, b), UVM_FULL);
    
    foreach(be[i]) begin
      if (be[i] & b[i] == 1'b1) return 1; 
    end

    return 0;

  endfunction
  // -----------------------------------------------------------------------
  // Function to update local memory 
  // -----------------------------------------------------------------------
//  function void update_local_memory(hpdcache_req_be_t B, int word, hpdcache_req_data_t D);
//      foreach ( B[i,j] ) begin
//        if ( B[i][j]) m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = D[i][j*8 +: 8] | m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8];
//      end
//
//  endfunction 
  // -----------------------------------------------------------------------
  // Report phase
  // -----------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase); 

  endfunction: report_phase

  function int get_req_counter();
    get_req_counter = m_hpdcache_req_counter;
  endfunction

  function int get_mem_req_counter();
    get_mem_req_counter = m_mem_req_counter;
  endfunction

   // Function to addition and substraction
   function logic [8:0] adder(input logic [7:0] x, y, input logic cin);

      logic [7:0] s; // internal signals
      logic c;

      c = cin;
      for (int k = 0; k < 8; k++) begin
        s[k] = x[k] ^ y[k] ^ c;
        c = (x[k] & y[k]) | (c & x[k]) | (c & y[k]);
      end
      adder = {c, s};
   endfunction

  covergroup  cfg_error_on_cacheable_amo_coverage;
    cfg_error_on_cacheable_amo: coverpoint cov_cfg_error_on_cacheable_amo;
    new_hpdcache_op             : coverpoint cov_new_hpdcache_op;

    error_on_cacheable_amo_x_hpdcache_op : cross new_hpdcache_op, cfg_error_on_cacheable_amo;
  endgroup

  covergroup sc_pass_word_coverage;
    sc_pass_word: coverpoint cov_sc_pass_word {
      bins all_bins[] = {[0:3]};
    }
  endgroup 

  covergroup wr_wbuf_size_coverage;
    wr_wbuf_size: coverpoint cov_wr_wbuf_size{
      bins all_bins[] = {[0:4]};
  }

  endgroup 
  
  covergroup rd_miss_size_coverage;
    rd_miss_size: coverpoint cov_rd_miss_size{
      bins all_bins[] = {[0:4]};
  }

  endgroup 

  covergroup mem_id_coverage;
    mem_id : coverpoint cov_mem_id;

  endgroup 
  
  covergroup mem_command_coverage;
    mem_cacheable : coverpoint cov_mem_cacheable;
    mem_cmd       : coverpoint cov_mem_cmd;

    mm_cmd_x_cacheable: cross mem_cmd, mem_cacheable; 
  endgroup 

  covergroup wr_merge_cnt_coverage;
    wr_merge_cnt: coverpoint cov_wr_merge_cnt {
      bins all_bins[] = {[0:63]};
    }
  endgroup 

  covergroup mem_atomic_coverage; 
     atomic_size : coverpoint cov_atomic_size; 
     atomic_cmd  : coverpoint cov_atomic_cmd;
     atomic_size_x_atomic_op : cross  atomic_size, atomic_cmd;
   endgroup: mem_atomic_coverage; 


   covergroup b2b_mem_cmd_coverage;
     prev_mem_cmd: coverpoint cov_prev_mem_cmd; 
     new_mem_cmd : coverpoint cov_new_mem_cmd; 
     prev_new_mem_cmd : coverpoint cov_new_mem_cmd {
       bins all_transition[] = ([cov_new_mem_cmd.first:cov_new_mem_cmd.last] => [cov_new_mem_cmd.first:cov_new_mem_cmd.last]);
     }


   endgroup : b2b_mem_cmd_coverage;

   covergroup b2b_hpdcache_req_op_coverage;
     prev_hpdcache_op: coverpoint cov_prev_hpdcache_op ;
     new_hpdcache_op : coverpoint cov_new_hpdcache_op;
     prev_new_hpdcache_op : coverpoint cov_new_hpdcache_op {
       bins all_transition[] = ([cov_new_hpdcache_op.first:cov_new_hpdcache_op.last] => [cov_new_hpdcache_op.first:cov_new_hpdcache_op.last]);
    //   ignore_bins  reserved0 = (RESERVED => [cov_new_hpdcache_op.first:cov_new_hpdcache_op.last]);
    //   ignore_bins  reserved1 = ([cov_new_hpdcache_op.first:cov_new_hpdcache_op.last] => RESERVED);
     }



   endgroup : b2b_hpdcache_req_op_coverage;

   covergroup b2b_hpdcache_req_op_error_no_need_coverage;
     prev_hpdcache_op: coverpoint cov_prev_hpdcache_op ;
     new_hpdcache_op : coverpoint cov_new_hpdcache_op;
     prev_new_hpdcache_op : coverpoint cov_new_hpdcache_op {
       bins all__transition[]  = ([cov_new_hpdcache_op.first:cov_new_hpdcache_op.last] => [cov_new_hpdcache_op.first:cov_new_hpdcache_op.last]);
       bins all_transition[]   = ([cov_new_hpdcache_op.first:cov_new_hpdcache_op.last] => [cov_new_hpdcache_op.first:cov_new_hpdcache_op.last]);
    //   ignore_bins  reserved0 = (RESERVED => [cov_new_hpdcache_op.first:cov_new_hpdcache_op.last]);
    //   ignore_bins  reserved1 = ([cov_new_hpdcache_op.first:cov_new_hpdcache_op.last] => RESERVED);
     }

   endgroup : b2b_hpdcache_req_op_error_no_need_coverage;
endclass: hpdcache_sb
