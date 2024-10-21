## ----------------------------------------------------------------------------
##Copyright 2024 CEA*
##*Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
##
##Licensed under the Apache License, Version 2.0 (the "License");
##you may not use this file except in compliance with the License.
##You may obtain a copy of the License at
##
##    http://www.apache.org/licenses/LICENSE-2.0
##
##Unless required by applicable law or agreed to in writing, software
##distributed under the License is distributed on an "AS IS" BASIS,
##WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##See the License for the specific language governing permissions and
##limitations under the License.
##[END OF HEADER]
## ----------------------------------------------------------------------------
##  Description : Agent for the hpdcache request
## ----------------------------------------------------------------------------

import argparse
import os


project_dir = os.environ["PROJECT_DIR"];
questa_path = os.environ["QUESTA_PATH"];


def run_test(test_name, seed, debug, batch, dump, num_txn, stdout, outdir):
   ## get arguments
   if outdir == None: 
      outdir = "output"

   if test_name == None: 
      test_name = "test_hpdcache_multiple_random_requests"
   
   if seed == None: 
      seed = 2
   
   if debug == None: 
      debug = "UVM_LOW"
  
   if batch == None: 
      batch = 1 
   
   if dump == None: 
      dump = 1 
   
   if num_txn == None: 
      num_txn = 5000 
   
   if batch == 1:
     batchstr = "-c"
   else:
     batchstr = ""
   
   if dump == 1:
     dumpstr = "{}/testbench/simu/run.do".format(project_dir)
   else:
     dumpstr = "{}/testbench/simu/run_no_log.do".format(project_dir)

   if stdout == None:
       stdout = 1

   if stdout == 0:
       stdoutstr = ">"
   else:
       stdoutstr = "-l"
  
   if os.path.isdir("{}".format(outdir)) == False:
     os.system("mkdir {}".format(outdir))
   
   os.system("vsim {} -do {} +NB_TXNS={} -sv_seed {} +UVM_VERBOSITY={} -wlf {}/{}_{}.wlf +UVM_TESTNAME={} -assertdebug +COVER_VERBOSE -msgmode both -L cv_uvm_dv_utils_lib -64 +UVM_NO_RELNOTES +TIMEOUT=40000000 +PERF_LOG=NO -suppress 8386 -suppress 8233 -do {}/testbench/simu/run.do -lib work opt {} {}/{}_{}.log".format(batchstr, dumpstr, num_txn, seed, debug, outdir, test_name, seed, test_name, project_dir, stdoutstr, outdir, test_name, seed ))
