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
//  Description : This tests configure randomly the hwpf_strides and 
//                sends an unique request from the Requesters to start 
//                them up
// ----------------------------------------------------------------------------

`ifndef __test_hpdcache_hwpf_stride_reset_on_the_fly_SVH__
`define __test_hpdcache_hwpf_stride_reset_on_the_fly_SVH__

class test_hpdcache_hwpf_stride_reset_on_the_fly extends test_base;

  `uvm_component_utils(test_hpdcache_hwpf_stride_reset_on_the_fly)

  // Variable
  logic  flag_rearm [NUM_HW_PREFETCH] ;
  int    counter_hwpf_stride             ;
  int    number_hwpf_stride              ;

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    set_type_override_by_type(hpdcache_txn::get_type(), hpdcache_load_store_with_amos_txn::get_type());
    set_type_override_by_type(memory_rsp_cfg::get_type(), memory_rsp_cfg_no_error::get_type());
  endfunction: new

  // -------------------------------------------------------------------------
  // Configure phase
  // -------------------------------------------------------------------------
  virtual task configure_phase(uvm_phase phase);

    super.configure_phase(phase);
  
    `uvm_info("CONFIGURE_PHASE", $sformatf("Start configure phase for the test"), UVM_NONE)

    // Initialization of the flag rearm for the test
    for (int i = 0 ; i < NUM_HW_PREFETCH ; i++ ) begin
      flag_rearm[i] = 0 ;
    end

    // Initialization of some variable for the test
    number_hwpf_stride  = 2 ;
    counter_hwpf_stride = number_hwpf_stride * NUM_HW_PREFETCH ;
    env.reset_driver.set_num_reset( 1 );

  endtask

  // -------------------------------------------------------------------------
  // Run phase
  // -------------------------------------------------------------------------
  virtual task main_phase(uvm_phase phase);

    // Sequences to start the hwpf_strides
    hpdcache_single_directed_addr m_seq[NREQUESTERS-1];

    super.main_phase(phase);
    phase.raise_objection(this, "Starting sequences");

    #1000ns;

    fork 
      begin
        // Loop to start the test for each hwpf_stride
        for ( int i = 0 ; i < NUM_HW_PREFETCH ; i++) begin
          automatic int r = i;

          // Fork to start the hwpf_stridees for each hwpf_stride independently
          fork begin

            // Loop for starting n hwpf_stridees
            for ( int n = 0 ; n < number_hwpf_stride ; n++ ) begin
              `uvm_info("TEST", $sformatf("PREFETCHER_%0d Prefetch_number=%0d(d)",r, n), UVM_NONE)
 
                // Loop to start the sequence to start the hwpf_stride on each
                // requester
                for ( int j = 0 ; j < NREQUESTERS-1 ; j++ ) begin
                    automatic int m = j;
                    automatic logic [63:0] auto_address = 0 ;

                    // Depending of the activation mode of the precedent hwpf_stride,
                    // change the address which should start the hwpf_stride
                    if ( flag_rearm[r] ) begin
                        auto_address = { hwpf_stride_cfg_vif.snoop_addr[r] , 6'b0 };
                    end else begin
                        auto_address = base_addr[r] ;
                    end // end if

                    // Fork to start the sequence on the requester
                    fork begin
                        m_seq[m] = hpdcache_single_directed_addr::type_id::create($sformatf("seq_%0d", m));
                        m_seq[m].set_sid(m);
                        m_seq[m].set_addr(auto_address);
                        m_seq[m].start(env.m_hpdcache[m].m_sequencer);
                    end join_none

                end // end for requester

                // Save the activation mode of this hwpf_stride to determine the
                // address of the next sequence to restart the hwpf_stride
                if ( hwpf_stride_cfg_vif.hwpf_stride_cfg[r].hw_prefetch_base[1] == 1) begin
                    flag_rearm[r] = 1 ;
                end else begin
                    flag_rearm[r] = 0 ;
                end // end if

                // Wait for the hwpf_stride to start, only if the hwpf_stride was enabled
                if ( hwpf_stride_cfg_vif.hwpf_stride_cfg[r].hw_prefetch_base[0] == 1) begin
                  wait ( hwpf_stride_cfg_vif.hwpf_stride_status[32+r] != 'h0 );
                end

                // Wait for the hwpf_stride to end
                wait ( hwpf_stride_cfg_vif.hwpf_stride_status[32+r] == 0 );

                // If the hwpf_stride was in DISARM activation mode, drive low the
                // enable bit at the end of the hwpf_stride, to allow thereconfiguration 
                // of the base address of the hwpf_stride
                if ( hwpf_stride_cfg_vif.hwpf_stride_cfg[r].hw_prefetch_base[1] == 0) begin
                    hwpf_stride_cfg_vif.hwpf_stride_cfg[r].hw_prefetch_base[0] = 0 ;
                end

                // Wait for one cycle after the hwpf_stride is not busy anymore
                // before changing the configuration
                @( posedge hwpf_stride_cfg_vif.clk); 

                // Generate a new configuration for the next hwpf_stride
                generate_random_hwpf_stride_cfg( r );

                // Decrement the counter of the number of hwpf_stride, to end the
                // simulation only when the good number of hwpf_stride has happened
                counter_hwpf_stride-- ;
                `uvm_info("TEST", $sformatf("counter_hwpf_stride=%0d(d)",counter_hwpf_stride), UVM_NONE)

            end // end for number_hwpf_stride

          end join_none

        end // end for NUM_HW_PREFETCH
      end
      begin
        // phase.raise_objection(this, "Starting sequences");

        forever begin
          `uvm_info("TEST", $sformatf("Starting the reset on the fly, reset_on_the_fly_done=%0x(x), num_reset=%0d(d) hit_reset_cnt=%0d(d)",env.reset_driver.get_reset_on_the_fly_done(), env.reset_driver.get_num_reset(), hit_reset_cnt ), UVM_NONE)

          if(env.reset_driver.get_reset_on_the_fly_done == 1) begin 
            `uvm_info("TEST", $sformatf("Starting the reset on the fly"), UVM_NONE)
            // phase.drop_objection(this, "Starting sequences");
            break;
          end

          if ( hit_reset_cnt < 2 ) begin
            if ( !randomize(reset_delay_ns) with {reset_delay_ns inside {[5000:20000]}; } ) begin
              `uvm_fatal("RANDOMIZE FAIL","Unable to randomize reset_delay_ns" );
            end // if
            #(reset_delay_ns * 1ns);
            `uvm_info("TEST", $sformatf("Starting the reset on the fly"), UVM_NONE)

            hit_reset_cnt++;
            // phase.drop_objection(this, "Starting sequences");
            env.reset_driver.emit_assert_reset();
          end

        end
        `uvm_info("TEST", $sformatf("Breaking from the forever"), UVM_NONE)

      end 
    join_none

    // Waiting for all hwpf_stridees to happens
    wait ( counter_hwpf_stride == 0 );
    `uvm_info("TEST", $sformatf("Ending the test"), UVM_NONE)

    #5000ns;
    phase.drop_objection(this, "Completed sequences");

  endtask: main_phase

endclass: test_hpdcache_hwpf_stride_reset_on_the_fly

`endif // __test_hpdcache_hwpf_stride_reset_on_the_fly_SVH__
