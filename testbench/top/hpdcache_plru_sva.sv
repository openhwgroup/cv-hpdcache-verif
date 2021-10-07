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

`include "uvm_macros.svh"
module hpdcache_plru_sva
import hpdcache_pkg::*;
import hpdcache_common_pkg::*;
import uvm_pkg::*;
#(
    parameter hpdcache_cfg_t hpdcacheCfg = '0,

    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_word_t = logic,
    parameter type hpdcache_way_vector_t = logic,
    parameter type hpdcache_dir_entry_t = logic,

    parameter type hpdcache_data_word_t = logic,
    parameter type hpdcache_data_be_t = logic,

    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,

    parameter type hpdcache_refill_data_t = logic,
    parameter type hpdcache_refill_be_t = logic
)
    //  }}}

    //  Ports
    //  {{{
(
    //      Global clock and reset signals
    //      {{{
    input  logic                                clk_i,
    input  logic                                rst_ni,
    //      }}}

    //      Global control signals
    //      {{{
    input logic                                ready_o,
    //      }}}

    //      DIR array access interface
    //      {{{
    input  logic                                dir_match_i,
    input  hpdcache_set_t                       dir_match_set_i,
    input  hpdcache_tag_t                       dir_match_tag_i,
    input  logic                                dir_update_lru_i,
    input hpdcache_way_vector_t                dir_hit_way_o,

    input  logic                                dir_amo_match_i,
    input  hpdcache_set_t                       dir_amo_match_set_i,
    input  hpdcache_tag_t                       dir_amo_match_tag_i,
    input  logic                                dir_amo_update_plru_i,
    input hpdcache_way_vector_t                dir_amo_hit_way_o,

    input  logic                                dir_refill_sel_victim_i,
    input  logic                                dir_refill_i,
    input  hpdcache_set_t                       dir_refill_set_i,
    input  hpdcache_dir_entry_t                 dir_refill_entry_i,
    input  logic                                dir_refill_updt_plru_i,
    input hpdcache_way_vector_t                dir_victim_way_o,

    input  logic                                dir_inval_check_i,
    input  hpdcache_nline_t                     dir_inval_nline_i,
    input  logic                                dir_inval_write_i,
    input logic                                dir_inval_hit_o,

    input  logic                                dir_cmo_check_i,
    input  hpdcache_set_t                       dir_cmo_check_set_i,
    input  hpdcache_tag_t                       dir_cmo_check_tag_i,
    input hpdcache_way_vector_t                dir_cmo_check_hit_way_o,

    input  logic                                dir_cmo_inval_i,
    input  hpdcache_set_t                       dir_cmo_inval_set_i,
    input  hpdcache_way_vector_t                dir_cmo_inval_way_i,
    //      }}}

    //      DATA array access interface
    //      {{{
    input  logic                                data_req_read_i,
    input  hpdcache_set_t                       data_req_read_set_i,
    input  hpdcache_req_size_t                  data_req_read_size_i,
    input  hpdcache_word_t                      data_req_read_word_i,
    input hpdcache_req_data_t                  data_req_read_data_o,

    input  logic                                data_req_write_i,
    input  logic                                data_req_write_enable_i,
    input  hpdcache_set_t                       data_req_write_set_i,
    input  hpdcache_req_size_t                  data_req_write_size_i,
    input  hpdcache_word_t                      data_req_write_word_i,
    input  hpdcache_req_data_t                  data_req_write_data_i,
    input  hpdcache_req_be_t                    data_req_write_be_i,

    input  logic                                data_amo_write_i,
    input  logic                                data_amo_write_enable_i,
    input  hpdcache_set_t                       data_amo_write_set_i,
    input  hpdcache_req_size_t                  data_amo_write_size_i,
    input  hpdcache_word_t                      data_amo_write_word_i,
    input  hpdcache_req_data_t                  data_amo_write_data_i,
    input  hpdcache_req_be_t                    data_amo_write_be_i,

    input  logic                                data_refill_i,
    input  hpdcache_way_vector_t                data_refill_way_i,
    input  hpdcache_set_t                       data_refill_set_i,
    input  hpdcache_word_t                      data_refill_word_i,
    input  hpdcache_refill_data_t               data_refill_data_i
    //      }}}
);

    typedef struct packed {
        bit            status;
        hpdcache_tag_t tag;        
    } hpdcache_tag_dir_t;

  bit [hpdcacheCfg.u.ways -1: 0]      m_bPLRU_table[hpdcacheCfg.u.sets];
  hpdcache_tag_dir_t             m_tag_dir[hpdcacheCfg.u.sets][hpdcacheCfg.u.ways];


  int                            idx, way, way1,idx0, idx1, idx2;
  hpdcache_set_t                 dir_match_set_q;
  hpdcache_set_t                 dir_amo_match_set_q;
  hpdcache_set_t                 dir_refill_set_q;
  hpdcache_tag_t                 dir_match_tag_q;

  always @(posedge clk_i or rst_ni) begin
    if(rst_ni == 0) begin
      dir_match_set_q       <=  0;
      dir_amo_match_set_q   <=  0;   
      dir_refill_set_q      <=  0;   
      dir_match_tag_q       <=  0;

    end else begin
      dir_match_set_q       <=  dir_match_set_i;   
      dir_amo_match_set_q   <=  dir_amo_match_set_i;   
      dir_refill_set_q      <=  dir_refill_set_i;      
      dir_match_tag_q       <=  dir_match_tag_i;
    end
  end

  // ----------------------------------------------------------
  // Inval 
  // --> invalidate the set and way 
  // --> do nothing to PLRU 
  // miss
  // check if for a give set there is an invalid way 
  // if invalid way found ...update tga dir et plru table 
  //  else check PLRU pour faire une eviction
  //  if needed, update PLRU 
  // ----------------------------------------------------------
   
  assign way = (dir_refill_i)? get_index_from_tag_dir(dir_refill_set_i, dir_refill_entry_i.tag): -1;
 // assign idx = (dir_refill_i)? cache_miss_get_way(dir_refill_set_i):-1;
  assign idx = (dir_refill_i)? get_index_from_plru(dir_refill_set_i, way): -1;
  always @(posedge clk_i or rst_ni) begin
    if(rst_ni == 0) begin
      for ( int s = 0 ; s < hpdcacheCfg.u.sets ; s++ ) begin
        for ( int w = 0 ; w < hpdcacheCfg.u.ways ; w++ ) begin 
          m_tag_dir[s][w].status = 1'b0; 
        end
      end

    end else if(dir_cmo_inval_i) begin 

      for ( int w = 0 ; w < hpdcacheCfg.u.ways ; w++ ) begin 
        if(dir_cmo_inval_way_i[w] == 1'b1) begin 
          m_tag_dir[dir_cmo_inval_set_i][w].status = 1'b0;
        end
      end
    end else if(dir_refill_i) begin // miss 
     if(way >= 0) begin // index found in the tag dir 
       m_tag_dir[dir_refill_set_i][way].status = 1'b1;
       m_tag_dir[dir_refill_set_i][way].tag    = dir_refill_entry_i.tag;
     end else begin // index found using PLRU 
       m_tag_dir[dir_refill_set_i][idx].status = 1'b1;
       m_tag_dir[dir_refill_set_i][idx].tag    = dir_refill_entry_i.tag;
     end
   end
  end

  // -------------------------------------------------
  // Hit 
  // --> update the PLRU 
  // --> 
  // miss
  // check if for a given set there is an invalid way 
  // if invalid way found ...update tga dir et plru table 
  //  else check PLRU pour faire une eviction
  //  if needed, update PLRU 
  // -------------------------------------------------
  assign idx0 = (dir_update_lru_i)       ? get_index_from_tag_dir_hit(dir_match_set_q, dir_match_tag_i): -1;
  assign idx1 = (dir_amo_update_plru_i)  ? get_index_from_tag_dir_hit(dir_amo_match_set_q, dir_amo_match_tag_i): -1;
  assign way1 = (dir_refill_updt_plru_i) ? get_index_from_tag_dir(dir_refill_set_i, dir_refill_entry_i.tag): -1;
  assign idx2 = (dir_refill_updt_plru_i) ? get_index_from_plru(dir_refill_set_i, way1) : -1;

  always @(posedge clk_i or rst_ni) begin
    if(~rst_ni) begin 
      for ( int s = 0 ; s < hpdcacheCfg.u.sets ; s++ ) begin
        for ( int w = 0 ; w < hpdcacheCfg.u.ways ; w++ ) begin 
          m_bPLRU_table[s][w] <= 0; 
        end
      end
    end else if(dir_update_lru_i) begin // hit 
      if(idx0 >= 0) begin // index from tag dir 
        if(($countones(m_bPLRU_table[dir_match_set_q]) == hpdcacheCfg.u.ways - 1) & (m_bPLRU_table[dir_match_set_q][idx0] == 1'b0)) begin 
          m_bPLRU_table[dir_match_set_q] <= 'h0;
        end
        m_bPLRU_table[dir_match_set_q][idx0] <= 1'b1; 
      end
    end else if(dir_amo_update_plru_i) begin // hit 
      if(idx1 >= 0) begin
        if(($countones(m_bPLRU_table[dir_amo_match_set_q]) == hpdcacheCfg.u.ways - 1) & (m_bPLRU_table[dir_amo_match_set_q][idx1] == 1'b0)) begin 
          m_bPLRU_table[dir_amo_match_set_q] <= 'h0;
        end
        m_bPLRU_table[dir_amo_match_set_q][idx1] <= 1'b1; 
      end
    end else if(dir_refill_updt_plru_i) begin // miss 
     // index from PLRU 
     if((m_bPLRU_table[dir_refill_set_i][idx2] == 1'b0) && ($countones(m_bPLRU_table[dir_refill_set_i]) == hpdcacheCfg.u.ways - 1)) begin 
       m_bPLRU_table[dir_refill_set_i]     <= 'h0;
     end
     m_bPLRU_table[dir_refill_set_i][idx2] <= 1'b1; 
    end
  end

  // ------------------------------------------------------------
  // CACHE HIT: update PLRU 
  // CACHE MISS: Updat PLRU And get the index 
  // ------------------------------------------------------------
  function void cache_hit_update_bPLRU(hpdcache_set_t set, int index);
     if(($countones(m_bPLRU_table[set]) == hpdcacheCfg.u.ways - 1) & (m_bPLRU_table[set][index] == 1'b0)) begin 
       m_bPLRU_table[set] = 'h0;
     end
     m_bPLRU_table[set][index] = 1'b1; 
   //  `uvm_info("SB PLRU UPDATE", $sformatf("PLRU %0x(x) %0d(d)", m_bPLRU_table[set], index), UVM_HIGH );
  endfunction

  function int cache_miss_get_way(hpdcache_set_t set);
     int index;
     index = -1;
     for (int way = 0; way < hpdcacheCfg.u.ways; way++) begin
       if(m_bPLRU_table[set][way] == 1'b0)  begin 
         index = way;
         break;
       end
     end

     `uvm_info("SB PLRU UPDATE", $sformatf("PLRU index %0d(d)", index), UVM_HIGH );
     return index;
  endfunction

  function int get_index_from_plru(hpdcache_set_t set, int idx);
     int index;
     index = -1;

     if(idx < 0) begin
       for (int way = 0; way < hpdcacheCfg.u.ways; way++) begin
         if(m_bPLRU_table[set][way] == 1'b0)  begin 
           index = way;
           break;
         end
       end
     end else begin
       index = idx;
     end

  //   `uvm_info("SB PLRU UPDATE", $sformatf("PLRU %0x(x)", m_bPLRU_table[set]), UVM_HIGH );
     return index; 
  endfunction

  function int get_index_from_tag_dir_hit(hpdcache_set_t set, hpdcache_tag_t tag);
    int index; 

    index = -1; 
    for (int way = 0; way < hpdcacheCfg.u.ways; way++) begin
//      `uvm_info("SB CACHE HIT PLRU SEARCH", $sformatf("status %s tag %0x(x) is a hit", m_tag_dir[set][way].status, m_tag_dir[set][way].tag), UVM_DEBUG );
      if((m_tag_dir[set][way].status == 1'b1) & (m_tag_dir[set][way].tag == tag)) begin 
        index = way;
        `uvm_info("SB CACHE HIT PLRU SEARCH", $sformatf("status %d(d) set %0d(d) tag %0x(x) index %0d(d)", m_tag_dir[set][index].status, set, m_tag_dir[set][index].tag, index), UVM_DEBUG );

        break;
      end
    end
    return index; 
  endfunction

  function int get_index_from_tag_dir(hpdcache_set_t set, hpdcache_tag_t tag);
    int index; 

    index = -1; 
    for (int way = 0; way < hpdcacheCfg.u.ways; way++) begin
      if((m_tag_dir[set][way].status == 1'b1) & (m_tag_dir[set][way].tag == tag)) begin 
        index = way;
        break;
      end
    end
    if(index < 0) begin
      for (int way = 0; way < hpdcacheCfg.u.ways; way++) begin
        if((m_tag_dir[set][way].status == 1'b0)) begin 
          index = way;
          break;
        end
      end
    end
    return index; 
  endfunction

endmodule
