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
//  Description : DCache transaction used in the driver to drive the requests
// ----------------------------------------------------------------------------

// -----------------------------------------------------------------------
// Class hpdcache_txn
//
// Contains fields that are sent to the scoreboard for further analysis
// -----------------------------------------------------------------------
class hpdcache_txn extends uvm_sequence_item;
   `uvm_object_utils(hpdcache_txn )

//    // choses between one of the 3 write policies or staticom
//    //   HPDCACHE_WR_POLICY_AUTO = 3'b001,
//    //   HPDCACHE_WR_POLICY_WB   = 3'b010,
//    //   HPDCACHE_WR_POLICY_WT   = 3'b100
//    //   RANDOM
//    static bit[2:0]  m_write_policy;
//    // ------------------------------------------------------------------------
//    // tag with 4 lsb == m_wt_tag_bits are fixed write through
//    // ------------------------------------------------------------------------
//    static bit[3:0]  m_wt_tag_bits;
//    // ------------------------------------------------------------------------
//    // tag with 4 lsb == m_wb_tag_bits are fixed write back
//    // ------------------------------------------------------------------------
//    static bit[3:0]  m_wb_tag_bits;
    
    //          Request Interfacei
    rand  hpdcache_set_t        m_req_set;
    rand  hpdcache_tag_t        m_req_tag;
    rand  hpdcache_word_t       m_req_word;
    rand  hpdcache_req_offset_t m_req_offset;
    rand  hpdcache_req_addr_t   m_req_addr;

    rand  hpdcache_req_data_t   m_req_wdata;
    rand  hpdcache_req_op_t     m_req_op;
    rand  hpdcache_req_be_t     m_req_be;
    rand  hpdcache_req_size_t   m_req_size;

    rand  logic                     m_req_uncacheable;
    rand  logic                     m_req_io;
    rand  hpdcache_wr_policy_hint_t m_wr_policy_hint;

    rand  logic                 m_req_abort;
    rand  logic                 m_req_phys_indexed;

    rand  hpdcache_req_sid_t    m_req_sid;
    rand  hpdcache_req_tid_t    m_req_tid;
    rand  logic                 m_req_need_rsp;

    //          Response Interface
    rand  hpdcache_req_data_t   m_rsp_rdata;
    rand  hpdcache_req_sid_t    m_rsp_sid;
    rand  hpdcache_req_tid_t    m_rsp_tid;

    rand hpdcache_req_tid_t     q_inflight_tid[hpdcache_req_tid_t];

    rand int                    m_txn_idle_cycles; 

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_txn");
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

    constraint m_constraint_c           {solve m_req_addr before m_req_uncacheable;
                                         solve m_req_uncacheable before m_req_size;
                                         solve m_req_tag before m_wr_policy_hint;
                                         solve m_req_tag before m_req_op;};

    constraint m_tag_c                 {  m_req_tag dist {0                                   := 01, 
                                                            [1:{HPDCACHE_TAG_WIDTH{1'b1}} - 1]   := 98, 
                                                            {HPDCACHE_TAG_WIDTH{1'b1}}           := 01 }; 
                                                   };

    
    constraint m_req_op_amo_c       {m_req_op dist{
                                         HPDCACHE_REQ_LOAD        := 40,
                                         HPDCACHE_REQ_STORE       := 40,
                                         HPDCACHE_REQ_AMO_LR      := 5,
                                         HPDCACHE_REQ_AMO_SC      := 5,
                                         HPDCACHE_REQ_AMO_SWAP    := 5,
                                         HPDCACHE_REQ_AMO_ADD     := 5,
                                         HPDCACHE_REQ_AMO_AND     := 5,
                                         HPDCACHE_REQ_AMO_OR      := 5,
                                         HPDCACHE_REQ_AMO_XOR     := 5,
                                         HPDCACHE_REQ_AMO_MAX     := 5,
                                         HPDCACHE_REQ_AMO_MAXU    := 5,
                                         HPDCACHE_REQ_AMO_MIN     := 5,
                                         HPDCACHE_REQ_AMO_MINU    := 5,
                                         HPDCACHE_REQ_CMO_FENCE             := 5,
                                         HPDCACHE_REQ_CMO_PREFETCH          := 5,
                                         HPDCACHE_REQ_CMO_FLUSH_NLINE       := 5,
                                         HPDCACHE_REQ_CMO_FLUSH_ALL         := 5,
                                         HPDCACHE_REQ_CMO_FLUSH_INVAL_NLINE := 5,
                                         HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL   := 5
                                       };
                                     }
// 
//    constraint m_req_op_c           {(m_req_tag[3:0] != m_rand_tag_lsb) -> 
//                                       m_req_op dist{
//                                         HPDCACHE_REQ_LOAD        := 40,
//                                         HPDCACHE_REQ_STORE       := 40,
//                                         HPDCACHE_REQ_CMO_FENCE             := 5,
//                                         HPDCACHE_REQ_CMO_PREFETCH          := 5,
//                                         HPDCACHE_REQ_CMO_INVAL_NLINE       := 5,
//                                         HPDCACHE_REQ_CMO_INVAL_ALL         := 5,
//                                         HPDCACHE_REQ_CMO_FLUSH_NLINE       := 5,
//                                         HPDCACHE_REQ_CMO_FLUSH_ALL         := 5,
//                                         HPDCACHE_REQ_CMO_FLUSH_INVAL_NLINE := 5,
//                                         HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL   := 5
//                                       };
//                                     }
//
//


    constraint m_req_size_uc_c          { (m_req_op == HPDCACHE_REQ_LOAD ||  m_req_op == HPDCACHE_REQ_STORE || m_req_op == HPDCACHE_REQ_CMO_PREFETCH)  -> m_req_size <= $clog2(HPDCACHE_REQ_DATA_WIDTH/8);};
    constraint m_req_size_amo_c         { (is_amo(m_req_op) == 1 )  -> m_req_size inside {[2:3]} ;};
    constraint m_req_size_amo_max_c     { (is_amo(m_req_op) == 1 )  -> m_req_size <= $clog2(HPDCACHE_REQ_WORDS*HPDCACHE_WORD_WIDTH/8) ;};
    constraint m_req_size_cmo_flush_c         { (is_cmo_flush(m_req_op) == 1 )  -> m_req_size == 0 ;};
    constraint m_req_size_cmo_inval_c         { (is_cmo_inval(m_req_op) == 1 )  -> m_req_size == 0 ;};
    constraint m_req_size_cmo_fence_c         { (is_cmo_fence(m_req_op) == 1 )  -> m_req_size == 0 ;};

    // CMO Constraints 
    constraint m_req_need_rsp_cmo_c        { (is_cmo(m_req_op) == 1)        -> m_req_need_rsp == 0;};
    constraint m_req_need_rsp_cmo_flush_c  { (is_cmo_flush(m_req_op) == 1)  -> m_req_need_rsp == 0;};

    // AMOS Constraints 
    constraint m_req_need_rsp_amo_c     { (is_amo(m_req_op) == 1 ) -> m_req_need_rsp == 1;};

    constraint m_req_tid_c              {!(m_req_tid inside {q_inflight_tid});}; 

    constraint m_req_abort_c           {  m_req_abort dist { 0 := 90, 1 := 0 } ;};

  //  constraint m_offset_c               {  m_req_addr[$clog2(HPDCACHE_REQ_DATA_WIDTH/8) -1:0] inside  {[1:$clog2(HPDCACHE_REQ_DATA_WIDTH)]};};
  //  constraint m_offset1_c              {  m_req_offset[$clog2(HPDCACHE_REQ_DATA_WIDTH/8) -1:0] inside  {[1:$clog2(HPDCACHE_REQ_DATA_WIDTH)]};};
          
    constraint lots_b2b_c {
              m_txn_idle_cycles dist {       0  := 10,    // lots of b2b
                                             1  := 5,     // 1 cycle gap is good
                                          [2:5] := 5,     // gap close to pipe dept
                                          [5:32]:= 1 }; }; // less interesting

//     constraint m_wt_policy_c   { (m_write_policy == 4) -> m_wr_policy_hint == HPDCACHE_WR_POLICY_WT;};
//     constraint m_wb_policy_c   { (m_write_policy == 2) -> m_wr_policy_hint == HPDCACHE_WR_POLICY_WB;};
//     constraint m_wb_policy_c   { (m_write_policy == 1) -> m_wr_policy_hint == HPDCACHE_WR_POLICY_AUTO;};
//
//     constraint m_wt_policy_c   { ((m_write_policy == 0) & (m_req_tag[3:0] == m_wt_tag_bits)) -> m_wr_policy_hint == HPDCACHE_WR_POLICY_WT;};
//     constraint m_wb_policy_c   { ((m_write_policy == 0) & (m_req_tag[3:0] == m_wb_tag_bits)) -> m_wr_policy_hint == HPDCACHE_WR_POLICY_WB;};

    // Following fields are assingned in the sequence
    function void pre_randomize();
       super.pre_randomize();
       foreach(q_inflight_tid[i]) q_inflight_tid[i].rand_mode(0);
    endfunction 

    // Create the BB and addresses 
    function void post_randomize();
       hpdcache_word_t     word;    
       super.post_randomize();
       m_req_addr = {m_req_tag, m_req_offset};
       word = hpdcache_get_req_addr_word(m_req_addr);
       
       set_addr_alignement(m_req_size);
       if(! (is_cmo(m_req_op) == 1))
       set_byte_enable(m_req_size, m_req_addr[$clog2(HPDCACHE_REQ_DATA_WIDTH/8) -1:0], m_req_op);

    endfunction 

    // Calculate the addr alignement
    function void set_addr_alignement(int S);
       for(int i = 0; i < S; i++) m_req_addr[i] = 0; 
       for(int i = 0; i < S; i++) m_req_offset[i] = 0; 
    endfunction

    // Calculate the byte enable
    function void set_byte_enable(int S, int Of, hpdcache_req_op_t Op);

     foreach(m_req_be[i]) m_req_be[i] = 0; 

     // In the case of AMOs, BE are continous
     while(1) begin
       for(int i = Of; i < Of + 2**S; i++) begin
         m_req_be[i/HPDCACHE_BYTE_PER_WORD][i - (i/HPDCACHE_BYTE_PER_WORD)*(HPDCACHE_BYTE_PER_WORD)]     = (Op == HPDCACHE_REQ_LOAD || Op == HPDCACHE_REQ_STORE) ? $urandom_range(0, 1): 1'b1;  
       end
       if( m_req_be != 0)  break;
     end


    endfunction 
endclass: hpdcache_txn

// --------------------------------
// ONLY LOAD STORE TRANSACTION
// --------------------------------
class hpdcache_load_store_with_amos_txn extends hpdcache_txn;
   `uvm_object_utils(hpdcache_load_store_with_amos_txn )
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_load_store_with_amos_txn");
        super.new(name);
    endfunction

    constraint m_req_op_c               {m_req_op dist {HPDCACHE_REQ_LOAD     := 42, 
                                                        HPDCACHE_REQ_STORE    := 42,
                                                        HPDCACHE_REQ_AMO_SWAP := 2,
                                                        HPDCACHE_REQ_CMO_FENCE             := 2,
                                                        HPDCACHE_REQ_CMO_PREFETCH          := 2,
                                                        HPDCACHE_REQ_CMO_INVAL_NLINE       := 2,
                                                        HPDCACHE_REQ_CMO_INVAL_ALL         := 2,
                                                        HPDCACHE_REQ_CMO_FLUSH_NLINE       := 2,
                                                        HPDCACHE_REQ_CMO_FLUSH_ALL         := 2,
                                                        HPDCACHE_REQ_CMO_FLUSH_INVAL_NLINE := 2,
                                                        HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL   := 2,
                                                        HPDCACHE_REQ_AMO_OR   := 2, 
                                                        HPDCACHE_REQ_AMO_AND  := 2,  
                                                        HPDCACHE_REQ_AMO_ADD  := 2,  
                                                        HPDCACHE_REQ_AMO_XOR  := 2, 
                                                        HPDCACHE_REQ_AMO_MAX  := 2, 
                                                        HPDCACHE_REQ_AMO_MAXU := 2, 
                                                        HPDCACHE_REQ_AMO_MIN  := 2, 
                                                        HPDCACHE_REQ_AMO_MINU := 2};};

endclass 

// ---------------------------------------
// MOSTLY LR/SC operation inter mingled 
// with other type of transactions
// ---------------------------------------
class hpdcache_lr_sc_with_random_txn extends hpdcache_txn;
   `uvm_object_utils(hpdcache_lr_sc_with_random_txn )
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_lr_sc_with_random_txn");
        super.new(name);
    endfunction

    constraint m_req_op_c               {m_req_op dist {HPDCACHE_REQ_AMO_SC := 45,  HPDCACHE_REQ_AMO_LR := 45, HPDCACHE_REQ_STORE := 1, HPDCACHE_REQ_LOAD := 4};};
endclass 
// --------------------------------
// ONLY CACHEABLE TRANSACTION
// --------------------------------
class hpdcache_cacheable_only_txn extends hpdcache_txn;
   `uvm_object_utils(hpdcache_cacheable_only_txn )
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_cacheable_only_txn");
        super.new(name);
    endfunction


    constraint m_uncacheable_c             {m_req_uncacheable == 0;};
    constraint m_wt_policy_c            { m_wr_policy_hint == HPDCACHE_WR_POLICY_WT;};
endclass 

class hpdcache_mostly_cacheable_load_txn extends hpdcache_txn;
   `uvm_object_utils(hpdcache_mostly_cacheable_load_txn )
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_mostly_cacheable_load_txn");
        super.new(name);
    endfunction


    constraint m_req_op_c               {m_req_op == HPDCACHE_REQ_LOAD;};
    constraint m_uncacheable_c          {m_req_uncacheable dist { 0 := 95, 1 := 5};};
    constraint m_wt_policy_c            { m_wr_policy_hint == HPDCACHE_WR_POLICY_WT;};
endclass 

class hpdcache_mostly_cacheable_store_txn extends hpdcache_txn;
   `uvm_object_utils(hpdcache_mostly_cacheable_store_txn )
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_mostly_cacheable_store_txn");
        super.new(name);
    endfunction


    constraint m_req_op_c               {m_req_op == HPDCACHE_REQ_STORE;};
    constraint m_uncacheable_c          {m_req_uncacheable dist { 0 := 95, 1 := 5};};
    constraint m_wt_policy_c            { m_wr_policy_hint == HPDCACHE_WR_POLICY_WT;};
endclass

class hpdcache_zero_delay_cacheable_store_txn extends hpdcache_txn;
   `uvm_object_utils(hpdcache_zero_delay_cacheable_store_txn )
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_zero_delay_cacheable_store_txn");
        super.new(name);
        lots_b2b_c.constraint_mode(0);
    endfunction


    constraint m_req_op_c               {m_req_op == HPDCACHE_REQ_STORE;};
    constraint m_txn_idle_cycles_c      {m_txn_idle_cycles == 0;};
    constraint m_m_req_phys_indexed_c   {m_req_phys_indexed == 1;};
    constraint m_uncacheable_c          {m_req_uncacheable == 0;};
    constraint m_wt_policy_c            { m_wr_policy_hint == HPDCACHE_WR_POLICY_WT;};
endclass

class hpdcache_zero_delay_cacheable_load_txn extends hpdcache_txn;
   `uvm_object_utils(hpdcache_zero_delay_cacheable_load_txn )
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_zero_delay_cacheable_load_txn");
        super.new(name);
        lots_b2b_c.constraint_mode(0);
    endfunction


    constraint m_req_op_c               {m_req_op == HPDCACHE_REQ_LOAD;};
    constraint m_txn_idle_cycles_c      {m_txn_idle_cycles == 0;};
    constraint m_m_req_phys_indexed_c   {m_req_phys_indexed == 1;};
    constraint m_uncacheable_c          {m_req_uncacheable == 0;};
    constraint m_wt_policy_c            { m_wr_policy_hint == HPDCACHE_WR_POLICY_WT;};
endclass

// ---------------------------------------
// ONLY CACHEABLE TRANSACTION
// And Only load and store transaction
// ---------------------------------------
class hpdcache_zero_delay_cacheable_load_store_txn extends hpdcache_txn;
   `uvm_object_utils(hpdcache_zero_delay_cacheable_load_store_txn )
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_zero_delay_cacheable_load_store_txn");
        super.new(name);
        lots_b2b_c.constraint_mode(0);
    endfunction


    constraint m_req_op_c               {m_req_op dist { HPDCACHE_REQ_LOAD := 70, HPDCACHE_REQ_STORE :=30};};
    constraint m_txn_idle_cycles_c      {m_txn_idle_cycles == 0;};
    constraint m_uncacheable_c          {m_req_uncacheable == 0;};
    constraint m_wt_policy_c            { m_wr_policy_hint == HPDCACHE_WR_POLICY_WT;};
endclass 

// ------------------------------------------------------------------
// Send request every 50 clk cycles 
// To avoid conflicts between refill rsp and new req
// Otherwise its not possible to predict PLRU behaviour @black box
// ------------------------------------------------------------------
class hpdcache_bPLRU_txn extends hpdcache_txn;
   `uvm_object_utils(hpdcache_bPLRU_txn )
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_bPLRU_txn");
        super.new(name);
        lots_b2b_c.constraint_mode(0);
    endfunction


    constraint m_txn_idle_cycles_c      {m_txn_idle_cycles == 50;};
    constraint m_need_rsp_ld_c          {(m_req_op == HPDCACHE_REQ_LOAD ) -> m_req_need_rsp == 1;};
    constraint m_wt_policy_c            { m_wr_policy_hint == HPDCACHE_WR_POLICY_WT;};
endclass 
