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
//  Description : DCache configuration 
// ----------------------------------------------------------------------------

// -----------------------------------------------------------------------
// Class hpdcache_top_cfg
//
// Contains fields that are sent to the scoreboard for further analysis
// -----------------------------------------------------------------------
class hpdcache_top_cfg extends uvm_object;
   `uvm_object_utils( hpdcache_top_cfg)

    rand int       m_requester_enable[NREQUESTERS - 1];
    rand int       m_num_requesters;        // how many requesters enabled
    rand bit       m_reset_on_the_fly;
    rand bit       m_flush_on_the_fly;
    rand bit       m_bPLRU_enable;
    rand bit       m_disable_wbuf_merge_check;
    rand bp_type_t m_read_bp_type;
    rand bp_type_t m_write_req_bp_type;
    rand bp_type_t m_write_data_bp_type;

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_top_cfg");
        super.new(name);
    endfunction

    // ------------------------------------------------------------------------
    // convert2string
    // ------------------------------------------------------------------------
    virtual function string convert2string;
        string s;
        s = super.convert2string();

        s = {s, $sformatf( "NUM_REQUESTERS %d", m_num_requesters)};
        s = {s, $sformatf( "RESET %d",          m_reset_on_the_fly)};
        s = {s, $sformatf( "FLUSH %d",          m_flush_on_the_fly)};
        s = {s, $sformatf( "PLRU Enable %d",    m_bPLRU_enable)};
        return s;
    endfunction: convert2string
       
   constraint requester_enab_binary_c { foreach ( m_requester_enable[i] ) m_requester_enable[i] inside { 0, 1 }; }; 

    // 1 requester is for Prefetcher 
    constraint requester_num_c {
             NREQUESTERS > 1 ->
                m_num_requesters  dist {                 1  := 10,    
                                             [2:NREQUESTERS]:= 1 
                                        }; 
             NREQUESTERS == 1 ->
                m_num_requesters  == 1; 
            }


   constraint reset_on_the_fly_c   {m_reset_on_the_fly dist {1 := 10, 0 := 90};} // insert reset on the fly 10% of the time
   constraint flush_on_the_fly_c   {m_flush_on_the_fly dist {1 := 10, 0 := 90};} // insert flush on the fly 10% of the time
   constraint num_requerts_c { m_requester_enable.sum() == m_num_requesters; }

   constraint bPLRU_c      { m_bPLRU_enable  == 0; }
   constraint wbuf_merge_c { m_disable_wbuf_merge_check  == 1; }

endclass: hpdcache_top_cfg

class hpdcache_top_one_requester_cfg extends hpdcache_top_cfg;
   `uvm_object_utils( hpdcache_top_one_requester_cfg)
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_top_one_requester_cfg");
        super.new(name);
        num_requerts_c.constraint_mode(0);
        reset_on_the_fly_c.constraint_mode(0);
    endfunction

       
   constraint num_one_request_c     { m_requester_enable.sum() == 1; }
   constraint no_reset_on_the_fly_c { m_reset_on_the_fly  == 0; }


endclass: hpdcache_top_one_requester_cfg

class hpdcache_bPLRU_cfg extends hpdcache_top_cfg;
   `uvm_object_utils(hpdcache_bPLRU_cfg )
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_bPLRU_cfg");
        super.new(name);
        bPLRU_c.constraint_mode(0);
        reset_on_the_fly_c.constraint_mode(0);
        num_requerts_c.constraint_mode(0);
    endfunction

       
   constraint no_reset_on_the_fly_c      { m_reset_on_the_fly  == 0; }
   constraint bPLRU_enable_c             { m_bPLRU_enable  == HPDCACHE_VICTIM_SEL; }
   constraint no_read_bp                 { m_read_bp_type           == NO_BP;}
   constraint no_write_req_bp            { m_write_req_bp_type      == NO_BP;}
   constraint no_write_data_bp           { m_write_data_bp_type     == NO_BP;}
   constraint num_one_request_c     { m_requester_enable.sum() == 1; }


endclass

class hpdcache_top_one_requester_congestion_cfg extends hpdcache_top_cfg;
   `uvm_object_utils( hpdcache_top_one_requester_congestion_cfg)
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function new(string name = "hpdcache_top_one_requester_congestion_cfg");
        super.new(name);
        num_requerts_c.constraint_mode(0);
        reset_on_the_fly_c.constraint_mode(0);
        flush_on_the_fly_c.constraint_mode(0);
    endfunction

       
   constraint num_one_request_c     { m_requester_enable.sum() == 1; }
   constraint no_reset_on_the_fly_c { m_reset_on_the_fly  == 0; }
   constraint no_flush_on_the_fly_c { m_flush_on_the_fly  == 0; }
   constraint no_read_bp            { m_read_bp_type           == NO_BP;}
   constraint no_write_req_bp       { m_write_req_bp_type      == NO_BP;}
   constraint no_write_data_bp      { m_write_data_bp_type     == NO_BP;}

endclass: hpdcache_top_one_requester_congestion_cfg
