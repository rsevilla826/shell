# shell
Random collection of useful shell scripts I developed

run.sh - I developed this to execute PDI ETL jobs:

################################################################################################
# Script: run.sh
# Author: Robert Sevilla
#
# Description - This script will run all ETL jobs in PDI (Pentaho Data Integration)
#               run.sh will set the environment variables for PDI to run and also
#               prevent duplicate runs.
#
# Arguments: $1 - JOB NAME
#            $2 - LOG LEVEL (Default - Basic):
#			Error: Only show errors
#			Nothing: Don't show any output
#			Minimal: Only use minimal logging
#			Basic: This is the default basic logging level
#			Detailed: Give detailed logging output
#			Debug: For debugging purposes, very detailed output.
#			Rowlevel: Logging at a row level, this can generate a lot of data.
#
# Control file: run_param.cfg - Pass named parameters to PDI jobs
#
#=============================================================================================
