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
//  Description : Test base class that create the Dcache Driver
// ----------------------------------------------------------------------------

class hpdcache_driver extends uvm_driver # (hpdcache_txn);

    `uvm_component_utils( hpdcache_driver)

    // ------------------------------------------------------------------------
    // Local variable
    // ------------------------------------------------------------------------
    protected string name ;
    hpdcache_txn rsp_list[integer][$]; 

    // ------------------------------------------------------------------------
    // Modules
    // -----------------------------------------------------------------------
    virtual hpdcache_if hpdcache_vif;
    
    // ----------------------------------------------------------------------- 
    // Constructor
    // ----------------------------------------------------------------------- 
    function new( string name , uvm_component parent = null ); 
      super.new( name , parent);
      this.name = name;
    endfunction

    // ----------------------------------------------------------------------- 
    // Build phase
    // ----------------------------------------------------------------------- 
    virtual function void build_phase (uvm_phase phase);

        super.build_phase(phase);

    endfunction

    // ------------------------------------------------------------------------
    // Reset phase
    // ------------------------------------------------------------------------ 
    virtual task reset_phase(uvm_phase phase);
        super.reset_phase(phase);

       hpdcache_vif.core_req_valid_i            <= 0; 
       hpdcache_vif.core_req_i.addr_offset      <= 0;
       hpdcache_vif.core_req_i.addr_tag         <= 0;
       hpdcache_vif.core_req_i.wdata            <= 0;
       hpdcache_vif.core_req_i.op               <= HPDCACHE_REQ_LOAD;
       hpdcache_vif.core_req_i.be               <= 0;
       hpdcache_vif.core_req_i.size             <= 0;
       hpdcache_vif.core_req_i.sid              <= 0;
       hpdcache_vif.core_req_i.tid              <= 0;
       hpdcache_vif.core_req_i.need_rsp         <= 0;
       hpdcache_vif.wbuf_flush_i                <= 0;
       hpdcache_vif.core_req_i.phys_indexed     <= 0;

       // PMA 
       hpdcache_vif.core_req_i.pma.uncacheable  <= 0;
       hpdcache_vif.core_req_i.pma.io           <= 0;

        hpdcache_vif.core_req_abort_i           <= 0;
        hpdcache_vif.core_req_tag_i             <= 0;
        hpdcache_vif.core_req_pma_i.uncacheable   <= 0;
        hpdcache_vif.core_req_pma_i.io            <= 0;

        `uvm_info(this.name, "Reset stage complete.", UVM_LOW)
    endtask

    // ----------------------------------------------------------------------- 
    // Main phase
    // ----------------------------------------------------------------------- 
    virtual task main_phase ( uvm_phase phase );

        super.main_phase(phase);
 
       // ----------------------------------------------------------------------------
       // get_and_drive_req : new sequence item is created and new transaction 
       // ----------------------------------------------------------------------------
       fork 
         get_and_drive_req(); 
         spy_and_drive_rsp(); 
       join_none

    endtask

    // ----------------------------------
    // get and drive 
    // ----------------------------------
    virtual task get_and_drive_req( );
       // Drive hpdcache iterface
       forever begin
           seq_item_port.get_next_item(req);
           `uvm_info("HPDCACHE DRIVER", "New Request Recieved", UVM_HIGH);

//           @ (posedge hpdcache_vif.clk_i);

           if(req.m_txn_idle_cycles > 0)
             hpdcache_vif.wait_n_clocks(req.m_txn_idle_cycles);

           hpdcache_vif.core_req_valid_i           <=  1'b1;
           hpdcache_vif.core_req_i.addr_offset     <=  req.m_req_offset;
           hpdcache_vif.core_req_i.addr_tag        <=  req.m_req_tag;
           hpdcache_vif.core_req_i.wdata           <=  req.m_req_wdata;
           hpdcache_vif.core_req_i.op              <=  req.m_req_op;
           hpdcache_vif.core_req_i.be              <=  req.m_req_be;
           hpdcache_vif.core_req_i.size            <=  req.m_req_size;
           hpdcache_vif.core_req_i.sid             <=  req.m_req_sid;
           hpdcache_vif.core_req_i.tid             <=  req.m_req_tid;
           hpdcache_vif.core_req_i.need_rsp        <=  req.m_req_need_rsp;
           hpdcache_vif.core_req_i.phys_indexed    <=  req.m_req_phys_indexed;
           hpdcache_vif.core_req_i.pma.uncacheable <=  req.m_req_uncacheable;  
           hpdcache_vif.core_req_abort_i           <=  1'b0;

           // Wait for the request to be consumed
           do begin
             @(posedge hpdcache_vif.clk_i);
           end while (!hpdcache_vif.core_req_ready_o);
           hpdcache_vif.core_req_valid_i       <=  1'b0;
           hpdcache_vif.core_req_i.addr_offset <=  'hX; 
           hpdcache_vif.core_req_i.addr_tag    <=  'hX; 
           hpdcache_vif.core_req_i.wdata       <=  'hX;  
           hpdcache_vif.core_req_i.be          <=  'hX;  
           hpdcache_vif.core_req_i.size        <=  'hX;  
           hpdcache_vif.core_req_i.pma.uncacheable <=  'hX;  
           hpdcache_vif.core_req_i.sid         <=  'hX;  
           hpdcache_vif.core_req_i.tid         <=  'hX;  
           hpdcache_vif.core_req_i.need_rsp    <=  'hX;  
  
           // ------------------------------------------------------
           // This is to be used by respose handler
           // ------------------------------------------------------
           if(req.m_req_need_rsp) begin 
            // rsp_list[req.m_req_tid] = hpdcache_txn::type_id::create("driver response");
             rsp_list[req.m_req_tid].push_back(req);
           end

           if(req.m_req_phys_indexed == 0) begin
             hpdcache_vif.core_req_abort_i           <=  req.m_req_abort;
             hpdcache_vif.core_req_pma_i.uncacheable <=  req.m_req_uncacheable;
             hpdcache_vif.core_req_pma_i.io          <=  req.m_req_io;
             hpdcache_vif.core_req_tag_i             <=  req.m_req_tag;
             hpdcache_vif.core_req_i.phys_indexed    <=  req.m_req_phys_indexed;
             @(posedge hpdcache_vif.clk_i);
             seq_item_port.item_done();
           end else begin
             seq_item_port.item_done();
           end
           // If virtual addr, drive the rest of the address 

       end
    endtask

    // ----------------------------------
    // get and drive 
    // ----------------------------------
    virtual task spy_and_drive_rsp( );
       hpdcache_txn rsp;
       // Drive hpdcache iterface
       forever begin
           @ (posedge hpdcache_vif.clk_i);
           
           if(hpdcache_vif.core_rsp_valid_o) begin
             rsp = hpdcache_txn::type_id::create("new rsp");
             rsp.m_req_tid = hpdcache_vif.core_rsp_o.tid;
             rsp.m_req_sid = hpdcache_vif.core_rsp_o.sid;
             rsp.set_sequence_id(rsp_list[rsp.m_req_tid].pop_front().get_transaction_id);

             seq_item_port.put(rsp);
             `uvm_info("HPDCACHE DRIVER", "New Response Sent", UVM_HIGH);
           end
       end
    endtask
    // ------------------------------------------------------
    // API to set the interface 
    // ------------------------------------------------------
    function void set_hpdcache_vif (virtual hpdcache_if I);
        hpdcache_vif = I;
    endfunction
endclass
