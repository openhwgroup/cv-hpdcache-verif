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

module hpdcache_fxarb_sva
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    //    Number of requesters
    parameter int unsigned N = 0
)
    //  }}}
    //  Ports
    //  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  logic [N-1:0]          req_i,
    input  logic [N-1:0]          gnt_o,
    input  logic                  ready_i
);

 logic ready_ff;

 always @(posedge clk_i) begin 
   if (!rst_ni) begin
     ready_ff <= 0;
   end else begin
     ready_ff <= ready_i;
   end
 end
    
 always @(posedge clk_i) begin 
    for (int i=0; i< N-1; i++) begin 
       if (req_i[i] & ready_ff) 
          begin 
            assert(gnt_o[i]==1'b1 && $onehot(gnt_o)); // immediate assertion 
            break; 
          end 
    end 
  end 

  ap_zero_req: assert property(@(posedge clk_i) disable iff(!rst_ni) req_i==0 |-> gnt_o==0);

  gnt_at_most_one_requester: assert property (@(posedge clk_i) disable iff(!rst_ni)
          $onehot0(gnt_o)) else $error("arbiter: granting more than one requester");

  arbiter_work_conserving: assert property (@(posedge clk_i) disable iff(!rst_ni)
          (req_i > 0) |-> (gnt_o > 0)) else $error("arbiter: is not work conserving");

endmodule

