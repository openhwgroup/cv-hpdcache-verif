#!/bin/csh -f
# ----------------------------------------------------------------------------
# Copyright 2024 CEA*
# *Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------------------------------------------------------

setenv PROJECT_DIR ${cwd}

## Parse optional user setup file
if ( -f ${PROJECT_DIR}/setup.local.csh ) then
	source ${PROJECT_DIR}/setup.local.csh
endif

################################################
# Setup the design's env vars
################################################

## Set the project specific environment variables
echo ">> Setting environment variables"
if ( -f ${PROJECT_DIR}/config/setup_env.design.csh ) then
	source ${PROJECT_DIR}/config/setup_env.design.csh
endif
