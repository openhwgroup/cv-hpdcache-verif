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
//  Description : Agent for the dram request
// ----------------------------------------------------------------------------

class dram_mon_agent extends uvm_agent;

  // -------------------------------------------------------------------------
  // UVM Utils
  // -------------------------------------------------------------------------
  `uvm_component_utils_begin(dram_mon_agent)
      `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
  `uvm_component_utils_end

  // -------------------------------------------------------------------------
  // Fields for the vrp agents
  // -------------------------------------------------------------------------
  protected uvm_active_passive_enum is_active = UVM_PASSIVE;

`ifndef AXI2MEM
  dram_mon_fifo     m_dram_fifo;
`endif
  dram_monitor      m_monitor;

  virtual dram_if dram_vif; 
  
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

  `ifndef AXI2MEM
    m_dram_fifo  = dram_mon_fifo::type_id::create("DRAM_FIFO", this);
  `endif
    m_monitor    = dram_monitor::type_id::create("DRAM_MON", this);

    if (!uvm_config_db #( virtual dram_if)::get(this, "", "DRAM_IF", dram_vif )) begin
        `uvm_fatal("BUILD_PHASE", $psprintf("Unable to get dram_vif_config for %s from configuration database", get_name() ) );
    end // if

    `uvm_info(get_full_name( ), "Build stage complete.", UVM_LOW)
  endfunction: build_phase
  
  // ----------------------------------------------------------------------
  // connect phase
  // ----------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
   `ifndef AXI2MEM
      m_dram_fifo.set_dram_vif(dram_vif);
  `endif
      `uvm_info(get_full_name( ), "Connect stage complete.", UVM_LOW)
  endfunction: connect_phase

  // ----------------------------------------------------------------------
  // Set agent to active mode
  // ----------------------------------------------------------------------
  function void set_is_active();
    is_active = UVM_PASSIVE;
  endfunction: set_is_active
  
endclass: dram_mon_agent
