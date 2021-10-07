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
//  Description : In this class we recieve transaction from the mem response model
//                The transaction is stored in a fifo and is driven to dram
// ----------------------------------------------------------------------------

class dram_mon_fifo extends uvm_component;

    `uvm_component_utils( dram_mon_fifo)

    // ------------------------------------------------------------------------
    // Local variable
    // ------------------------------------------------------------------------
    protected string name ;
    // ------------------------------------------------------------------------
    // Modules
    // -----------------------------------------------------------------------
    virtual dram_if dram_vif;
    
    // ------------------------------------------------------------------------
    // Memory configuration class 
    // Configures the back pressure on ready signal 
    // ------------------------------------------------------------------------
    dram_mon_cfg m_cfg; 

    // ------------------------------------------------------------------------
    // Queue to store upcoming transactions 
    // -----------------------------------------------------------------------
    mailbox #( hpdcache_mem_resp_r_t)   b_mem_miss_read_resp     = new(0);
    mailbox #( hpdcache_mem_resp_r_t)   b_mem_uc_read_resp       = new(0);
    mailbox #( hpdcache_mem_req_t)      b_mem_wbuf_write_req     = new(0);
    mailbox #( hpdcache_mem_req_w_t)    b_mem_wbuf_write_data    = new(0);
    mailbox #( hpdcache_mem_ext_req_t)  b_mem_wbuf_write_ext_req = new(0);
    mailbox #( hpdcache_mem_resp_w_t)   b_mem_wbuf_write_rsp     = new(0);
    mailbox #( hpdcache_mem_req_t)      b_mem_uc_write_req       = new(0);
    mailbox #( hpdcache_mem_req_w_t)    b_mem_uc_write_data      = new(0);
    mailbox #( hpdcache_mem_ext_req_t)  b_mem_uc_write_ext_req   = new(0);
    mailbox #( hpdcache_mem_resp_w_t)   b_mem_uc_write_rsp       = new(0);

    // ------------------------------------------------------------------------
    // queue to reconstuct the response for multiple mem responses 
    // -----------------------------------------------------------------------
    hpdcache_mem_write_ext_rsp_t        q_num_wbuf_write_req[integer];
    hpdcache_mem_write_ext_rsp_t        q_num_uc_write_req[integer];
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

        m_cfg = dram_mon_cfg::type_id::create("dram mon configuration", this);

    endfunction
    // ------------------------------------------------------------------------
    // Reset phase
    // ------------------------------------------------------------------------ 
    virtual task reset_phase(uvm_phase phase);
      super.reset_phase(phase);
      dram_vif.mem_resp_miss_read_valid_int_i  = 1'b0;
      dram_vif.mem_req_uc_write_valid_int_o    = 1'b0;
      dram_vif.mem_req_wbuf_write_valid_int_o  = 1'b0;

      dram_vif.mem_resp_uc_read_valid_int_i    = 0;
      `uvm_info(this.name, "Reset stage complete.", UVM_LOW)
    endtask

    virtual task configure_phase(uvm_phase phase);
       super.configure_phase(phase); 
       dram_vif.mem_req_miss_read_base_id_i  = HPDCACHE_MISS_READ_BASE_ID;
       dram_vif.mem_req_uc_read_base_id_i    = HPDCACHE_UC_READ_BASE_ID;
       dram_vif.mem_req_wbuf_write_base_id_i = HPDCACHE_WBUF_WRITE_BASE_ID;
       dram_vif.mem_req_uc_write_base_id_i   = HPDCACHE_UC_WRITE_BASE_ID;

      dram_vif.mem_req_wbuf_write_ready_i = 1'b1;
      dram_vif.mem_req_wbuf_write_data_ready_i = 1'b1;
      dram_vif.mem_req_uc_write_ready_i = 1'b1;
      dram_vif.mem_req_uc_write_data_ready_i = 1'b1;
       if (!m_cfg.randomize()) begin
         `uvm_error("End of elaboration", "Randomization failed");
       end
       dram_vif.mem_req_wbuf_write_ready_bp      = m_cfg.wbuf_write_ready_bp;
       dram_vif.mem_req_wbuf_write_data_ready_bp = m_cfg.wbuf_write_data_ready_bp;
       dram_vif.mem_req_uc_write_ready_bp        = m_cfg.uc_write_ready_bp;
       dram_vif.mem_req_uc_write_data_ready_bp   = m_cfg.uc_write_data_ready_bp;
    endtask

    // ----------------------------------------------------------------------- 
    // Main phase
    // ----------------------------------------------------------------------- 
    virtual task main_phase ( uvm_phase phase );

 
       // ----------------------------------------------------------------------------
       // push_dram_miss_read_fifo : new sequence item is created and new transaction 
       // ----------------------------------------------------------------------------
       fork 
         push_dram_miss_read_fifo(); 
         pop_dram_miss_read_fifo(); 
         push_dram_uc_read_fifo(); 
         pop_dram_uc_read_fifo(); 
         push_dram_wbuf_write_req_fifo(); 
         push_dram_wbuf_write_data_fifo(); 
         pop_dram_wbuf_write_req_data_fifo(); 
         pop_dram_wbuf_write_req_ext_fifo(); 
         push_dram_wbuf_write_resp_fifo(); 
         pop_dram_wbuf_write_resp_fifo(); 
         push_dram_uc_write_req_fifo(); 
         push_dram_uc_write_data_fifo(); 
         pop_dram_uc_write_req_data_fifo(); 
         pop_dram_uc_write_req_ext_fifo(); 
         push_dram_uc_write_resp_fifo(); 
         pop_dram_uc_write_resp_fifo(); 
       join_none

        super.main_phase(phase);
    endtask

    // ----------------------------------
    // get 
    // ----------------------------------
    virtual task push_dram_miss_read_fifo( );

       // Drive dram iterface
       forever begin

         if(dram_vif.mem_resp_miss_read_valid_i) begin
           b_mem_miss_read_resp.put(dram_vif.mem_resp_miss_read_i);
         end

         @ (posedge dram_vif.clk_i);

       end
    endtask

    // ----------------------------------
    // drive 
    // ----------------------------------
    virtual task pop_dram_miss_read_fifo( );
       hpdcache_mem_resp_r_t mem_miss_resp;

       // Drive dram iterface
       forever begin
         b_mem_miss_read_resp.get(mem_miss_resp);
         dram_vif.mem_resp_miss_read_int_i       = mem_miss_resp; 
         dram_vif.mem_resp_miss_read_valid_int_i = 1'b1;
   
         do begin
           @ (posedge dram_vif.clk_i);
         end while (dram_vif.mem_resp_miss_read_ready_o == 1'b0);

         dram_vif.mem_resp_miss_read_valid_int_i = 1'b0;

       end
    endtask

    // ----------------------------------
    // get 
    // ----------------------------------
    virtual task push_dram_uc_read_fifo( );

       // Drive dram iterface
       forever begin

         if(dram_vif.mem_resp_uc_read_valid_i) begin
           b_mem_uc_read_resp.put(dram_vif.mem_resp_uc_read_i);
         end
         @ (posedge dram_vif.clk_i);

       end
    endtask

    // ----------------------------------
    // drive 
    // ----------------------------------
    virtual task pop_dram_uc_read_fifo( );
       hpdcache_mem_resp_r_t mem_uc_read_resp;

       // Drive dram iterface
       forever begin
         b_mem_uc_read_resp.get(mem_uc_read_resp);
         dram_vif.mem_resp_uc_read_int_i       = mem_uc_read_resp; 
         dram_vif.mem_resp_uc_read_valid_int_i = 1'b1;
   
         do begin
           @ (posedge dram_vif.clk_i);
         end while (dram_vif.mem_resp_uc_read_ready_o == 1'b0);

         dram_vif.mem_resp_uc_read_valid_int_i = 1'b0;

       end
    endtask

    // ----------------------------------
    // put 
    // ----------------------------------
    virtual task push_dram_wbuf_write_req_fifo( );

       // Drive dram iterface
       forever begin

         if(dram_vif.mem_req_wbuf_write_ready_i && dram_vif.mem_req_wbuf_write_valid_o ) begin
           b_mem_wbuf_write_req.put(dram_vif.mem_req_wbuf_write_o);
         end
         @ (posedge dram_vif.clk_i);

       end
    endtask
    // ----------------------------------
    // put 
    // ----------------------------------
    virtual task push_dram_wbuf_write_data_fifo( );

       // Drive dram iterface
       forever begin

         if(dram_vif.mem_req_wbuf_write_data_ready_i && dram_vif.mem_req_wbuf_write_data_valid_o ) begin
           b_mem_wbuf_write_data.put(dram_vif.mem_req_wbuf_write_data_o);
         end
         @ (posedge dram_vif.clk_i);

       end
    endtask
    // --------------------------------------------------------
    // get
    // Get write request and get corresponding data 
    // create extended mem request to be sent to the mem model
    // --------------------------------------------------------
    virtual task pop_dram_wbuf_write_req_data_fifo( );
       hpdcache_mem_req_t     req;
       hpdcache_mem_req_w_t   wreq;
       hpdcache_mem_ext_req_t ext_req;
       int                  cnt;
       // Drive dram iterface
       forever begin

          // -------------------------------------
          // Get the write request 
          // -------------------------------------
          b_mem_wbuf_write_req.get(req);
          cnt = 0;

         // -------------------------------------
         // Look for the corresponding data
         // -------------------------------------
         do begin
            b_mem_wbuf_write_data.get(wreq);
            cnt++;
            ext_req.mem_req  = req; 
            ext_req.mem_data = wreq.mem_req_w_data;
            ext_req.mem_be   = wreq.mem_req_w_be;
            b_mem_wbuf_write_ext_req.put(ext_req);

         end while(wreq.mem_req_w_last == 0);

         // -------------------------------------
         // To reconstruct the response
         // -------------------------------------
         q_num_wbuf_write_req[req.mem_req_id].cnt       = cnt;
         q_num_wbuf_write_req[req.mem_req_id].is_atomic = 0;
         q_num_wbuf_write_req[req.mem_req_id].id        = req.mem_req_id;
       end
    endtask

    // --------------------------------------²------------------
    // get
    // Drive this to memory response model 
    // --------------------------------------------------------
    virtual task pop_dram_wbuf_write_req_ext_fifo( );
       hpdcache_mem_ext_req_t req;
       // Drive dram iterface
       dram_vif.mem_req_wbuf_write_valid_int_o = 1'b0;
       forever begin
         b_mem_wbuf_write_ext_req.get(req);
         dram_vif.mem_req_wbuf_write_int_o           = req; 
         dram_vif.mem_req_wbuf_write_valid_int_o     = 1'b1;
   
         do begin
           @ (posedge dram_vif.clk_i);
         end while (dram_vif.mem_req_wbuf_write_ready_int_i == 1'b0);
         dram_vif.mem_req_wbuf_write_valid_int_o = 1'b0;
       end
    endtask

    // --------------------------------------²------------------
    // put
    // Construct the response for the memory
    // --------------------------------------------------------
    virtual task push_dram_wbuf_write_resp_fifo( );
       // Drive dram iterface
       hpdcache_mem_resp_w_t        rsp;
       hpdcache_mem_resp_w_t        int_rsp;
       hpdcache_mem_write_ext_rsp_t ext_rsp;
       int                        cnt;
       forever begin
         cnt = 0; 
         if(dram_vif.mem_resp_wbuf_write_valid_int_i == 1) begin

           cnt++; 
           rsp     = dram_vif.mem_resp_wbuf_write_int_i; 
           ext_rsp = q_num_wbuf_write_req[rsp.mem_resp_w_id];
           int_rsp.mem_resp_w_error = rsp.mem_resp_w_error;

           if(cnt == ext_rsp.cnt) begin
             cnt = 0;
             int_rsp.mem_resp_w_is_atomic = ext_rsp.is_atomic; 
             int_rsp.mem_resp_w_id        = ext_rsp.id;
             b_mem_wbuf_write_rsp.put(int_rsp);
           end // if
         end // if
         @ (posedge dram_vif.clk_i);
       end
    endtask

    // --------------------------------------²------------------
    // get
    // 
    // --------------------------------------------------------
    virtual task pop_dram_wbuf_write_resp_fifo( );
       // Drive dram iterface
       hpdcache_mem_resp_w_t        rsp;
       hpdcache_mem_resp_w_t        int_rsp;
       hpdcache_mem_write_ext_rsp_t ext_rsp;
       forever begin
         b_mem_wbuf_write_rsp.get(int_rsp);
         dram_vif.mem_resp_wbuf_write_i        = int_rsp; 
         dram_vif.mem_resp_wbuf_write_valid_i  = 1'b1;
         do begin
           @ (posedge dram_vif.clk_i);
         end while (dram_vif.mem_resp_wbuf_write_ready_o == 1'b0);

         dram_vif.mem_resp_wbuf_write_valid_i  = 1'b0;

       end
    endtask

    // ----------------------------------
    // put 
    // ----------------------------------
    virtual task push_dram_uc_write_req_fifo( );

       // Drive dram iterface
       forever begin

         if(dram_vif.mem_req_uc_write_ready_i && dram_vif.mem_req_uc_write_valid_o ) begin
           b_mem_uc_write_req.put(dram_vif.mem_req_uc_write_o);
         end
         @ (posedge dram_vif.clk_i);

       end
    endtask
    // ----------------------------------
    // put 
    // ----------------------------------
    virtual task push_dram_uc_write_data_fifo( );

       // Drive dram iterface
       forever begin

         if(dram_vif.mem_req_uc_write_data_ready_i && dram_vif.mem_req_uc_write_data_valid_o ) begin
           b_mem_uc_write_data.put(dram_vif.mem_req_uc_write_data_o);
         end
         @ (posedge dram_vif.clk_i);

       end
    endtask
    // --------------------------------------------------------
    // get
    // Get write request and get corresponding data 
    // create extended mem request to be sent to the mem model
    // --------------------------------------------------------
    virtual task pop_dram_uc_write_req_data_fifo( );
       hpdcache_mem_req_t     req;
       hpdcache_mem_req_w_t   wreq;
       hpdcache_mem_ext_req_t ext_req;
       int                  cnt;
       // Drive dram iterface
       forever begin

          // -------------------------------------
          // Get the write request 
          // -------------------------------------
          b_mem_uc_write_req.get(req);
          cnt = 0;

         // -------------------------------------
         // Look for the corresponding data
         // -------------------------------------
         do begin
            b_mem_uc_write_data.get(wreq);
            cnt++;
            ext_req.mem_req  = req; 
            ext_req.mem_data = wreq.mem_req_w_data;
            ext_req.mem_be   = wreq.mem_req_w_be;
            b_mem_uc_write_ext_req.put(ext_req);

         end while(wreq.mem_req_w_last == 0);

         // -------------------------------------
         // To reconstruct the response
         // -------------------------------------
         q_num_uc_write_req[req.mem_req_id].cnt       = cnt;
         q_num_uc_write_req[req.mem_req_id].is_atomic = 0;
         q_num_uc_write_req[req.mem_req_id].id        = req.mem_req_id;
       end
    endtask

    // --------------------------------------²------------------
    // get
    // Drive this to memory response model 
    // --------------------------------------------------------
    virtual task pop_dram_uc_write_req_ext_fifo( );
       hpdcache_mem_ext_req_t req;
       // Drive dram iterface
       dram_vif.mem_req_uc_write_valid_int_o = 1'b0;
       forever begin
         b_mem_uc_write_ext_req.get(req);
         dram_vif.mem_req_uc_write_int_o           = req; 
         dram_vif.mem_req_uc_write_valid_int_o     = 1'b1;
   
         do begin
           @ (posedge dram_vif.clk_i);
         end while (dram_vif.mem_req_uc_write_ready_int_i == 1'b0);
         dram_vif.mem_req_uc_write_valid_int_o = 1'b0;
       end
    endtask

    // --------------------------------------²------------------
    // put
    // Construct the response for the memory
    // --------------------------------------------------------
    virtual task push_dram_uc_write_resp_fifo( );
       // Drive dram iterface
       hpdcache_mem_resp_w_t        rsp;
       hpdcache_mem_resp_w_t        int_rsp;
       hpdcache_mem_write_ext_rsp_t ext_rsp;
       int                        cnt;
       forever begin
         cnt = 0; 
         if(dram_vif.mem_resp_uc_write_valid_int_i == 1) begin

           cnt++; 
           rsp     = dram_vif.mem_resp_uc_write_int_i; 
           ext_rsp = q_num_uc_write_req[rsp.mem_resp_w_id];
           int_rsp.mem_resp_w_error = rsp.mem_resp_w_error;

           if(cnt == ext_rsp.cnt) begin
             cnt = 0;
             int_rsp.mem_resp_w_is_atomic = ext_rsp.is_atomic; 
	         //Ludo
	         if(dram_vif.mem_resp_uc_write_i.mem_resp_w_is_atomic == 1) begin
                 	int_rsp.mem_resp_w_is_atomic = 1; 	     
	         end
             int_rsp.mem_resp_w_id        = ext_rsp.id;
             b_mem_uc_write_rsp.put(int_rsp);
           end // if
         end // if
         @ (posedge dram_vif.clk_i);
       end
    endtask

    // --------------------------------------²------------------
    // get
    // 
    // --------------------------------------------------------
    virtual task pop_dram_uc_write_resp_fifo( );
       // Drive dram iterface
       hpdcache_mem_resp_w_t        rsp;
       hpdcache_mem_resp_w_t        int_rsp;
       hpdcache_mem_write_ext_rsp_t ext_rsp;
       forever begin
         b_mem_uc_write_rsp.get(int_rsp);
         dram_vif.mem_resp_uc_write_i        = int_rsp; 
         dram_vif.mem_resp_uc_write_valid_i  = 1'b1;
         do begin
           @ (posedge dram_vif.clk_i);
         end while (dram_vif.mem_resp_uc_write_ready_o == 1'b0);

         dram_vif.mem_resp_uc_write_valid_i  = 1'b0;

       end
    endtask


    // ----------------------------------
    // API to set the interface 
    // ----------------------------------
    function void set_dram_vif (virtual dram_if I);
        dram_vif = I;
    endfunction


endclass
