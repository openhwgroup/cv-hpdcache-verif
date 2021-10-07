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

import hpdcache_pkg::*;
import hpdcache_common_pkg::*;
interface hpdcache_if (input bit clk_i, input bit rst_ni);

  //  Ports
  //      Force the write buffer to send all pending writes
  logic                          wbuf_flush_i;

  //      Core request interface
  logic                          core_req_valid_i;
  logic                          core_req_ready_o;
  hpdcache_req_t                 core_req_i;

  logic                          core_req_abort_i;
  hpdcache_tag_t                 core_req_tag_i  ;
  hpdcache_pma_t                 core_req_pma_i  ;
  
  // ------------------------------------------------------------------------
  // Delay Task
  // ------------------------------------------------------------------------
  task wait_n_clocks( int N );          // pragma tbx xtf
    begin
      if( N > 0) begin
        @(posedge clk_i);
        repeat (N-1) @( posedge clk_i );
      end
    end
  endtask : wait_n_clocks

  /* pragma translate_off */
  core_req_valid_assert       : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( core_req_valid_i ) );
  core_req_ready_assert       : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( core_req_ready_o ) );

  core_req_addr_assert        : assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i ) -> !$isunknown( core_req_i.addr_offset        ) );
  core_req_wdata_assert       : assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i ) -> !$isunknown( core_req_i.wdata       ) );
  core_req_op_assert          : assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i ) -> !$isunknown( core_req_i.op          ) );
  core_req_be_assert          : assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i ) -> !$isunknown( core_req_i.be          ) );
  core_req_size_assert        : assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i ) -> !$isunknown( core_req_i.size        ) );
  core_req_uncacheable_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i ) -> !$isunknown( core_req_i.pma.uncacheable ) );
  core_req_sid_assert         : assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i ) -> !$isunknown( core_req_i.sid         ) );
  core_req_tid_assert         : assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i ) -> !$isunknown( core_req_i.tid         ) );
  core_req_need_rsp_assert    : assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_req_valid_i ) -> !$isunknown( core_req_i.need_rsp    ) );

  /* pragma translate_on */

  //      Core response interface
  logic                          core_rsp_valid_o;
  hpdcache_rsp_t                 core_rsp_o;

  /* pragma translate_off */
  core_rsp_valid_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni) !$isunknown( core_rsp_valid_o ) );

  // core_rsp_rdata_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_rsp_valid_o ) -> !$isunknown( core_rsp_o.rdata ) );
  core_rsp_sid_assert   : assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_rsp_valid_o ) -> !$isunknown( core_rsp_o.sid   ) );
  core_rsp_tid_assert   : assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_rsp_valid_o ) -> !$isunknown( core_rsp_o.tid   ) );
  core_rsp_error_assert : assert property ( @(posedge clk_i) disable iff(!rst_ni) ( core_rsp_valid_o ) -> !$isunknown( core_rsp_o.error ) );

  /* pragma translate_on */

endinterface
