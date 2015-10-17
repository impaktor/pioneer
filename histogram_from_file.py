#!/usr/bin/env python2

import numpy as np
import argparse

def parse_arg():
    "Use argparse to parse the arguments from the command line"

    descrip = "Make a histogram of data from a column (default: first) in a file"
    parser = argparse.ArgumentParser(description=descrip)

    parser.add_argument('file')
    parser.add_argument('-b','--bins', help='bins to use', required=False, default = 20)
    parser.add_argument('-c','--col',  help='use col (0 indexed)', required=False, default = 0)
    parser.add_argument('-l','--log',  help='use log spacing on data', required=False, dest='log', action='store_true')
    parser.set_defaults(log=False)
    args = parser.parse_args()
    return args


def main(args):
    print("# Data from: %s" % args.file)
    data = np.loadtxt(args.file, comments='#', usecols={int(args.col)})

    bins = int(args.bins)
    if args.log:
        logdata = [np.log(i) for i in data if i > 0]
        f, x = np.histogram(logdata, bins=bins)
    else:
        f, x = np.histogram(data, bins=bins)

    # Normalize:
    bin_width = (x[-1]  - x[0]) / bins
    tot_number = np.sum(f)
    tot_area = tot_number * bin_width

    print("# value:\t norm. freq:\t count:")
    for i in range(len(f)):
        print("%s\t%s\t%s" % (x[i], f[i]/tot_area, f[i]))


if __name__ == "__main__":
    args = parse_arg()
    main(args)
