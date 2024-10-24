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
//  Description : This class contains dram monitor configuration elements 
//                To drive ready back pressure 
// ----------------------------------------------------------------------------

class dram_mon_cfg extends uvm_component;

    `uvm_component_utils( dram_mon_cfg)
     rand bp_t wbuf_write_ready_bp;
     rand bp_t wbuf_write_data_ready_bp;
    // ----------------------------------------------------------------------- 
    // Constructor
    // ----------------------------------------------------------------------- 
    function new( string name , uvm_component parent = null ); 
      super.new( name , parent);
    endfunction

endclass
