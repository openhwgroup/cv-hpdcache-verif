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
import dram_mon_agent_pkg::*;

interface dram_if (input bit clk_i, input bit rst_ni);

    //      Miss read interface
    logic                          mem_req_read_ready_i;
    logic                          mem_req_read_valid_o;
    hpdcache_mem_req_t             mem_req_read_o;
    hpdcache_mem_id_t              mem_req_read_base_id_i;

    logic                          mem_resp_read_ready_o;
    logic                          mem_resp_read_valid_i;
    logic                          mem_resp_read_valid_int_i;
    hpdcache_mem_resp_r_t          mem_resp_read_int_i;
    hpdcache_mem_resp_r_t          mem_resp_read_i;

    //      Write-buffer write interface
    logic                          mem_req_write_ready_i;
    logic                          mem_req_write_valid_o;
    hpdcache_mem_req_t             mem_req_write_o;
    hpdcache_mem_id_t              mem_req_write_base_id_i;
    bp_t                           mem_req_write_ready_bp; 
    
    logic                          mem_req_write_data_ready_i;
    logic                          mem_req_write_data_valid_o;
    hpdcache_mem_req_w_t           mem_req_write_data_o;
    bp_t                           mem_req_write_data_ready_bp; 

    logic                          mem_req_write_ready_int_i;
    logic                          mem_req_write_valid_int_o;
    hpdcache_mem_ext_req_t         mem_req_write_int_o;         
    
    logic                          mem_resp_write_ready_o;
    logic                          mem_resp_write_valid_i;
    hpdcache_mem_resp_w_t          mem_resp_write_i;

    logic                          mem_resp_write_valid_int_i;
    hpdcache_mem_resp_w_t          mem_resp_write_int_i;

    // ------------------------------------------------------------------------
    // Delay Task
    // ------------------------------------------------------------------------
    task wait_n_clocks( int N );          // pragma tbx xtf
      begin
         @(posedge clk_i);
         repeat (N-1) @( posedge clk_i );
      end
    endtask : wait_n_clocks


//`ifndef AXI2MEM
//    // Back Pressure on ready signal 
//    always_ff @(posedge clk_i or negedge rst_ni) begin
//      if(~rst_ni) begin
//        mem_req_write_ready_i <= 0;
//      end else begin
//        case(mem_req_write_ready_bp)
//          NEVER :
//          begin
//           mem_req_write_ready_i <= 1'b1; 
//          end
//          LIGHT : 
//          begin 
//           if($urandom_range(1, 3) == 2)     mem_req_write_ready_i <= 1'b0;
//           else                              mem_req_write_ready_i <= 1'b1; 
//          end
//          MEDIUM:
//          begin 
//           if($urandom_range(1, 10) >= 4)    mem_req_write_ready_i <= 1'b0;
//           else                              mem_req_write_ready_i <= 1'b1; 
//          end
//          HEAVY: 
//          begin 
//           if($urandom_range(1, 20) >= 5)    mem_req_write_ready_i <= 1'b0;
//           else                              mem_req_write_ready_i <= 1'b1; 
//          end
//        endcase
//      end
//    end
//    
//
//    // Back Pressure on ready signal 
//    always_ff @(posedge clk_i or negedge rst_ni) begin
//      if(~rst_ni) begin
//        mem_req_write_data_ready_i <= 0;
//      end else begin
//        case(mem_req_write_data_ready_bp)
//          NEVER :
//          begin
//           mem_req_write_data_ready_i <= 1'b1; 
//          end
//          LIGHT : 
//          begin 
//           if($urandom_range(1, 3) == 2)     mem_req_write_data_ready_i <= 1'b0;
//           else                              mem_req_write_data_ready_i <= 1'b1; 
//          end
//          MEDIUM:
//          begin 
//           if($urandom_range(1, 10) >= 4)    mem_req_write_data_ready_i <= 1'b0;
//           else                              mem_req_write_data_ready_i <= 1'b1; 
//          end
//          HEAVY: 
//          begin 
//           if($urandom_range(1, 20) >= 5)    mem_req_write_data_ready_i <= 1'b0;
//           else                              mem_req_write_data_ready_i <= 1'b1; 
//          end
//        endcase
//      end
//    end
//  
//    always_ff @(posedge clk_i or negedge rst_ni) begin
//      if(~rst_ni) begin
//        mem_req_uc_write_ready_i <= 0;
//      end else begin
//        case(mem_req_uc_write_ready_bp)
//          NEVER :
//          begin
//           mem_req_uc_write_ready_i <= 1'b1; 
//          end
//          LIGHT : 
//          begin 
//           if($urandom_range(1, 3) == 2)     mem_req_uc_write_ready_i <= 1'b0;
//           else                              mem_req_uc_write_ready_i <= 1'b1; 
//          end
//          MEDIUM:
//          begin 
//           if($urandom_range(1, 10) >= 4)    mem_req_uc_write_ready_i <= 1'b0;
//           else                              mem_req_uc_write_ready_i <= 1'b1; 
//          end
//          HEAVY: 
//          begin 
//           if($urandom_range(1, 20) >= 5)    mem_req_uc_write_ready_i <= 1'b0;
//           else                              mem_req_uc_write_ready_i <= 1'b1; 
//          end
//        endcase
//      end
//    end
//
//   
//    always_ff @(posedge clk_i or negedge rst_ni) begin
//      if(~rst_ni) begin
//        mem_req_uc_write_data_ready_i <= 0;
//      end else begin
//        case(mem_req_uc_write_data_ready_bp)
//          NEVER :
//          begin
//           mem_req_uc_write_data_ready_i <= 1'b1; 
//          end
//          LIGHT : 
//          begin 
//           if($urandom_range(1, 3) == 2)     mem_req_uc_write_data_ready_i <= 1'b0;
//           else                              mem_req_uc_write_data_ready_i <= 1'b1; 
//          end
//          MEDIUM:
//          begin 
//           if($urandom_range(1, 10) >= 4)    mem_req_uc_write_data_ready_i <= 1'b0;
//           else                              mem_req_uc_write_data_ready_i <= 1'b1; 
//          end
//          HEAVY: 
//          begin 
//           if($urandom_range(1, 40) >= 5)    mem_req_uc_write_data_ready_i <= 1'b0;
//           else                              mem_req_uc_write_data_ready_i <= 1'b1; 
//          end
//        endcase
//      end
//    end
//`endif
endinterface

