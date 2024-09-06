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
//  Description : DCache transaction used in the driver to drive the requests
// ----------------------------------------------------------------------------

// -----------------------------------------------------------------------
// Class cacheability_cfg_c
//
// Contains fields that are sent to the scoreboard for further analysis
// -----------------------------------------------------------------------
class cacheability_cfg_c extends uvm_sequence_item;

    `uvm_object_utils(cacheability_cfg_c )

    // ------------------------------------------------------------------------
    // Fields
    // ------------------------------------------------------------------------
    logic [63:0] cacheability_base ;
    logic [63:0] cacheability_mask ;
    logic        cacheability_en   ;

    // ------------------------------------------------------------------------
    // Constraints
    // ------------------------------------------------------------------------
    constraint c_base { cacheability_base dist { 'h0 := 10, ['h1:'hffff_ffff_ffff_fffe] := 100, 'hffff_ffff_ffff_ffff := 10 } ; }
    constraint c_mask { cacheability_mask dist { 'h0 := 10, ['h1:'hffff_ffff_ffff_fffe] := 100, 'hffff_ffff_ffff_ffff := 10 } ; }

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "cacheability_cfg_c");
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
 
endclass: cacheability_cfg_c
