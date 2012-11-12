#!/bin/bash

# The purpose of this wrapper script is to set some environment
# variables particular to our setup on moby, prior to launching the
# FastCGI process.

export LD_LIBRARY_PATH=/tdr/bin/lib:/usr/local/lib:/usr/local/lib/mysql

# Here's the command that actually launches the FastCGI server.
/tdr/bin/esd-dev/script/esd_fastcgi.pl -processes 3
