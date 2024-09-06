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
