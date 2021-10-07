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

`ifndef __test_hpdcache_multiple_random_hwpf_strides_SVH__
`define __test_hpdcache_multiple_random_hwpf_strides_SVH__

class test_hpdcache_multiple_random_hwpf_strides extends test_base;

  `uvm_component_utils(test_hpdcache_multiple_random_hwpf_strides)

  // Variable
  logic  flag_rearm [NUM_HW_PREFETCH] ;
  int    number_hwpf_stride ;
  int    counter_hwpf_stride [NUM_HW_PREFETCH] ;

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

    // Initialization of the flag rearm for the test
    for (int i = 0 ; i < NUM_HW_PREFETCH ; i++ ) begin
      flag_rearm[i] = 0 ;
      counter_hwpf_stride[i] = 5 ;
    end

    number_hwpf_stride = 5;

  endtask

  // -------------------------------------------------------------------------
  // Run phase
  // -------------------------------------------------------------------------
  virtual task main_phase(uvm_phase phase);

    // Sequences to start the hwpf_strides
    hpdcache_single_directed_addr m_seq[NREQUESTERS-1];

    phase.raise_objection(this, "Starting sequences");

    // Loop to start the test for each hwpf_stride
    for ( int i = 0 ; i < NUM_HW_PREFETCH ; i++) begin
      automatic int r = i;

      // Fork to start the hwpf_strides for each hwpf_stride independently
      fork begin

        // Loop for starting n hwpf_strides
        for ( int n = 0 ; n < number_hwpf_stride ; n++ ) begin
 
            // Loop to start the sequence to start the hwpf_stride on each
            // requester
            for ( int j = 0 ; j < NREQUESTERS - 1 ; j++ ) begin
                automatic int m = j;
                automatic hpdcache_req_addr_t auto_address = 0 ;
                automatic logic auto_rearm = flag_rearm[r] ;

                // Depending of the activation mode of the precedent hwpf_stride,
                // change the address which should start the hwpf_stride
                if ( auto_rearm ) begin
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
            if ( hwpf_stride_cfg_vif.hwpf_stride_cfg[r].hw_prefetch_base[1] == 1 ) begin
              flag_rearm[r] = 1 ;
            end else begin
              flag_rearm[r] = 0 ;
            end

            // Wait for the hwpf_stride to start, only if the hwpf_stride was enabled
            wait ( hwpf_stride_cfg_vif.hwpf_stride_status[32+r] != 'h0 );

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

            @( posedge hwpf_stride_cfg_vif.clk); 

            // Decrement the counter of the number of hwpf_stride, to end the
            // simulation only when the good number of hwpf_stride has happened
            counter_hwpf_stride[r]-- ;
            // `uvm_info("DEBUG", $sformatf("PREFETCHER_%0d counter_hwpf_stride=%0d(d)",r, counter_hwpf_stride[r]  ), UVM_NONE)

        end // end for number_hwpf_stride

      end join_none

    end // end for NUM_HW_PREFETCH

    // Waiting for all hwpf_strides to happens
    for ( int i = 0 ; i < 2 ; i ++ ) begin
      fork begin
        automatic int r = i ;
        wait ( counter_hwpf_stride[r] == 0 ) ;
      end join
    end // for

    #5000ns;
    phase.drop_objection(this, "Completed sequences");
    super.main_phase(phase);

  endtask: main_phase

endclass: test_hpdcache_multiple_random_hwpf_strides

`endif // __test_hpdcache_multiple_random_hwpf_strides_SVH__
