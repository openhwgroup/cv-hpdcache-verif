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
//  Description : Package containing all the covergroup of the hpdcache agent
//                package
// ----------------------------------------------------------------------------

// -----------------------------------------------------------------------
// hpdcache covergroups
// -----------------------------------------------------------------------

// hpdcache req coverage
covergroup hpdcache_req_cg (ref hpdcache_req_mon_t packet);
  type_option.merge_instances = 1;
  option.get_inst_coverage    = 1;
  option.per_instance         = 1;
  cov_addr: coverpoint packet.addr
  { 
    bins zero    = {'h0};
    bins all[16] = {['h1:{HPDCACHE_PA_WIDTH{1'b1}}-1 ]};
    bins one     = {{HPDCACHE_PA_WIDTH{1'b1}}};
  }
  cov_wdata: coverpoint packet.wdata
  { 
    bins zero    = {'h0};
    bins all[16] = {['h1:{HPDCACHE_REQ_DATA_WIDTH{1'b1}}-1 ]};
    bins one     = {{HPDCACHE_REQ_DATA_WIDTH{1'b1}}};
 }
  cov_op: coverpoint packet.op
  { 
    bins op_load       = {HPDCACHE_REQ_LOAD    };
    bins op_store      = {HPDCACHE_REQ_STORE   };
   // bins op_reserved_2 = {// RESERVED        };
   // bins op_reserved_3 = {// RESERVED        };
    bins op_amo_lr     = {HPDCACHE_REQ_AMO_LR  };
    bins op_amo_sc     = {HPDCACHE_REQ_AMO_SC  };
    bins op_amo_swap   = {HPDCACHE_REQ_AMO_SWAP};
    bins op_amo_add    = {HPDCACHE_REQ_AMO_ADD };
    bins op_amo_and    = {HPDCACHE_REQ_AMO_AND };
    bins op_amo_or     = {HPDCACHE_REQ_AMO_OR  };
    bins op_amo_xor    = {HPDCACHE_REQ_AMO_XOR };
    bins op_amo_max    = {HPDCACHE_REQ_AMO_MAX };
    bins op_amo_maxu   = {HPDCACHE_REQ_AMO_MAXU};
    bins op_amo_min    = {HPDCACHE_REQ_AMO_MIN };
    bins op_amo_minu   = {HPDCACHE_REQ_AMO_MINU};
    bins op_cmo        = {HPDCACHE_REQ_CMO     };
  }
  cov_be: coverpoint packet.be
  { 
    bins zero   = {'h0};
    bins all[8] = {['h1:{HPDCACHE_REQ_DATA_WIDTH/8{1'b1}}-1 ]};
    bins one    = {{HPDCACHE_REQ_DATA_WIDTH/8{1'b1}}};
  }
  cov_size: coverpoint packet.size
  { 
    bins size_0 = {'h0};
    bins size_1 = {'h1};
    bins size_2 = {'h2};
    bins size_3 = {'h3};
    bins size_4 = {'h4};
    bins size_5 = {'h5};
    bins size_6 = {'h6};
    bins size_7 = {'h7};
  }
  cov_uncacheable: coverpoint packet.pma.uncacheable
  { 
    bins cacheable   = {'h0};
    bins uncachealbe = {'h1};
  }
  cov_sid: coverpoint packet.sid
  { 
    bins all[] = {['h0:{HPDCACHE_REQ_SRC_ID_WIDTH{1'b1}}]};
  }
  cov_tid: coverpoint packet.tid
  { 
    bins all[] = {['h0:{HPDCACHE_REQ_TRANS_ID_WIDTH{1'b1}}]};
  }
  cov_need_rsp: coverpoint packet.need_rsp
  { 
    bins no_rsp = {'h0};
    bins rsp    = {'h1};
  }
  cov_cmo_type : cross cov_op, cov_size
  {
    bins cmo_fence           = binsof(cov_op.op_cmo) && binsof(cov_size.size_0);
    bins cmo_dinval          = binsof(cov_op.op_cmo) && binsof(cov_size.size_1);
    // bins cmo_reserved_2      = binsof(cov_op.op_cmo) && binsof(cov_size.size_2);
    // bins cmo_reserved_3      = binsof(cov_op.op_cmo) && binsof(cov_size.size_3);
    bins cmo_prefetch_sw     = binsof(cov_op.op_cmo) && binsof(cov_size.size_4);
    bins cmo_prefetch_hw     = binsof(cov_op.op_cmo) && binsof(cov_size.size_5);
    bins cmo_prefetch_sw_slc = binsof(cov_op.op_cmo) && binsof(cov_size.size_6);
    bins cmo_prefetch_hw_slc = binsof(cov_op.op_cmo) && binsof(cov_size.size_7);
  }

  cov_set : coverpoint hpdcache_get_req_addr_set(packet.addr)
  {
    bins all_set[] = {[0: HPDCACHE_SETS -1]};
  }
  cov_word : coverpoint hpdcache_get_req_addr_word(packet.addr);

  cov_cross_op_need_rsp    : cross cov_need_rsp, cov_op;
  cov_cross_op_uncacheable : cross cov_uncacheable, cov_op; 
  cov_cross_op_set : cross cov_set, cov_op; 
  cov_cross_op_word : cross cov_word, cov_op; 

  cov_cross_op_set_size : cross cov_set, cov_size, cov_op; 
  cov_cross_op_set_word : cross cov_set, cov_word, cov_op; 

endgroup: hpdcache_req_cg

// hpdcache rsp coverage
covergroup hpdcache_rsp_cg (ref hpdcache_rsp_t packet);
  type_option.merge_instances = 1;
  option.get_inst_coverage = 1;
  option.per_instance = 1;
  cov_rdata: coverpoint packet.rdata
  { 
    bins zero    = {'h0};
    bins all[16] = {['h1:{HPDCACHE_REQ_DATA_WIDTH{1'b1}}-1 ]};
    bins one     = {{HPDCACHE_REQ_DATA_WIDTH{1'b1}}};
  }
  cov_sid: coverpoint packet.sid
  { 
    bins all[] = {['h0:{HPDCACHE_REQ_SRC_ID_WIDTH{1'b1}}]};
  }
  cov_tid: coverpoint packet.tid
  { 
    bins all[] = {['h0:{HPDCACHE_REQ_TRANS_ID_WIDTH{1'b1}}]};
  }
  cov_error: coverpoint packet.error
  { 
    bins no_error = {'h0};
    bins error    = {'h1};
  }
endgroup : hpdcache_rsp_cg 
