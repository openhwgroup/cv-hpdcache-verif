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
// Class hwpf_stride_cfg_c
//
// Contains fields that are sent to the scoreboard for further analysis
// -----------------------------------------------------------------------
class hwpf_stride_cfg_c extends uvm_sequence_item;

    `uvm_object_utils(hwpf_stride_cfg_c )

    typedef enum bit {
      SHORT = 0 ,
      LONG  = 1
    } length_t;

    // ------------------------------------------------------------------------
    // Fields
    // ------------------------------------------------------------------------
    rand logic [63:0] snoop ;

    // Throttle config
    rand logic [15:0] ninflight ;
    rand logic [15:0] nwait     ;

    // Param config
    rand logic [15:0] nlines    ;
    rand logic [15:0] nblocks   ;
    rand logic [31:0] strides   ;

    // Base config
    rand logic [58:0] base_address ;
    rand logic        enable_bit   ;
    rand logic        rearm_bit    ;
    rand logic        cycle_bit    ;
    rand logic        upstream_bit ;

    rand length_t     prefetch_length ;
    rand int unsigned cycle_before_abort;
    
    // ------------------------------------------------------------------------
    // Constraints
    // ------------------------------------------------------------------------
    // Prefetch length constraints
    constraint c_length         { prefetch_length dist { SHORT := 100, LONG := 1 } ; }
    constraint c_short_prefetch { ( prefetch_length == SHORT ) -> ( ( nblocks + 1 ) * ( nlines + 1 ) <= 512  ) ; }
    constraint c_long_prefetch  { ( prefetch_length == LONG )  -> ( ( ( nblocks + 1 ) * ( nlines + 1 ) <= 5096 ) && ( ( nblocks + 1 ) * ( nlines + 1 ) > 512 ) ); }


    // Configuration constraints
    constraint c_block        { nblocks <= 'h13e7 ; }
    constraint c_line         { nlines  <= 'h13e7 ; }
    constraint c_nwait   {  nwait  <= 0  ; }
 //   constraint c_nwait_long   { ( prefetch_length == LONG )  -> ( nwait  <= 'hf )  ; }
 //   constraint c_nwait_short  { ( prefetch_length == SHORT ) -> ( nwait  <= 'hff ) ; }
    constraint c_ninflight    { ninflight  <= 'hff ; }
    constraint c_base_address { base_address dist { 'h0 := 10, ['h1:'h1ff_ffff_ffff_fffe] := 100, 'h1ff_ffff_ffff_ffff := 10 } ; }

    constraint c_cycle_before_abort { cycle_before_abort dist { [0: 10] := 45, 
                                                                [11: ( nlines + 1 ) * ( nblocks + 1 )] := 10,
                                                                [( nlines + 1 ) * ( nblocks + 1 ): ( nlines + 1 ) * ( nblocks + 1 ) + 100] := 45};}
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hwpf_stride_cfg_c");
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
 
endclass: hwpf_stride_cfg_c


class hwpf_stride_cfg_cnr_active_c extends hwpf_stride_cfg_c;

    `uvm_object_utils(hwpf_stride_cfg_cnr_active_c )


    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hwpf_stride_cfg_cnr_active_c");
        super.new(name);
    endfunction

    constraint c_cycle_bit        { cycle_bit == 1; }
    constraint c_rearm_bit        { rearm_bit == 1; }
 
endclass: hwpf_stride_cfg_cnr_active_c
