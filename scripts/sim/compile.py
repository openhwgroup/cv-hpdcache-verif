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
import compile_cmd as cmp

parser = argparse.ArgumentParser(description='compile and simulation options')
parser.add_argument('--cfg'     ,dest='cfg', type=str, help='One of the 4 congurations:config1_HPC, config2_HPC, CONFIG3_EMBEDDED, CONFIG4_EMBEDDED')
parser.add_argument('--outdir'  ,dest='outdir', type=str, help='Logs are directed to outdir: default output')
parser.add_argument('--stdout'  ,dest='stdout', type=int, help='If 0, logs are direted directly to outdir/<file.log>')
args = parser.parse_args()

print(args.stdout)
cmp.compile_cmd(args.cfg, args.outdir, args.stdout)
