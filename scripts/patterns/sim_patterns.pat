# ###########################################################################
# Patterns file
#
# This file defines that patterns which are used to identify an error
# or a warning in a simulation log file.
#
# This file can be used as a base and can be customized depending of 
# user needs
#
# Some regular expression below are used for UVM log file
# 
# ###########################################################################
EOT,TEST COMPLETED
ERROR,UVM_ERROR.*\@
ERROR,UVM_FATAL.*\@
ERROR,Fatal:
ERROR,\* Error
ERROR,Error:
WARNING,UVM_WARNING.*\@
WARNING,Warning:
WARNING,Warning.*at
RESET,RESET DONE.*0 active
SEED,sv_seed ([0-9]+)
EOT,Note: \$finish
ERROR,Fatal error
ERROR,Unrecognized parameter name:
ERROR,Unexpected characters after parameter value:
ERROR,Quoted string not terminated by end of line
ERROR,Model qualifiers not yet implemented for
ERROR,Model qualifiers not allowed for
ERROR,Invalid include filespec:
ERROR,Instance qualifiers not yet implemented for
ERROR,Instance qualifiers not allowed with
