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
//  Description : Scoreboard (amo (cached and uncahced), Uncached requests)
// ----------------------------------------------------------------------------



// =================================================== 
// ERROR BIT CHECK: AMOS 
// --------------------------------------------------
// Prediction of error for amos
// If m_cfg_error_on_cacheable_amo flag is set 
// And AMO request has uncacheable = 0, its an error
//
// Else AMO request is sent to atomic memory interface 
// --------------------------------------------------
// Performance counter 
if(req.pma.uncacheable == 1 && !(req.op == HPDCACHE_REQ_CMO)) cnt_uncached_req++;

if ( is_amo(req.op) ) begin
    // Performance counter 
    if(req.pma.uncacheable == 0) cnt_uncached_req++; 

    if (m_hpdcache_conf.m_cfg_error_on_cacheable_amo == 1) begin
      if(req.pma.uncacheable == 0) begin

        `uvm_info("SB HPDCACHE WRONG AMO", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x) Offset=%0d(d)", addr, set, tag, offset), UVM_FULL);
        m_error_amo[set][tag] = 1'b1;

      end else begin
        m_error_amo[set][tag] = 1'b0;
      end

    end else begin
      m_error_amo[set][tag] = 1'b0;
    end

end
// =================================================== 

// =================================================== 
// MEMORY REQUEST CHECK: UNCACHEABLE REQUESTS  
// ------------------------------------------------------
// Used to check the memory requests
// Valid AMO cacheable requests or uncacheable requests 
// are stored in the list m_hpdcache_req_uncached 
// And once the memory request is observed, the hpdcached request is
// poped from this list to verify the valid memory request.
// -----------------------------------------------------
if (is_amo(req.op)  && !is_amo_sc(req.op) && !(m_hpdcache_conf.m_cfg_error_on_cacheable_amo == 1 && req.pma.uncacheable == 0))  begin
  m_hpdcache_req_uncached.push_back(req);
end
// =================================================== 


// ===================================================
// --------------------------------------------------
// Get the aligned address
// Get the word at memory interface 
// --------------------------------------------------
addr   = req.addr;
offset = req.addr[HPDCACHE_OFFSET_WIDTH -1 :0];
addr[HPDCACHE_OFFSET_WIDTH -1 :0] = 0;
// =================================================== 

// =============================================================
// LR/SC CHECK
// -------------------------------------------------------------
// Reserve or Unreserve the byte as per LR/SC transaction
// -------------------------------------------------------------
  if(req.op == HPDCACHE_REQ_AMO_SC) begin
     m_sc_status[set][tag] = 1'b0;
     if( m_load_reservation.exists(addr)) begin 
       if(!check_lr_sc_reservation(addr, mem_be_res)) begin
         m_load_reservation.delete(addr);
         m_sc_status[set][tag] = 1'b1;
         `uvm_info("SB HPDCACHE FAIL SC", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", addr, set, tag, offset), UVM_FULL);
       end
     end else begin
       m_sc_status[set][tag] = 1'b1;
       foreach(m_load_reservation[i]) m_load_reservation.delete(i);
       `uvm_info("SB HPDCACHE FAIL SC", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", addr, set, tag, offset), UVM_FULL);
     end
  end
//  case(req.op)
//    // -------------------------------------------------------------
//    // Associative Array is used to store the word which is reserved 
//    // -------------------------------------------------------------
//  //  HPDCACHE_REQ_AMO_LR: begin
//  //    foreach(m_load_reservation[i]) m_load_reservation.delete(i);
//  //    m_load_reservation[addr] = (offset >> 3) << 3;
//  //    `uvm_info("SB HPDCACHE SET LR", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x) Offset=%0d(d)", addr, set, tag, offset), UVM_FULL);
//  //  end
//  //  HPDCACHE_REQ_LOAD: begin
//  //    // -------------------------------------------------------------
//  //    // Load does not change the lock status
//  //    // -------------------------------------------------------------
//  //    if( m_load_reservation.exists(addr)) begin
//  //     `uvm_info("SB HPDCACHE LR EXISTS", $sformatf("SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", set, tag, offset), UVM_FULL);
//  //    end
//  //  end
//  //  HPDCACHE_REQ_CMO: begin
//  //    // -------------------------------------------------------------
//  //    // Load does not change the lock status
//  //    // -------------------------------------------------------------
//  //    if( m_load_reservation.exists(addr)) begin
//  //     `uvm_info("SB HPDCACHE LR EXISTS", $sformatf("SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", set, tag, offset), UVM_FULL);
//  //    end
//  //  end
//   // default: begin
//   //   // -------------------------------------------------------------
//   //   // Any kind of store/amo(except LR/SC) at the same word address changes the lock
//   //   // status 
//   //   // -------------------------------------------------------------
//   //   if( m_load_reservation.exists(addr)) begin 
//   //     if (((m_load_reservation[addr] >= (offset >> 3) << 3) & (m_load_reservation[addr] <= (((offset >> 3) << 3)+2**req.size)))||
//   //        ((m_load_reservation[addr] + 8 >= (offset >> 3) << 3) & (m_load_reservation[addr] +8 <= (((offset >> 3) << 3)+2**req.size)))) begin
//   //       m_load_reservation.delete(addr);
//   //       `uvm_info("SB HPDCACHE UNSET LR", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", addr, set, tag, offset), UVM_FULL);
//   //     end else begin
//   //       `uvm_info("SB HPDCACHE NOT UNSET LR", $sformatf("ADDR=%0x(x) SET=%0d(d), TAG=%0x(x)  Offset=%0d(d)", addr, set, tag, offset), UVM_FULL);
//   //     end
//   //   end
//   // end
//  endcase
// end
// ===================================================
// UPDATE MEMORY SHADOW : AMOS 
// -------------------------------------------
// Update Memory Shadow in case of AMO 
// Only if flag on cacheable amo is not set
// -------------------------------------------
if(!(m_hpdcache_conf.m_cfg_error_on_cacheable_amo == 1 && req.pma.uncacheable == 0)) begin

  // --------------------------------------------------------------
  // Create/update memory node for AMOs 
  // For SC creation of a new memory node depends on the SC status
  // --------------------------------------------------------------
  if(!(req.op == HPDCACHE_REQ_AMO_SC || req.op == HPDCACHE_REQ_STORE || req.op == HPDCACHE_REQ_LOAD || req.op == HPDCACHE_REQ_CMO)) begin

    create_and_init_memory_node(addr, HPDCACHE_MEM_LOAD_NUM);
    if(req.need_rsp == 1) m_load_data[set][tag].push_back(m_memory[addr].data);
    `uvm_info("SB HPDCACHE BEFORE AMO", $sformatf("OP=%s,  SET=%0d(d), TAG=%0x(x)  Offset=%0d(d) READ=%0x(x)", req.op, set, tag, offset, m_memory[addr].data), UVM_MEDIUM);

  end

  // -------------------------------------
  // Create a word from the bytes
  // Data read from the memory
  // Data sent with the request
  // -------------------------------------
  req_data      = 'h0;
  mem_data      = 'h0;
  last_one_strb = 0;

  for(int i = 0; i < $size(req.be); i++) begin
    for(int j = 0; j < $size(req.be[i]); j++) begin
//  foreach (req.be[i,j] ) begin
      if ( req.be[i][j]) begin 
        if(m_memory.exists(addr))  mem_data[i*HPDCACHE_WORD_WIDTH + j*8 +: 8]   = m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH + j*8 + i*HPDCACHE_WORD_WIDTH +: 8]; 
                                   req_data[i*HPDCACHE_WORD_WIDTH + j*8 +: 8]   = req.wdata[i][j*8 +: 8];
        last_one_strb  = i*HPDCACHE_WORD_WIDTH + (j+ 1)*8;
      end
    end
  end

  // --------------------------------------------------
  // To get the sign of the data 
  // -------------------------------------------
//  last_one_strb = 2**req.size*8; //(req.addr[3:2] + 1)*(2**req.size)*8;
  case (req.op)
    HPDCACHE_REQ_AMO_LR :
    begin
      `uvm_info("SB HPDCACHE LR", $sformatf("SET=%0d(d), TAG=%0x(x)  Offset=%0d(d) DATA=%0x(x)", set, tag, offset, m_memory[addr].data), UVM_MEDIUM);
    end
    HPDCACHE_REQ_AMO_OR : 
    begin
      foreach ( req.be[i,j] ) begin
        if ( req.be[i][j]) m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = req.wdata[i][j*8 +: 8] | m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8];
      end
    end
    HPDCACHE_REQ_AMO_SWAP: 
    begin
      foreach ( req.be[i,j] ) begin
        if ( req.be[i][j]) m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = req.wdata[i][j*8 +: 8];
      end
    end
    HPDCACHE_REQ_AMO_AND : 
    begin
      foreach ( req.be[i,j] ) begin
        // data sent to the memory is ~data, because and -> CLR at
        // memory interface
        if ( req.be[i][j]) m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = req.wdata[i][j*8 +: 8] & m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8];
      end
    end
    HPDCACHE_REQ_AMO_XOR : 
    begin
      foreach ( req.be[i,j] ) begin
        if ( req.be[i][j]) m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = req.wdata[i][j*8 +: 8] ^ m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8];
      end
    end
    HPDCACHE_REQ_AMO_ADD : 
    begin
      carry = 0;
      for(int i = 0; i < 2; i++) begin
        for(int j = 0; j < 8; j++) begin

          if ( req.be[i][j]) {carry, m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8]} = adder(req.wdata[i][j*8 +: 8], m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8], carry);
        end
      end
    end
    HPDCACHE_REQ_AMO_MAX  :
    begin
      // ------------------------------------------------
      // Convert unsgined vector to signed vector 
      // ------------------------------------------------
      for(int i =last_one_strb; i < HPDCACHE_REQ_DATA_WIDTH; i++) begin
        mem_data[i]  = mem_data[last_one_strb -1];
        req_data[i]  = req_data[last_one_strb -1];
      end
      if($signed(req_data) > $signed(mem_data)) begin
        foreach ( req.be[i,j] ) begin
          if ( req.be[i][j]) m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = req.wdata[i][j*8 +: 8];
        end
      end
    end
    HPDCACHE_REQ_AMO_MAXU : 
    begin
      if(req_data > mem_data) begin
        foreach ( req.be[i,j] ) begin
          if ( req.be[i][j]) m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = req.wdata[i][j*8 +: 8];
        end
      end
    end
    HPDCACHE_REQ_AMO_MIN  : 
    begin
      // ------------------------------------------------
      // Convert unsgined vector to signed vector 
      // ------------------------------------------------
      for(int i = last_one_strb; i < HPDCACHE_REQ_DATA_WIDTH; i++) begin
        mem_data[i]  = mem_data[last_one_strb -1];
        req_data[i]  = req_data[last_one_strb -1];
      end
      `uvm_info("HPDCACHE_REQ_AMO_MIN", $sformatf("MEM DATA=%0x(x) REQ DATA=%0x(x)", mem_data, req_data), UVM_LOW);
      if($signed(req_data) < $signed(mem_data)) begin
        foreach ( req.be[i,j] ) begin
          if ( req.be[i][j]) m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = req.wdata[i][j*8 +: 8];
        end
      end
    end
    HPDCACHE_REQ_AMO_MINU : 
    begin
      if(req_data < mem_data) begin
        foreach ( req.be[i,j] ) begin
          if ( req.be[i][j]) m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = req.wdata[i][j*8 +: 8];
        end
      end
    end
    HPDCACHE_REQ_AMO_SC : 
    begin
      if(m_load_reservation.exists(addr) &&  check_lr_sc_reservation(addr, mem_be_res)) begin

        create_and_init_memory_node(addr);
        foreach ( req.be[i,j] ) begin
          if ( req.be[i][j]) m_memory[addr].data[(word)*HPDCACHE_REQ_DATA_WIDTH  + j*8+i*HPDCACHE_WORD_WIDTH +: 8] = req.wdata[i][j*8 +: 8];
        end

        // -------------------------------------------------------------
        // Unset the reservation
        // -------------------------------------------------------------
        m_load_reservation.delete(addr);
        `uvm_info("SB HPDCACHE SC PASS", $sformatf("SET=%0d(d), TAG=%0x(x)  Offset=%0d(d) DAta=%0x(x)", set, tag, offset, m_memory[addr].data), UVM_FULL);

        cov_sc_pass_word = word; 
        sc_pass_word_coverage.sample();

        m_hpdcache_req_uncached.push_back(req);
      end
    end
  endcase
  // ===================================================

  // 
  // Debug Message
  // -------------------------------------------------------------
  if(!(req.op == HPDCACHE_REQ_AMO_SC || req.op == HPDCACHE_REQ_STORE || req.op == HPDCACHE_REQ_LOAD || req.op == HPDCACHE_REQ_CMO)) begin

    `uvm_info("SB HPDCACHE AFTER AMO", $sformatf("SET=%0d(d), TAG=%0x(x)  Offset=%0d(d) READ=%0x(x)", set, tag, offset, m_memory[addr].data), UVM_MEDIUM);

  end
end
