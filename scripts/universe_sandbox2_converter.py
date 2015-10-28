#!/usr/bin/env python2

import sys

# float, string -> string
def computeOrbit(x,y):
    """This function does something with x,y,
    and returns a cryptic string of little meaning"""

    return "foo"



def main(argv):
    if not len(argv) == 2:
        print("wrong number or arguments to program: %s" % (argv[0]))
        sys.exit()

    fileToOpen = argv[1]
    print("# Data from: %s" % fileToOpen)

    # open file in read only mode
    f = open(fileToOpen, 'r')

    # read each line, in file and
    for line in f.readlines():
        print(line.split())


if __name__ == "__main__":
    main(sys.argv)
