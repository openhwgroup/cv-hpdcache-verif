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
//  Description : Agent for the hpdcache request
// ----------------------------------------------------------------------------

class hpdcache_agent extends uvm_agent;

  // -------------------------------------------------------------------------
  // UVM Utils
  // -------------------------------------------------------------------------
  `uvm_component_utils_begin(hpdcache_agent)
      `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
  `uvm_component_utils_end

  // -------------------------------------------------------------------------
  // Fields for the vrp agents
  // -------------------------------------------------------------------------
  protected uvm_active_passive_enum is_active = UVM_PASSIVE;

  hpdcache_sequencer  m_sequencer;
  hpdcache_driver     m_driver;

  virtual hpdcache_if hpdcache_vif; 
  hpdcache_monitor    m_monitor;
  
  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
      super.new(name, parent);
  endfunction
  
  // ----------------------------------------------------------------------
  // Build Phase
  // ----------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    m_monitor = hpdcache_monitor::type_id::create("monitor", this);
    if(is_active == UVM_ACTIVE) begin
      m_sequencer = hpdcache_sequencer::type_id::create("sequencer", this);
      m_driver    = hpdcache_driver::type_id::create("driver", this);
      m_monitor.set_is_active();
    end

    if (!uvm_config_db #( virtual hpdcache_if)::get(this, "", get_name(), hpdcache_vif )) begin
        `uvm_fatal("BUILD_PHASE", $psprintf("Unable to get hpdcache_vif_config for %s from configuration database", get_name() ) );
    end // if

    `uvm_info(get_full_name( ), "Build stage complete.", UVM_LOW)
  endfunction: build_phase
  
  // ----------------------------------------------------------------------
  // connect phase
  // ----------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
      if(is_active == UVM_ACTIVE) begin
        m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        m_driver.set_hpdcache_vif(hpdcache_vif);
        m_monitor.m_sequencer    = m_sequencer; 
      end
      m_monitor.set_hpdcache_vif(hpdcache_vif);
      `uvm_info(get_full_name( ), "Connect stage complete.", UVM_LOW)
  endfunction: connect_phase

  // ----------------------------------------------------------------------
  // Set agent to active mode
  // ----------------------------------------------------------------------
  function void set_is_active();
    is_active = UVM_ACTIVE;
  endfunction: set_is_active
 
  virtual task reset_phase( uvm_phase phase );
      if ( is_active == UVM_ACTIVE ) begin
        m_sequencer.stop_sequences();
        `uvm_info( "STOPPED SEQUENCES", "STOPPED SEQUENCES", UVM_LOW );
      end // if
  endtask: reset_phase

endclass: hpdcache_agent
