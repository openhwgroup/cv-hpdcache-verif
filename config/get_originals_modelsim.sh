#!/bin/bash
[[ -z $1 ]] && { echo "ERROR: missing target directory."; exit 1; }
[[ -z $1 ]] || { work_dir=$(readlink -f $1); }
[[ -z $2 ]] && { echo "ERROR: missing questa_version."; exit 1; }
[[ -z $2 ]] || { questa_version=$2; }
# Explicitely pass in Questa_PATH Variable
[[ -z $3 ]] && { echo "ERROR: missing questa_path in invocation of get_originals_modelsim.sh."; exit 1; }
[[ -z $3 ]] || { questa_home=$3; }
lib_suffix=$4;
echo "=================================================="
echo "==   Creation of modelsim.ini file              =="
echo "=================================================="
echo "  questa_version = ${questa_version}"
  origin_modelsim_file="${questa_home}/modelsim.ini"
  if [[ -f ${origin_modelsim_file} ]]
  then
    new_modelsim_file="${work_dir}/modelsim${lib_suffix}.ini"
    cp ${origin_modelsim_file} ${new_modelsim_file}
    chmod 775 ${new_modelsim_file}
    sed -i '/\[Library\]/ a\others = $PROJECT_DIR/config/modelsim.libs.ini' ${new_modelsim_file}
    sed -i '/^\s*;\s*CheckSynthesis/ a\CheckSynthesis = 1' ${new_modelsim_file}
    sed -i 's/^\s*Resolution\s*=.*$/Resolution = ps/' ${new_modelsim_file}
    sed -i '/^\s*;\s*WLFUseThreads/ a\WLFUseThreads = 1' ${new_modelsim_file}
    sed -i 's/^\s*;\s*StdArithNoWarnings.*/StdArithNoWarnings = 1/' ${new_modelsim_file}
    sed -i 's/^\s*;\s*NumericStdNoWarnings.*/NumericStdNoWarnings = 1/' ${new_modelsim_file}
	# remove the Memory keyword to allow the tracing of memory-like variables (2D arrays)
    sed -i 's/^\(WildcardFilter = .*\) Memory/\1/' ${new_modelsim_file}
    # remove built-in UVM libraries
    sed -i -e 's/^mtiUvm/#mtiUvm/' ${new_modelsim_file}
    sed -i -e 's/ mtiUvm//'        ${new_modelsim_file}
  else
    echo "  ERROR : ${origin_modelsim_file} doesn't exist"
    exit 1
  fi
echo "=================================================="
