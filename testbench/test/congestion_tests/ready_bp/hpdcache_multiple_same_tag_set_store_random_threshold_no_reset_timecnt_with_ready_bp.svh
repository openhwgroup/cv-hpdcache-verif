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

`ifndef __test_hpdcache_multiple_same_tag_set_store_random_threshold_no_reset_timecnt_with_ready_bp_SVH__
`define __test_hpdcache_multiple_same_tag_set_store_random_threshold_no_reset_timecnt_with_ready_bp_SVH__

class test_hpdcache_multiple_same_tag_set_store_random_threshold_no_reset_timecnt_with_ready_bp extends test_base;

  `uvm_component_utils(test_hpdcache_multiple_same_tag_set_store_random_threshold_no_reset_timecnt_with_ready_bp)
  hpdcache_same_tag_set_access_request_cached m_seq[NREQUESTERS-1];

    int num_expected_write = 0;
    int num_rtab_entry;
    int cnt;
  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    set_type_override_by_type(hpdcache_conf_txn::get_type(), hpdcache_conf_random_threshold_no_reset_timecnt::get_type());
    set_type_override_by_type(hpdcache_txn::get_type()     , hpdcache_zero_delay_cacheable_store_txn::get_type());
    set_type_override_by_type(hpdcache_top_cfg::get_type() , hpdcache_top_one_requester_congestion_cfg::get_type());
  endfunction: new

  function void start_of_simulation_phase(uvm_phase phase);

    super.start_of_simulation_phase(phase);
    
  endfunction 
  // -------------------------------------------------------------------------
  // Pre Main Phase
  // -------------------------------------------------------------------------
  virtual task pre_reset_phase(uvm_phase phase);
    super.pre_reset_phase(phase);

    // force NoC ready to 0
    m_read_bp_vif.force_bp_out(1'b1);
    m_write_req_bp_vif.force_bp_out(1'b1);
    m_write_data_bp_vif.force_bp_out(1'b1);
  endtask
  // -------------------------------------------------------------------------
  // Pre Main Phase
  // -------------------------------------------------------------------------
  virtual task pre_main_phase(uvm_phase phase);
    // Create new sequence
    cnt = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) : 
          (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) : 
          $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold -1);

    for (int i = 0; i < NREQUESTERS-1; i++) begin
      m_seq[i] = hpdcache_same_tag_set_access_request_cached::type_id::create($sformatf("seq_%0d", i));
      if(!$cast(base_sequence[i], m_seq[i])) `uvm_fatal("CAST FAILED", "cannot cast base seqence");
      m_seq[i].wr_cnt_per_itr = cnt; 
    end

    num_expected_write = 0;
    super.pre_main_phase(phase);

  endtask: pre_main_phase

  virtual task main_phase(uvm_phase phase);
    int set = 0;

 
    num_rtab_entry = ((env.m_hpdcache_conf.m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));
    if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // write at same addr is blocked if waw=1 and wbuf= sent 
      if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf
        // In case of 1 request goes to write buffer and cache can accept
        // a new request
        // in case of 2 1st request goes to write buffer and second in the
        // RTAB and cache can accept a new request
        // in the case of > 3, 1st request goes to write buffer and second in
        // the RTAB and third put the request on hold
        case (cnt) 
          1:num_expected_write = get_min(HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) + num_rtab_entry; 
          2:num_expected_write = num_rtab_entry*2; // 1 in write buffer 1 in RTAB until RTAB is full   
          default: num_expected_write = 1 + num_rtab_entry;
        endcase

      end else begin
         num_expected_write =  cnt*get_min(HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry; 
      end
    end else begin
      if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin
        num_expected_write = get_min(HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry;
      end else begin
        case(env.m_hpdcache_conf.m_cfg_wbuf_threshold) inside
          [0:1]: 
          begin
            num_expected_write = get_min(HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);
          end 
          default: 
          begin
            num_expected_write =  cnt*get_min(HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES); 
          end
        endcase
        num_expected_write =  num_expected_write + ((env.m_hpdcache_conf.m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES)); 
      end
    end
    
    fork 
    begin
      phase.raise_objection(this);
      vif.wait_n_clocks(get_min(HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)*(env.m_hpdcache_conf.m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES+HPDCACHE_SETS*10); 
      

      // Depending on the pipeline we can some transactions accepted
      if(((num_expected_write + 3) >  env.m_hpdcache_sb.get_req_counter()) && (env.m_hpdcache_sb.get_req_counter() >= num_expected_write))  begin
        `uvm_info("TEST", $sformatf("Number of requests  txn count per itr=%0d(d) recieved %0d(d), expected %0d(d), RTAB ENTRIES %0d(d) THRESHOLD %0d(d), SEQ WAW=%0d(d) COALESCING %0x(x)", 
                                                                             cnt, 
                                                                             env.m_hpdcache_sb.get_req_counter(),
                                                                             num_expected_write,
                                                                             num_rtab_entry, 
                                                                             env.m_hpdcache_conf.m_cfg_wbuf_threshold,
                                                                             env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw,
                                                                             env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing
                                                                             ), UVM_LOW);
      end else begin
        `uvm_error("TEST", $sformatf("Number of requests  txn count per itr=%0d(d) recieved %0d(d), expected %0d(d), RTAB ENTRIES %0d(d) THRESHOLD %0d(d), SEQ WAW=%0d(d) COALESCING %0x(x)", 
                                                                             cnt, 
                                                                             env.m_hpdcache_sb.get_req_counter(),
                                                                             num_expected_write,
                                                                             num_rtab_entry, 
                                                                             env.m_hpdcache_conf.m_cfg_wbuf_threshold,
                                                                             env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw,
                                                                             env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing
                                                                             ));
      end

      // release ready signal
      m_read_bp_vif.release_bp_out();
      m_write_req_bp_vif.release_bp_out();
      m_write_data_bp_vif.release_bp_out();

      phase.drop_objection(this);
    end
    join_none
    super.main_phase(phase);

  endtask

endclass: test_hpdcache_multiple_same_tag_set_store_random_threshold_no_reset_timecnt_with_ready_bp

`endif // __test_hpdcache_multiple_same_tag_set_store_random_threshold_no_reset_timecnt_with_ready_bp_SVH__
