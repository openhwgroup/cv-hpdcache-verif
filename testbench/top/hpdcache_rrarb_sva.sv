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

module hpdcache_rrarb_sva
#(
    //    Number of requesters
    parameter int unsigned N = 0
)
(
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  logic [N-1:0]          req_i,
    input  logic [N-1:0]          gnt_o,
    input  logic                  ready_i
);

    logic                  ready_q;
    logic                  int_r;
    logic                  ready;
    logic [N-1:0]          exp_gnt;
    logic [N-1:0]          exp_gnt_q;
    logic [N-1:0]          exp_gnt_int;
    logic [N-1:0]          req_q;
    logic [N-1:0]          mask_high;
    int                    prev_gnt_index;
    int                    exp_gnt_index;

    // Here are some characteristics of the arbiter 
    // 1. If there is no gnt (gnt == 0), arbiter give the grant as soon as
    // request arrives
    // 2. But if ready is zero, it will wait until the ready is 1. 
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if(~rst_ni) begin
        ready_q <= 0;
        req_q   <= 0;
        exp_gnt_q <= 0;
      end else begin
        ready_q <= ready_i;
        req_q   <= req_i;
        exp_gnt_q <= (req_i > 0) ? exp_gnt: exp_gnt_q;
      end
    end

    // An internal ready in the case where req = 0 
    // Arbiter shall give grant as soon as req = 1
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if(~rst_ni) begin
        int_r <= 0;
      end else begin
        if(req_i == 0) begin
          int_r <= 1;
        end else begin
          int_r <= 0;
        end
      end
    end

    assign ready = ready_q | int_r;

    // Get index from the last gant 
    always_comb begin
      if(ready_q == 1) begin
        prev_gnt_index = locate_first_one(exp_gnt_q);
      end else if (int_r == 1) begin
        prev_gnt_index = locate_first_one(exp_gnt_q);
      end
    end

    // Once gnt is give 
    // set all bits after grant bit to 1
    always_comb begin
      for(int i = 0; i < N; i++) begin
        mask_high[i] = (i +1 > prev_gnt_index) ? 1'b1 : 1'b0;
      end
    end

    // By ending mask with req_i we can get the first req bit (after gnt bit) 
    // if its == 0 -> one of the LSBS before gnt bit is expecting for gnt
    // Ex 1: gnt        = 0010
    //       mask_high  = 1100   
    //       req        = 1000
    //       req & mask = 1000 (new gnt) 
    // Ex 2: gnt        = 0010
    //       mask_high  = 1100   
    //       req        = 0010
    //       req & mask = 0000 (new gnt == 2nd bit) 
    always_comb begin
      if(int_r == 1)         exp_gnt_int = mask_high & req_i;
      else if(ready_q == 1)  exp_gnt_int = mask_high & req_i;
    end
    always_comb begin
      if(int_r == 1 || ready_q == 1) begin
        exp_gnt_index = (exp_gnt_int == 0) ? locate_first_one(req_i): locate_first_one(exp_gnt_int);
      end else begin
        exp_gnt_index = exp_gnt_index;
      end
    end

    always_comb begin
      for(int i = 0; i < N; i++) begin
        exp_gnt[i] = (exp_gnt_index == i + 1) ? 1'b1 : 1'b0;
      end
    end

    gnt_check : assert property (  @( posedge clk_i ) disable iff(!rst_ni)
        ready_i == 1 |-> (  gnt_o == exp_gnt) )
    else $error("Arbiter has does not grant correctly");

    gnt_at_most_one_requester: assert property (@(posedge clk_i) disable iff(!rst_ni)
            $onehot0(gnt_o)) else $error("arbiter: granting more than one requester");

    arbiter_work_conserving: assert property (@(posedge clk_i) disable iff(!rst_ni)
            (req_i > 0) |-> (gnt_o > 0)) else $error("arbiter: is not work conserving");

    // function to get the first 1 bit in a vector 
    function int locate_first_one (input [N-1:0] a );
      locate_first_one = 0;
      for (int i =0 ; i < N; i++)
      begin
        if(a[i] == 1'b1)
          begin
            locate_first_one=i+1;
            break; 
          end
      end
    endfunction

endmodule


