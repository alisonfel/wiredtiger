#!/usr/bin/python

from bcc import BPF
import argparse

def find_symbols(wt_lib):
    user_functions = BPF.get_user_functions(
        wt_lib, str())
    for f in user_functions:
        print(f.decode('utf8'))

parser = argparse.ArgumentParser(
    description="Find WiredTiger symbols with eBPF",
    formatter_class=argparse.RawDescriptionHelpFormatter)

parser.add_argument(
    "-l", "--lib", type=str, dest="wt_lib",
    help="WiredTiger library path",
    required=True)
args = parser.parse_args()

find_symbols(args.wt_lib)
