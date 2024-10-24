/// ----------------------------------------------------------------------------
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
//  Description : DCache sequence lib
//              : It is advisable to drive every sequence from signle request/single request in region
// ----------------------------------------------------------------------------
class hpdcache_base_sequence extends uvm_sequence #(hpdcache_txn);


  `uvm_object_utils( hpdcache_base_sequence )

  hpdcache_sequencer  my_sequencer;

  int                     num_txn;
  int                     sid;
  int                     rsp_count; 
  hpdcache_tag_t          tag;
  hpdcache_req_offset_t   offset;
  hpdcache_req_addr_t     req_addr;

  int                     unique_set[HPDCACHE_SETS];

  memory_partitions_cfg    #(HPDCACHE_PA_WIDTH) m_hpdcache_partitions;
  hpdcache_txn            item;


  function new( string name = "base_data_txn_sequence" );
    super.new(name);

    if (!$value$plusargs("NB_TXNS=%d", num_txn )) begin
      num_txn = 10000;
    end // if
    `uvm_info( get_full_name(), $sformatf("NUM_TXN=%0d", num_txn), UVM_HIGH );

    use_response_handler(1);
  endfunction: new

  task pre_body();
    $cast(my_sequencer, get_sequencer());
    foreach(unique_set[i]) begin
      unique_set[i] = i;
    end
    unique_set.shuffle();

//    if( !my_sequencer.m_top_cfg.randomize()) begin
//      `uvm_error("End of elaboration", "Randomization of config failed");
//    end

    item                 = hpdcache_txn::type_id::create("dcach single request");

    
  //  item.m_write_policy = my_sequencer.m_top_cfg.m_write_policy;
  //  item.m_wt_tag_bits  = my_sequencer.m_top_cfg.m_wt_tag_bits ;
  //  item.m_wb_tag_bits  = my_sequencer.m_top_cfg.m_wb_tag_bits ;
  endtask: pre_body

  virtual task body( );
    super.body();
  endtask

  virtual task post_body( );
    super.post_body();
    `uvm_info("HPDCACHE SEQUENCE IS NOT EMPTY", $sformatf("ID list size %0d(d) is not empty",  my_sequencer.q_inflight_tid.size), UVM_HIGH);
      // Waiting for the reception of all responses in the case of id management
    wait( my_sequencer.q_inflight_tid.size == 0 );
    `uvm_info("HPDCACHE SEQUENCE IS EMPTY", $sformatf("ID list size %0d(d) is empty",  my_sequencer.q_inflight_tid.size), UVM_HIGH);
  endtask


  function void set_sid(int S);
    sid = S;
  endfunction

  // API needed for set address for directed sequences from the test or drived
  // sequences 
  function void set_addr(hpdcache_req_addr_t S);
    req_addr = S;
  endfunction 

  // The response_handler function serves to keep the sequence response FIFO empty
  function void response_handler(uvm_sequence_item response);
    rsp_count++;
    `uvm_info("HPDCACHE SEQUENCE BASE", $sformatf("Number of responses %0d(d)", rsp_count), UVM_HIGH);
  endfunction: response_handler

  // Task wait_id_list
  // If the id list if full 
  // --> it waits until an id is freed 
  virtual task wait_id_list( );
      int max_list_size;
      max_list_size = (2**HPDCACHE_REQ_TRANS_ID_WIDTH -1) ;

      while ( my_sequencer.q_inflight_tid.size >= max_list_size) begin
         `uvm_info("HPDCACHE SEQUENCE ID LIST FULL", $sformatf("ID list size %0d(d) is full, waiting for a slot to be free",  my_sequencer.q_inflight_tid.size), UVM_HIGH);
         #10;
      end 
  endtask: wait_id_list

  // Customized the finish item sequence from sequence base lib 
  // The task now waits for the ID to be free before moving into the next item 
  //
  virtual task finish_item (  uvm_sequence_item 	item,	  	
                              int 	set_priority	 = 	-1);

      super.finish_item(item, set_priority);
      wait_id_list();
  endtask
  

endclass: hpdcache_base_sequence

///////////////////////////////////////////////////////////
// Single Generic Sequence
//////////////////////////////////////////////////////////
class hpdcache_generic_request extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_generic_request );


  function new( string name = "single_txn_sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();

    // --------------------------------------------------------------------------------
    // to generate unique TID a list of tid in flight is passed on to the sequence
    // --------------------------------------------------------------------------------
    item.q_inflight_tid = my_sequencer.q_inflight_tid;
    // Start the item
    start_item( item );
    // Send the transction to the driver
    finish_item( item );

  endtask: body

endclass: hpdcache_generic_request


///////////////////////////////////////////////////////////
// Single Random Cache Access
//////////////////////////////////////////////////////////
class hpdcache_single_non_cmo_request extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_single_non_cmo_request );


  function new( string name = "single_txn_sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();


    // --------------------------------------------------------------------------------
    // to generate unique TID a list of tid in flight is passed on to the sequence
    // --------------------------------------------------------------------------------
    item.q_inflight_tid = my_sequencer.q_inflight_tid;

    // --------------------------------
    // Randomize transaction item
    // --------------------------------
    if ( !item.randomize() with { m_req_sid == sid ; 
                                  m_req_op inside {  HPDCACHE_REQ_LOAD                 ,
                                                     HPDCACHE_REQ_STORE                ,
                                                     HPDCACHE_REQ_AMO_LR               ,
                                                     HPDCACHE_REQ_AMO_SC               ,
                                                     HPDCACHE_REQ_AMO_SWAP             ,
                                                     HPDCACHE_REQ_AMO_ADD              ,
                                                     HPDCACHE_REQ_AMO_AND              ,
                                                     HPDCACHE_REQ_AMO_OR               ,
                                                     HPDCACHE_REQ_AMO_XOR              ,
                                                     HPDCACHE_REQ_AMO_MAX              ,
                                                     HPDCACHE_REQ_AMO_MAXU             ,
                                                     HPDCACHE_REQ_AMO_MIN              ,
                                                     HPDCACHE_REQ_AMO_MINU            }; } )
      `uvm_fatal("body","Randomization failed");

    // ----------------------------------------------------
    // Fix q_uncacheable value according to the tag
    // ----------------------------------------------------
    tag = hpdcache_get_req_addr_tag(item.m_req_addr);

    if ( !my_sequencer.q_uncacheable.exists(tag) ) my_sequencer.q_uncacheable[tag] = ($urandom_range(0, 100) > 5) ? 0: 1;
    item.m_req_uncacheable = my_sequencer.q_uncacheable[tag]; 
    // --------------------------------------------------------------------------------
    // It is used when the response is received from the driver
    // --------------------------------------------------------------------------------
    if ( item.m_req_need_rsp == 1 ) begin 
      my_sequencer.q_inflight_tid[item.m_req_tid] = item.m_req_tid;
    end

    start_item( item );
    finish_item( item );

  endtask: body

endclass: hpdcache_single_non_cmo_request
///////////////////////////////////////////////////////////
// Single Random Cache Access
//////////////////////////////////////////////////////////
class hpdcache_single_request extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_single_request );


  function new( string name = "single_txn_sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();


    // --------------------------------------------------------------------------------
    // to generate unique TID a list of tid in flight is passed on to the sequence
    // --------------------------------------------------------------------------------
    item.q_inflight_tid = my_sequencer.q_inflight_tid;

    // --------------------------------
    // Randomize transaction item
    // --------------------------------
    if ( !item.randomize() with { m_req_sid == sid ; } )
      `uvm_fatal("body","Randomization failed");

    // ----------------------------------------------------
    // Fix q_uncacheable value according to the tag
    // ----------------------------------------------------
    tag = hpdcache_get_req_addr_tag(item.m_req_addr);

    if ( !my_sequencer.q_uncacheable.exists(tag) ) my_sequencer.q_uncacheable[tag] = ($urandom_range(0, 100) > 5) ? 0: 1;
    item.m_req_uncacheable = my_sequencer.q_uncacheable[tag]; 
    // --------------------------------------------------------------------------------
    // It is used when the response is received from the driver
    // --------------------------------------------------------------------------------
    if ( item.m_req_need_rsp == 1 ) begin 
      my_sequencer.q_inflight_tid[item.m_req_tid] = item.m_req_tid;
    end

    start_item( item );
    finish_item( item );

  endtask: body

endclass: hpdcache_single_request

class hpdcache_single_request_cached extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_single_request_cached );


  function new( string name = "single_txn_sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();


    // --------------------------------------------------------------------------------
    // to generate unique TID a list of tid in flight is passed on to the sequence
    // --------------------------------------------------------------------------------
    item.q_inflight_tid = my_sequencer.q_inflight_tid;

    // --------------------------------
    // Randomize transaction item
    // --------------------------------
    if ( !item.randomize() with { m_req_sid == sid ; } )
      `uvm_fatal("body","Randomization failed");

    // ----------------------------------------------------
    // Fix q_uncacheable value according to the tag
    // ----------------------------------------------------
    tag = hpdcache_get_req_addr_tag(item.m_req_addr);

    item.m_req_uncacheable = 1'b0; 
    // --------------------------------------------------------------------------------
    // It is used when the response is received from the driver
    // --------------------------------------------------------------------------------
    if ( item.m_req_need_rsp == 1 ) begin 
      my_sequencer.q_inflight_tid[item.m_req_tid] = item.m_req_tid;
    end

    start_item( item );
    finish_item( item );

  endtask: body

endclass: hpdcache_single_request_cached

class hpdcache_single_request_mostly_cached extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_single_request_mostly_cached );


  function new( string name = "single_txn_sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();


    // --------------------------------------------------------------------------------
    // to generate unique TID a list of tid in flight is passed on to the sequence
    // --------------------------------------------------------------------------------
    item.q_inflight_tid = my_sequencer.q_inflight_tid;

    // --------------------------------
    // Randomize transaction item
    // --------------------------------
    if ( !item.randomize() with { m_req_sid == sid ; } )
      `uvm_fatal("body","Randomization failed");

    // ----------------------------------------------------
    // Fix q_uncacheable value according to the tag
    // ----------------------------------------------------
    tag = hpdcache_get_req_addr_tag(item.m_req_addr);

    if ( !my_sequencer.q_uncacheable.exists(tag) ) begin
      if($urandom_range(0, 30) == 15) my_sequencer.q_uncacheable[tag] = 1;
      else                            my_sequencer.q_uncacheable[tag] = 0;
      
    end

    item.m_req_uncacheable = my_sequencer.q_uncacheable[tag]; 

    // --------------------------------------------------------------------------------
    // It is used when the response is received from the driver
    // --------------------------------------------------------------------------------
    if ( item.m_req_need_rsp == 1 ) begin 
      my_sequencer.q_inflight_tid[item.m_req_tid] = item.m_req_tid;
    end

    start_item( item );
    finish_item( item );

  endtask: body

endclass: hpdcache_single_request_mostly_cached

class hpdcache_single_request_uncached extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_single_request_uncached );


  function new( string name = "single_txn_sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();


    // --------------------------------------------------------------------------------
    // to generate unique TID a list of tid in flight is passed on to the sequence
    // --------------------------------------------------------------------------------
    item.q_inflight_tid = my_sequencer.q_inflight_tid;

    // --------------------------------
    // Randomize transaction item
    // --------------------------------
    if ( !item.randomize() with { m_req_sid == sid ; } )
      `uvm_fatal("body","Randomization failed");

    // ----------------------------------------------------
    // Fix q_uncacheable value according to the tag
    // ----------------------------------------------------
    tag = hpdcache_get_req_addr_tag(item.m_req_addr);

    item.m_req_uncacheable = 1'b1; 
    // --------------------------------------------------------------------------------
    // It is used when the response is received from the driver
    // --------------------------------------------------------------------------------
    if ( item.m_req_need_rsp == 1 ) begin 
      my_sequencer.q_inflight_tid[item.m_req_tid] = item.m_req_tid;
    end

    start_item( item );
    finish_item( item );

  endtask: body

endclass: hpdcache_single_request_uncached
///////////////////////////////////////////////////////////
// Single cache access within a region
//////////////////////////////////////////////////////////
class hpdcache_single_request_in_region extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_single_request_in_region );

  static int        region;
  int               m_cacheable;

  function new( string name = "single_txn_sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();
    

    // --------------------------------------------------------------------------------
    // to generate unique TID a list of tid in flight is passed on to the sequence
    // --------------------------------------------------------------------------------
    item.q_inflight_tid = my_sequencer.q_inflight_tid;

    // ----------------------------------------------
    // Randomize transaction item with in a region
    // -----------------------------------------------
    req_addr   = m_hpdcache_partitions.get_addr_in_mem_region(region);

    `uvm_info("hpdcache_single_request_in_region", $sformatf("region %0d(d) addr %0x(x)", region, req_addr), UVM_DEBUG);
    // ----------------------------------------------------
    // Fix uncacheable value according to the tag
    // ----------------------------------------------------
    tag = hpdcache_get_req_addr_tag(req_addr);

    case( m_cacheable)
      0: // random 
      begin
        if ( !my_sequencer.q_uncacheable.exists(tag) ) begin 
          my_sequencer.q_uncacheable[tag] = ($urandom_range(0, 100) > 5) ? 0: 1;
        end
      end
      1:
      begin
        if ( !my_sequencer.q_uncacheable.exists(tag) ) begin 
          my_sequencer.q_uncacheable[tag] = 1;
        end
      end
      2:
      begin
        if ( !my_sequencer.q_uncacheable.exists(tag) ) begin 
          my_sequencer.q_uncacheable[tag] = 0;
        end
      end
    endcase 


    if ( !item.randomize() with {m_req_sid         == sid;
                                 m_req_addr        == req_addr;
                                 m_req_uncacheable == my_sequencer.q_uncacheable[tag];})
        `uvm_fatal("body","Randomization failed");


    // --------------------------------------------------------------------------------
    // It is used when the response is received from the driver
    // --------------------------------------------------------------------------------
    if ( item.m_req_need_rsp == 1 ) begin 
      my_sequencer.q_inflight_tid[item.m_req_tid] = item.m_req_tid;
    end

    start_item( item );
    finish_item( item );

  endtask: body

endclass: hpdcache_single_request_in_region

///////////////////////////////////////////////////////////
// Single Random Cache Access
//////////////////////////////////////////////////////////
class hpdcache_single_request_with_errors extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_single_request_with_errors );

  hpdcache_req_addr_t   saved_addr        = 0;
  hpdcache_req_size_t   saved_size        = 0;
  hpdcache_req_op_t     saved_op          = HPDCACHE_REQ_LOAD;
  logic               saved_uncacheable = 0;
  logic               saved_need_rsp    = 1;

  function new( string name = "single_txn_sequence" );
      super.new(name);
  endfunction: new

  virtual task body( );
    super.body();

    for ( int i = 0 ; i < 2 ; i++ ) begin

	    // --------------------------------------------------------------------------------
	    // to generate unique TID a list of tid in flight is passed on to the sequence
	    // --------------------------------------------------------------------------------
	    item.q_inflight_tid = my_sequencer.q_inflight_tid;

	    // --------------------------------
	    // Randomize transaction item
	    // --------------------------------
	    if ( i == 0 ) begin
	      if ( !item.randomize() with { m_req_sid      == sid;
	                                    //m_req_need_rsp == 1;
                                        m_req_op dist {HPDCACHE_REQ_STORE := 50, HPDCACHE_REQ_LOAD := 50};})
          `uvm_fatal("body","Randomization failed");

	      tag = hpdcache_get_req_addr_tag(item.m_req_addr);

	      if ( !my_sequencer.q_uncacheable.exists(tag) ) my_sequencer.q_uncacheable[tag] = ($urandom_range(0, 100) > 5) ? 0: 1;
	      item.m_req_uncacheable = my_sequencer.q_uncacheable[tag]; 

        if ( item.m_req_uncacheable == 0 ) item.m_req_size = 4;
        if ( item.m_req_uncacheable == 1 ) item.m_req_size = ($urandom_range(0, 100) > 5) ? 0: 1;

	    end else begin
	      if ( !item.randomize() with {m_req_sid         == sid;
                                     m_req_addr        == saved_addr;
                                     m_req_size        == saved_size;
                                     m_req_need_rsp    == saved_need_rsp;
                                     m_req_uncacheable == saved_uncacheable;
                                     m_req_op          == saved_op;})
          `uvm_fatal("body","Randomization failed");	 
	    end

	    // ----------------------------------------------------
	    // Align the address to the size
	    // ----------------------------------------------------
//	    item.set_addr_offset(item.m_req_size);

	    // --------------------------------------------------------------------------------
	    // It is used when the response is received from the driver
	    // --------------------------------------------------------------------------------
	    if ( item.m_req_need_rsp == 1 ) begin 
        my_sequencer.q_inflight_tid[item.m_req_tid] = item.m_req_tid;
	    end
		
	    saved_addr = item.m_req_addr;
	    saved_size = item.m_req_size;
	    saved_op = item.m_req_op;
	    saved_uncacheable = item.m_req_uncacheable;
	    saved_need_rsp = item.m_req_need_rsp;
	
	
	    start_item( item );
	    finish_item( item );
    end

  endtask: body

endclass: hpdcache_single_request_with_errors


///////////////////////////////////////////////////////////
// Single amo Random Cache Access
//////////////////////////////////////////////////////////
class hpdcache_single_lr_sc_request extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_single_lr_sc_request );

  
  hpdcache_req_addr_t saved_addr;
  hpdcache_req_addr_t random_addr;
  bit               uncacheable; 
  hpdcache_tag_t             saved_tag;
  hpdcache_req_offset_t      saved_offset;
  hpdcache_tag_t             random_tag;
  hpdcache_req_offset_t      random_offset;

  function new( string name = "single_amo_txn_sequence_1" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();

    saved_addr = {$random, $random};
    saved_offset = hpdcache_get_req_addr_offset(saved_addr);
    saved_tag    = hpdcache_get_req_addr_tag(saved_addr);

    // lots of cacheable 
    uncacheable = ($urandom_range(0, 100) > 5) ? 0: 1;
    for ( int i = 0 ; i < 10 ; i++ ) begin     

      // --------------------------------------------------------------------------------
      // to generate unique TID a list of tid in flight is passed on to the sequence
      // --------------------------------------------------------------------------------
      item.q_inflight_tid = my_sequencer.q_inflight_tid;

      random_addr     = {$random, $random};
      saved_addr[$clog2(HPDCACHE_PA_WIDTH) -1: 0] = random_addr[$clog2(HPDCACHE_PA_WIDTH) -1: 0];
      random_offset = hpdcache_get_req_addr_offset(random_addr);
      random_tag    = hpdcache_get_req_addr_tag(random_addr);


      if ( !item.randomize() with {
          m_req_sid          == sid;
          m_req_uncacheable  == uncacheable;
          m_req_offset dist { saved_offset := 90, random_offset := 10};
          m_req_tag    dist { saved_tag    := 90, random_tag    := 10};
          m_req_op     dist { HPDCACHE_REQ_AMO_LR := 40, HPDCACHE_REQ_AMO_SC := 40, 
                              HPDCACHE_REQ_LOAD     := 9,
                              HPDCACHE_REQ_CMO_FENCE             := 1,
                              HPDCACHE_REQ_CMO_PREFETCH          := 1,
                              HPDCACHE_REQ_CMO_INVAL_NLINE       := 1,
                              HPDCACHE_REQ_CMO_INVAL_ALL         := 1,
                              HPDCACHE_REQ_CMO_FLUSH_NLINE       := 1,
                              HPDCACHE_REQ_CMO_FLUSH_ALL         := 1,
                              HPDCACHE_REQ_CMO_FLUSH_INVAL_NLINE := 1,
                              HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL   := 1,
                              HPDCACHE_REQ_STORE    := 1,
                              HPDCACHE_REQ_AMO_SWAP := 1,
                              HPDCACHE_REQ_AMO_ADD  := 1,
                              HPDCACHE_REQ_AMO_AND  := 1,
                              HPDCACHE_REQ_AMO_OR   := 1,
                              HPDCACHE_REQ_AMO_XOR  := 1,
                              HPDCACHE_REQ_AMO_MAX  := 1,
                              HPDCACHE_REQ_AMO_MAXU := 1,
                              HPDCACHE_REQ_AMO_MIN  := 1,
                              HPDCACHE_REQ_AMO_MINU := 1

                             }; })
      `uvm_fatal("body","Randomization failed");	

      tag = hpdcache_get_req_addr_tag(item.m_req_addr);

     //   if ( !my_sequencer.q_uncacheable.exists(tag) ) my_sequencer.q_uncacheable[tag] = m_req_uncacheable;
     //   item.m_req_uncacheable = my_sequencer.q_uncacheable[tag]; 

      // --------------------------------------------------------------------------------
      // It is used when the response is received from the driver
      // --------------------------------------------------------------------------------
      if ( item.m_req_need_rsp == 1 ) begin 
        my_sequencer.q_inflight_tid[item.m_req_tid] = item.m_req_tid;
      end

      if(item.m_req_tag == saved_tag) item.m_wr_policy_hint = HPDCACHE_WR_POLICY_WT;	

      start_item( item );
      finish_item( item );
    end
  endtask: body

endclass: hpdcache_single_lr_sc_request

///////////////////////////////////////////////////////////
// Single cache access within a addresses
// In this sequence address is set by user
//////////////////////////////////////////////////////////
class hpdcache_single_directed_addr extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_single_directed_addr );

  int        m_cacheable;
  hpdcache_req_offset_t        offset;
  hpdcache_tag_t               tag;


  function new( string name = "single_txn_sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();


    // --------------------------------------------------------------------------------
    // to generate unique TID a list of tid in flight is passed on to the sequence
    // --------------------------------------------------------------------------------
    item.q_inflight_tid = my_sequencer.q_inflight_tid;

    // ----------------------------------------------------
    // Fix uncacheable value according to the tag
    // ----------------------------------------------------
//    tag = hpdcache_get_req_addr_tag(req_addr);

    case( m_cacheable)
      0: // random: lots of cacheable  
      begin
        if ( !my_sequencer.q_uncacheable.exists(tag) ) begin 
          my_sequencer.q_uncacheable[tag] = ($urandom_range(0, 100) > 5) ? 0: 1;
        end
      end
      1:
      begin
        if ( !my_sequencer.q_uncacheable.exists(tag) ) begin
          my_sequencer.q_uncacheable[tag] = 1;
        end
      end
      2:
      begin
        if ( !my_sequencer.q_uncacheable.exists(tag) ) begin 
          my_sequencer.q_uncacheable[tag] = 0;
        end
      end
    endcase 

//    offset[$clog2(HPDCACHE_REQ_DATA_WIDTH/8) -1:0] = $urandom_range(1, $clog2(HPDCACHE_REQ_DATA_WIDTH));
    if ( !item.randomize() with {m_req_sid         == sid;
                                 m_req_offset      == offset;
                                 m_req_tag         == tag;
                                 m_req_uncacheable == my_sequencer.q_uncacheable[tag];})
        `uvm_fatal("body","Randomization failed");


    // --------------------------------------------------------------------------------
    // It is used when the response is received from the driver
    // --------------------------------------------------------------------------------
    if ( item.m_req_need_rsp == 1 ) begin 
      my_sequencer.q_inflight_tid[item.m_req_tid] = item.m_req_tid;
    end

    start_item( item );
    finish_item( item );

  endtask: body

endclass: hpdcache_single_directed_addr


///////////////////////////////////////////////////////////
// Multiple Random Cacche Access
//////////////////////////////////////////////////////////
class hpdcache_multiple_random_requests extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_multiple_random_requests );

  hpdcache_single_request         s_request; 

  function new( string name = "multiple sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();

    for ( int i = 0 ; i < num_txn ; i++ ) begin
      s_request = hpdcache_single_request::type_id::create("dcach multiple request");
      s_request.set_sid(sid);
      s_request.start(my_sequencer, this);
    end

  endtask: body

  virtual task post_body();
    hpdcache_single_non_cmo_request s_non_cmo_req;

    super.post_body(); 

    // This request is sent to make sure the last CMO finishes correctly 
    //
    s_non_cmo_req = hpdcache_single_non_cmo_request::type_id::create("dcach multiple non cmo request");
    s_non_cmo_req.set_sid(sid);
    s_non_cmo_req.start(my_sequencer, this);
  endtask 
endclass: hpdcache_multiple_random_requests

class hpdcache_multiple_random_requests_cached extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_multiple_random_requests_cached );

  hpdcache_single_request_cached         s_request; 

  function new( string name = "multiple sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();

    for ( int i = 0 ; i < num_txn ; i++ ) begin
      s_request = hpdcache_single_request_cached::type_id::create("dcach multiple request");
      s_request.set_sid(sid);
      s_request.start(my_sequencer, this);
    end

  endtask: body

  virtual task post_body();
    hpdcache_single_non_cmo_request s_non_cmo_req;

    super.post_body(); 

    // This request is sent to make sure the last CMO finishes correctly 
    //
    s_non_cmo_req = hpdcache_single_non_cmo_request::type_id::create("dcach multiple non cmo request");
    s_non_cmo_req.set_sid(sid);
    s_non_cmo_req.start(my_sequencer, this);
  endtask 
endclass: hpdcache_multiple_random_requests_cached

class hpdcache_multiple_random_requests_mostly_cached extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_multiple_random_requests_mostly_cached );

  hpdcache_single_request_mostly_cached         s_request; 

  function new( string name = "multiple sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();

    for ( int i = 0 ; i < num_txn ; i++ ) begin
      s_request = hpdcache_single_request_mostly_cached::type_id::create("dcach multiple request");
      s_request.set_sid(sid);
      s_request.start(my_sequencer, this);
    end

  endtask: body

  virtual task post_body();
    hpdcache_single_non_cmo_request s_non_cmo_req;

    super.post_body(); 

    // This request is sent to make sure the last CMO finishes correctly 
    //
    s_non_cmo_req = hpdcache_single_non_cmo_request::type_id::create("dcach multiple non cmo request");
    s_non_cmo_req.set_sid(sid);
    s_non_cmo_req.start(my_sequencer, this);
  endtask 
endclass: hpdcache_multiple_random_requests_mostly_cached

class hpdcache_multiple_random_requests_uncached extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_multiple_random_requests_uncached );

  hpdcache_single_request_uncached         s_request; 

  function new( string name = "multiple sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();

    // Uncached request takes a lot of time
    for ( int i = 0 ; i < num_txn/2 ; i++ ) begin
      s_request = hpdcache_single_request_uncached::type_id::create("dcach multiple request");
      s_request.set_sid(sid);
      s_request.start(my_sequencer, this);
    end

  endtask: body

  virtual task post_body();
    hpdcache_single_non_cmo_request s_non_cmo_req;

    super.post_body(); 

    // This request is sent to make sure the last CMO finishes correctly 
    //
    s_non_cmo_req = hpdcache_single_non_cmo_request::type_id::create("dcach multiple non cmo request");
    s_non_cmo_req.set_sid(sid);
    s_non_cmo_req.start(my_sequencer, this);
  endtask 
endclass: hpdcache_multiple_random_requests_uncached
///////////////////////////////////////////////////////////
// Multiple Cacche Access with in the memory region
// In the test, type override can be used to select
// the kind of operation needed to be run
//////////////////////////////////////////////////////////
class hpdcache_multiple_transactions_in_region extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_multiple_transactions_in_region );

  int region;
  int cacheable;
  hpdcache_single_request_in_region s_request; 
  int n_txn; 
  function new( string name = "multiple sequence in region" );
    super.new(name);
  endfunction: new

  virtual task body( );

    super.body();

    cacheable = ($urandom_range(0, 100) > 5 ) ? 2:  // mostly cacheable 
                ($urandom_range(0, 100) > 95) ? 1: // very few uncacheable 
                0; //random 

    // if uncacheable
    // redue the number of transaction 
    n_txn = (cacheable == 1) ? num_txn/2: num_txn;

    for ( int r = 0 ; r < n_txn; r++ ) begin
      s_request = hpdcache_single_request_in_region::type_id::create("dcach multiple request");
      s_request.set_sid(sid);
      s_request.m_hpdcache_partitions = m_hpdcache_partitions;
      s_request.region      = m_hpdcache_partitions.get_mem_region(); 
      s_request.m_cacheable = cacheable;
      s_request.start(my_sequencer, this);
    end

  endtask: body

  virtual task post_body();
    hpdcache_single_non_cmo_request s_non_cmo_req;

    super.post_body(); 

    // This request is sent to make sure the last CMO finishes correctly 
    //
    s_non_cmo_req = hpdcache_single_non_cmo_request::type_id::create("dcach multiple non cmo request");
    s_non_cmo_req.set_sid(sid);
    s_non_cmo_req.start(my_sequencer, this);
  endtask 
endclass: hpdcache_multiple_transactions_in_region

//////////////////////////////////////////////////////////
// Multiple Cacche Access with in address range 
// In this test for the same SET, 5 (NWAY + 1) random TAGs 
// are generated at the beggining of the test 
// The aime to have as many eviction as possible 
//////////////////////////////////////////////////////////
class hpdcache_multiple_directed_consecutive_addr extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_multiple_directed_consecutive_addr );

  hpdcache_req_addr_t           req_addr_start;
  hpdcache_single_directed_addr s_request;

  hpdcache_set_t  set;

  function new( string name = "multiple sequence" );
      super.new(name);
  endfunction: new

  virtual task body( );
    super.body();


    for ( int r = 0 ; r < 100 ; r++ ) begin

      s_request          = hpdcache_single_directed_addr::type_id::create("dcach multiple request");
      s_request.req_addr = req_addr_start + r << 6;

      s_request.set_sid(sid);
      s_request.start(my_sequencer, this);
    end
  endtask: body

  virtual task post_body();
    hpdcache_single_non_cmo_request s_non_cmo_req;

    super.post_body(); 

    // This request is sent to make sure the last CMO finishes correctly 
    //
    s_non_cmo_req = hpdcache_single_non_cmo_request::type_id::create("dcach multiple non cmo request");
    s_non_cmo_req.set_sid(sid);
    s_non_cmo_req.start(my_sequencer, this);
  endtask 
endclass: hpdcache_multiple_directed_consecutive_addr
//////////////////////////////////////////////////////////
// Multiple Cacche Access with in address range 
// In this test for the same SET, 5 (NWAY + 1) random TAGs 
// are generated at the beggining of the test 
// The aime to have as many eviction as possible 
//////////////////////////////////////////////////////////
class hpdcache_multiple_directed_addr extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_multiple_directed_addr );

  static hpdcache_req_offset_t    req_offset_arr[HPDCACHE_WAYS+1];
  static hpdcache_tag_t           req_tag_arr[HPDCACHE_WAYS+1];
  hpdcache_single_directed_addr s_request;

  hpdcache_set_t  set;

  function new( string name = "multiple sequence in region" );
      super.new(name);
  endfunction: new

  virtual task body( );
    int index; 
    super.body();

    // Fix the set
    set = $urandom;

    // ---------------------
    // Randomize the tag
    // ---------------------
    foreach ( req_offset_arr[i] )  begin
      req_offset_arr[i] = $urandom;
      req_offset_arr[i][HPDCACHE_OFFSET_WIDTH +: HPDCACHE_SET_WIDTH] = set;
    end
    foreach ( req_tag_arr[i] )  begin
      req_tag_arr[i] = $urandom;
    end

    for ( int r = 0 ; r < num_txn ; r++ ) begin

      s_request          = hpdcache_single_directed_addr::type_id::create("dcach multiple request");
      index              = $urandom_range(0, HPDCACHE_WAYS);
      s_request.offset = req_offset_arr[index];
      s_request.tag    = req_tag_arr[index];
      s_request.m_cacheable = 2;

      s_request.set_sid(sid);
      s_request.start(my_sequencer, this);
    end
  endtask: body

  virtual task post_body();
    hpdcache_single_non_cmo_request s_non_cmo_req;

    super.post_body(); 

    // This request is sent to make sure the last CMO finishes correctly 
    //
    s_non_cmo_req = hpdcache_single_non_cmo_request::type_id::create("dcach multiple non cmo request");
    s_non_cmo_req.set_sid(sid);
    s_non_cmo_req.start(my_sequencer, this);
  endtask 
endclass: hpdcache_multiple_directed_addr

//////////////////////////////////////////////////////////
// Multiple Cacche Access with in address range
//////////////////////////////////////////////////////////
class hpdcache_multiple_same_directed_addr_multiple_cores extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_multiple_same_directed_addr_multiple_cores );

  hpdcache_req_addr_t           req_addr_arr[HPDCACHE_WAYS+1];
  hpdcache_single_directed_addr s_request;
  int                         region;
  hpdcache_set_t                set;
  int                         cacheable; 

  function new( string name = "multiple sequence in region" );
    super.new(name);
  endfunction: new

  virtual task body( );
    int index; 
    super.body();

    cacheable = ($urandom_range(0, 100) > 5) ? 2: // mostly cacheable 
                ($urandom_range(0, 100) > 5) ? 1: // uncacheable 
                0; //random 
    for ( int r = 0 ; r < num_txn ; r++ ) begin

      s_request          = hpdcache_single_directed_addr::type_id::create("dcach multiple request");
      index              = $urandom_range(0, 4);
      s_request.req_addr = req_addr_arr[index];
      s_request.m_cacheable = cacheable;

      s_request.set_sid(sid);

      s_request.start(my_sequencer, this);
    end
  endtask: body

  function void set_addr_arr(hpdcache_req_addr_t S[HPDCACHE_WAYS+1]);
    req_addr_arr = S;
  endfunction 

  virtual task post_body();
    hpdcache_single_non_cmo_request s_non_cmo_req;

    super.post_body(); 

    // This request is sent to make sure the last CMO finishes correctly 
    //
    s_non_cmo_req = hpdcache_single_non_cmo_request::type_id::create("dcach multiple non cmo request");
    s_non_cmo_req.set_sid(sid);
    s_non_cmo_req.start(my_sequencer, this);
  endtask 
endclass: hpdcache_multiple_same_directed_addr_multiple_cores

class hpdcache_multiple_amo_lr_sc_requests extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_multiple_amo_lr_sc_requests );

  hpdcache_single_lr_sc_request s_request;

  function new( string name = "hpdcache_multiple_amo_lr_sc_requests" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();

    for ( int i = 0 ; i < num_txn/10 ; i++ ) begin
      s_request = hpdcache_single_lr_sc_request::type_id::create("dcach amo request");
      s_request.set_sid(sid);
      s_request.start(my_sequencer, this);
     end
  endtask: body

  virtual task post_body();
    hpdcache_single_non_cmo_request s_non_cmo_req;

    super.post_body(); 

    // This request is sent to make sure the last CMO finishes correctly 
    //
    s_non_cmo_req = hpdcache_single_non_cmo_request::type_id::create("dcach multiple non cmo request");
    s_non_cmo_req.set_sid(sid);
    s_non_cmo_req.start(my_sequencer, this);
  endtask 
endclass: hpdcache_multiple_amo_lr_sc_requests

class hpdcache_consecutive_set_access_request_cached extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_consecutive_set_access_request_cached );

  hpdcache_set_t    set; 
  hpdcache_tag_t    tag;
  hpdcache_offset_t offset;

  function new( string name = "single_txn_sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();

    for(int i = 0; i < num_txn; i ++) begin

      // --------------------------------------------------------------------------------
      // to generate unique TID a list of tid in flight is passed on to the sequence
      // --------------------------------------------------------------------------------
      item.q_inflight_tid = my_sequencer.q_inflight_tid;

      // --------------------------------
      // Randomize transaction item
      // --------------------------------
      if ( !item.randomize() with { m_req_sid == sid ; } )
        `uvm_fatal("body","Randomization failed");

      set    = hpdcache_get_req_addr_set(item.m_req_addr);
      offset = hpdcache_get_req_addr_offset(item.m_req_addr);
      tag    = hpdcache_get_req_addr_tag(item.m_req_addr);

//      offset = $urandom_range(1, $clog2(HPDCACHE_REQ_DATA_WIDTH));
      if(i < HPDCACHE_SETS) begin
        set = unique_set[i]; 
        item.m_req_addr = {tag, set, offset};
      end
      // ----------------------------------------------------
      // Fix q_uncacheable value according to the tag
      // ----------------------------------------------------
      tag = hpdcache_get_req_addr_tag(item.m_req_addr);

      item.m_req_uncacheable = 1'b0; 
      // --------------------------------------------------------------------------------
      // It is used when the response is received from the driver
      // --------------------------------------------------------------------------------
      if ( item.m_req_need_rsp == 1 ) begin 
        my_sequencer.q_inflight_tid[item.m_req_tid] = item.m_req_tid;
      end

      start_item( item );
      finish_item( item );
    end
  endtask: body

endclass: hpdcache_consecutive_set_access_request_cached

class hpdcache_same_tag_set_access_request_cached extends  hpdcache_base_sequence;
  `uvm_object_utils( hpdcache_same_tag_set_access_request_cached );

  hpdcache_set_t      set; 
  hpdcache_tag_t      tag;
  hpdcache_offset_t   offset;
  hpdcache_req_addr_t req_addr;
  int                 wr_cnt_per_itr;

  function new( string name = "single_txn_sequence" );
    super.new(name);
  endfunction: new

  virtual task body( );
    super.body();

    for(int i = 0; i < HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES + 10; i ++) begin

      // --------------------------------------------------------------------------------
      // to generate unique TID a list of tid in flight is passed on to the sequence
      // --------------------------------------------------------------------------------
      item.q_inflight_tid = my_sequencer.q_inflight_tid;

      // --------------------------------
      // Randomize transaction item
      // --------------------------------
      if ( !item.randomize() with { m_req_sid == sid ; m_req_size   == 0; item.m_req_uncacheable == 1'b0;m_req_need_rsp == 0; m_req_phys_indexed == 1;})
        `uvm_fatal("body","Randomization failed");
      if(i < HPDCACHE_SETS) set = unique_set[i];
      else set    = hpdcache_get_req_addr_set(item.m_req_addr);

      offset = hpdcache_get_req_addr_offset(item.m_req_addr);
      tag    = hpdcache_get_req_addr_tag(item.m_req_addr);

      for(int j = 0; j < wr_cnt_per_itr ; j ++) begin

        offset = $urandom_range(1, HPDCACHE_REQ_DATA_WIDTH/8 -1);
        item.m_req_addr = {tag, set, offset};
        // ----------------------------------------------------
        // Fix q_uncacheable value according to the tag
        // ----------------------------------------------------
        tag = hpdcache_get_req_addr_tag(item.m_req_addr);

        item.m_req_tid         = j;
//        item.set_byte_enable(item.m_req_size, item.m_req_addr[3:0], item.m_req_op);
        // --------------------------------------------------------------------------------
        // It is used when the response is received from the driver
        // --------------------------------------------------------------------------------
        if ( item.m_req_need_rsp == 1 ) begin 
          my_sequencer.q_inflight_tid[item.m_req_tid] = item.m_req_tid;
        end

        start_item( item );
        finish_item( item );
      end
    end
  endtask: body

endclass: hpdcache_same_tag_set_access_request_cached

