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


//-------------------------------------------------------
// Store req to predict the merge
//-------------------------------------------------------
if(is_store(req.op)) begin 
  m_hpdcache_store_cnt[set][tag]++; 
  `uvm_info("DEBUG CNT HPDCACHE STORE REQ", $sformatf("mem cnt %0d(d) req cnt %0d(d)", m_mem_write_cnt, m_hpdcache_store_cnt[set][tag]), UVM_DEBUG);
  if(req.pma.uncacheable == 1) begin
    m_hpdcache_req_uncached.push_back(req);
  end
end
// ===================================================
// UPDATE MEMORY SHADOW : LOAD/STORE/CMOs ( this is not hpdcache
// shadow)
// -------------------------------------------
// Update Memory Shadow in case of LOAD STORE
// In the case of LOAD: 
// Retreive the data from shadow memory m_memory
// In the case of STORE: 
// Update memory m_memory
// ----------------------------------------------------------------

`uvm_info("SB HPDCACHE REQ DEBUG", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x)", addr, set, tag), UVM_DEBUG);
case (req.op)
  HPDCACHE_REQ_LOAD   : 
  begin 
    create_and_init_memory_node(addr, HPDCACHE_MEM_LOAD_NUM);
    if(req.need_rsp == 1) m_load_data[set][tag].push_back(m_memory[addr].data);
    if(req.pma.uncacheable == 0) cnt_read_req++;
  end
  HPDCACHE_REQ_CMO   : 
  begin 
    case ( req.size )
      // case 0, 1 is treated saparetly 
      HPDCACHE_REQ_CMO_FENCE:  
      begin
        cnt_cmo_req++;
        `uvm_info("SB HPDCACHE CMO FENCE", $sformatf("SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", set, tag, offset), UVM_MEDIUM);
      end
      HPDCACHE_REQ_CMO_INVAL_NLINE: 
      begin 
        cnt_cmo_req++; 
        `uvm_info("SB HPDCACHE CMO INVALID", $sformatf("SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", set, tag, offset), UVM_MEDIUM);
      end
      HPDCACHE_REQ_CMO_INVAL_SET_WAY: 
      begin 
        cnt_cmo_req++; 
        `uvm_info("SB HPDCACHE CMO INVAL SET WAY", $sformatf("SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", set, tag, offset), UVM_MEDIUM);
      end
      HPDCACHE_REQ_CMO_INVAL_ALL: 
      begin 
        cnt_cmo_req++; 
        `uvm_info("SB HPDCACHE CMO INVAL ALL", $sformatf("SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", set, tag, offset), UVM_MEDIUM);
      end
      HPDCACHE_REQ_CMO_PREFETCH: 
      begin 
        if (req.pma.uncacheable == 0) begin
         // FIXME: for the moment RTL is behaving that way 
         if(req.size == HPDCACHE_REQ_CMO_PREFETCH) cnt_read_req++;

         // This sends a read miss request on the meme interface
         cnt_pref_req++; 
         create_and_init_memory_node(addr, HPDCACHE_MEM_LOAD_NUM);
         `uvm_info("SB HPDCACHE CMO", $sformatf("SET=%0d(d), TAG=%0x(x)  Offset=%0d(d) DATA=%0x(x)", set, tag, offset, m_memory[addr].data), UVM_MEDIUM);
        end else begin
         cnt_pref_err_req++; 
        end
      end
    endcase
  end
  HPDCACHE_REQ_STORE: 
  begin
    create_and_init_memory_node(addr, HPDCACHE_MEM_LOAD_NUM);
    foreach ( req.be[i,j] ) begin
      if ( req.be[i][j]) m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = req.wdata[i][j*8 +: 8];
    end
    `uvm_info("SB HPDCACHE STORE", $sformatf("SET=%0d(d), TAG=%0x(x) WORD=%0d(d) Offset=%0d(d) DATA=%0x(x)", set, tag, word, offset, m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  +: HPDCACHE_REQ_DATA_WIDTH]), UVM_MEDIUM);
    if(req.pma.uncacheable == 0) cnt_write_req++;
  end
endcase
