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

import argparse
import os

project_dir  = os.environ["PROJECT_DIR"];
hpdcache_dir = os.environ["HPDCACHE_DIR"];
cv_dv_utils  = os.environ["CV_DV_UTILS_DIR"];
questa_path  = os.environ["QUESTA_PATH"];

def compile_cmd(config, outdir, stdout):

   if stdout==None:
       stdout = 1

   if outdir==None:
       outdir = "output"

   if stdout == 1:
       stdoutstr = "-l"
   else:
       stdoutstr = ">"

   if config==None: 
      cfg = "{}/modules/hpdcache_params/hpdcache_params_pkg.sv".format(project_dir)
   elif config == "CONFIG1_HPC":
      cfg =  "{}/modules/hpdcache_params/hpdcache_params_pkg_config1_HPC.sv".format(project_dir)
   elif config == "CONFIG2_HPC":
      cfg =  "{}/modules/hpdcache_params/hpdcache_params_pkg_config2_HPC.sv".format(project_dir)
   elif config == "CONFIG3_EMBEDDED":
      cfg =  "{}/modules/hpdcache_params/hpdcache_params_pkg_config3_EMBEDDED.sv".format(project_dir)
   elif config == "CONFIG4_EMBEDDED":
      cfg =  "{}/modules/hpdcache_params/hpdcache_params_pkg_config4_EMBEDDED.sv".format(project_dir)

   if os.path.isdir("{}".format(outdir)) == False:
     os.system("mkdir {}".format(outdir))

   os.system("vlog -sv {}/rtl/include/hpdcache_typedef.svh {} -F {}/rtl/hpdcache.Flist -suppress 13177,13314 -lint -suppress 2583,13314 -lint=full {}/rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_1rw.sv {}/rtl/src/common/macros/behav/hpdcache_sram_1rw.sv {}/rtl/src/common/macros/behav/hpdcache_sram_wmask_1rw.sv -work work {} {}/rtl_compile.log".format(hpdcache_dir, cfg ,hpdcache_dir, hpdcache_dir, hpdcache_dir, hpdcache_dir, stdoutstr, outdir))

   os.system("vlog -sv +define+{} +define+AXI2MEM +incdir+{}/rtl/include -F {}/uvm/Files.f -F {}/testbench/Files.f -suppress 13177,13314 -lint -L {}/uvm-1.1d +incdir+{}/verilog_src/uvm-1.1d/src -suppress 2583,13314 -lint=full {}/testbench/top/top_axi2mem.sv -work work {} {}/tb_compile.log".format(config, hpdcache_dir, cv_dv_utils , project_dir, questa_path, questa_path, project_dir,  stdoutstr, outdir)) 

   os.system("vopt  -assertdebug top  -o opt -work work  +acc -64 -L {}/uvm-1.1d -suppress 2583,13314 -lint=full {} {}/vopt.log".format(questa_path, stdoutstr, outdir))  
