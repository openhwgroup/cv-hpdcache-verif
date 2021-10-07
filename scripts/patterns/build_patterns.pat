# ###########################################################################
# Patterns file for use with scanlogs.
#
# This file defines the patterns which are used for analyzing the log
# file produced when compiling a design for Questa.
# ###########################################################################

# Define patterns which indicate errors
ERROR_NUM,Errors: ([0-9]+)
ERROR,\* No rule to make target
ERROR,\*\* Error
ERROR,\*\*\* ERROR

# Define patterns which indicate warnings
WARNING,\* Warning

# Define patterns which indicate the build (vopt) has completed
EOT,Optimized design name is

# Define patterns for grouping error messages in a summary table
GROUP,(vopt-[0-9]+),QUESTA_ELABORATE
GROUP,(vcom-[0-9]+),QUESTA_COMPILE
GROUP,(vlog-[0-9]+),QUESTA_COMPILE
