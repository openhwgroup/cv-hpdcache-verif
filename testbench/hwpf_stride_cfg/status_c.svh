/// ----------------------------------------------------------------------------
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
//  Description : DCache transaction used in the driver to drive the requests
// ----------------------------------------------------------------------------

// -----------------------------------------------------------------------
// Class status_c
//
// Contains fields that are sent to the scoreboard for further analysis
// -----------------------------------------------------------------------
class status_c extends uvm_sequence_item;

    `uvm_object_utils(status_c )

    // ------------------------------------------------------------------------
    // Fields
    // ------------------------------------------------------------------------
    logic [NUM_HW_PREFETCH-1:0] enable     ;
    logic [3:0]                 free_index ;
    logic                       free       ;
    logic [NUM_HW_PREFETCH-1:0] busy       ;

    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "status_c");
        super.new(name);
    endfunction

    // ------------------------------------------------------------------------
    // convert2string
    // ------------------------------------------------------------------------
    virtual function string convert2string;
        string s;
        s = super.convert2string();
        return s;
    endfunction: convert2string
 
endclass: status_c
