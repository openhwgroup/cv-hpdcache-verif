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
import run

parser = argparse.ArgumentParser(description='compile and simulation options')
parser.add_argument('--test_name',dest='test_name', type=str, help='Name of the test, default: test_hpdcache_multiple_random_requests')
parser.add_argument('--seed'     , dest='seed',      type=int, help='random seed ex: 3452363, default 1')
parser.add_argument('--debug'    , dest='debug',     type=str, help='UVM_LOW/MEDIUM/HIGH/FULL/DEBUG, default LOW')
parser.add_argument('--batch'    , dest='batch',     type=int, help='1: batch mode, 0:gui default, 1')
parser.add_argument('--dump'     , dest='dump',      type=int, help='1: all signals are logged, 0: nothing is looged, default 1')
parser.add_argument('--num_txn'  , dest='num_txn',   type=int, help='number of transactions ex: 4000, default 5000')
parser.add_argument('--stdout' , dest='stdout', type=int, help='1: stdout 0: nostdout')
parser.add_argument('--outdir'   , dest='outdir', type=str, help='output dirctory de fault "output"')
##
args = parser.parse_args()

run.run_test(args.test_name, args.seed, args.debug, args.batch, args.dump, args.num_txn, args.stdout, args.outdir )
