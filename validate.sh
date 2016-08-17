#!/bin/bash

# -----------------------------------------------------------------------------
# Common variables
# -----------------------------------------------------------------------------
err_count=0
warn_count=0

# minimum versions for supporting tools
min_java_version=7
min_git_version=2
min_node_version=4
min_npm_version=2
min_mvn_version=3

min_rec_mem=8 #minimum recommended memory
min_req_mem=4 #minimum required memory
min_num_core=2 # minumum required number of cores/processores (no distinction for the sake of simplicity)

max_time_mvn_task=200 # maximum amount of time to get some artifacts from the BB repo
lim_time_mvn_task=500 # limit amount of time to get some artifacts from the BB repo

# -----------------------------------------------------------------------------
# Common functions
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Log function used to display messages
# Parameters: $1 severity (ERROR,INFO,WARNING)
#             $2 message
# Return: none
# -----------------------------------------------------------------------------
function log {
	color_mod="\033[1;49m"

	if [[ $1 == "ERROR" ]] 
	then
		color_mod="\033[1;31m"
		let err_count=err_count+1
	elif [[ $1 == "HEAD" ]] 
	then
		color_mod="\033[1;32m"
	elif [[ $1 == "WARNING" ]] 
	then
		color_mod="\033[1;93m"
		let warn_count=warn_count+1
	fi		

	echo -e "$color_mod $(date +'%D %T') [$1] $2\033[0m" 
}

# -----------------------------------------------------------------------------
# Check environment variables
# Return: 0 OK, != 0 error
# -----------------------------------------------------------------------------
function check_variables {
	var_error=false
	# Java Home variable
	if [ -z "$JAVA_HOME" ]
	then
   		log "ERROR" "\tEmpty JAVA_HOME variable. Please set this environment variable to your JDK directory. To find out more on how to configure it, please refer to the documentation available at http://bit.ly/cxplp"
   		var_error=true
	fi

	# M2_HOME variable
	if [ -z "$M2_HOME" ]
	then
	   log "ERROR" "\tEmpty M2_HOME variable. Please set this environment variable to your MAVEN directory. To find out more on how to configure it, please refer to the documentation available at http://bit.ly/cxplp"
	   var_error=true
	fi

	# M2 variable
	if [ -z "$M2" ]
	then
	   log "ERROR" "\tEmpty M2 variable. Please set this environment variable to your MAVEN bin directory. To find out more on how to configure it, please refer to the documentation available at http://bit.ly/cxplp"
	   var_error=true
	fi

	# MAVEN_OPTS variable
	if [ -z "$MAVEN_OPTS" ]
	then
	   log "ERROR" "\tEmpty MAVEN_OPTS. To find out more on how to configure it, please refer to the documentation available at http://bit.ly/cxplp"
	   var_error=true
	fi	
	if $var_error; then
		return -1
	fi
	log "INFO" "\tJAVA_HOME=$JAVA_HOME"
	log "INFO" "\tM2_HOME=$M2_HOME"
	log "INFO" "\tM2=$M2"
	log "INFO" "\tMAVEN_OPTS=$MAVEN_OPTS"
	return 0
}

# -----------------------------------------------------------------------------
# Check java installation
# Return: 0 OK, != 0 error
# -----------------------------------------------------------------------------
function check_java_installation {
	java_binary=$(which java)

	if [ -z $java_binary ]
	then
  		log "ERROR" "\tJava runtime is not present in the path. Please, fix your PATH variable"
  		return -1
	fi

	java_folder=$(echo $java_binary | sed 's/\/bin\/java$//g')
	if [ $JAVA_HOME != $java_folder ]
	then
   		log "ERROR" "\tJava runtime conflict: Your java binary present in the path is pointing to a different java installation. Please check your PATH and JAVA_HOME variables"  
   		return -1
	fi

	# Checking Java version
	java_version_pretty=$(java -version 2>&1 | head -1 | sed "s/java version//g" | sed 's/"//g' )
	java_version=$(echo $java_version_pretty | sed "s/.*\.\(.*\)\..*/\1/g")

	if (( java_version < $min_java_version )); then
		log "ERROR" "\tUpdate your JDK installation (current is $java_version_pretty) to at least the version $min_java_version"
		return -1
	fi
	log "INFO" "\tJava version: $java_version_pretty"
	return 0
}

# -----------------------------------------------------------------------------
# Check git installation
# Return: 0 OK, != 0 error
# -----------------------------------------------------------------------------
function check_git_installation {

	git_binary=$(which git)

	if [ -z $git_binary ]
	then
  		log "ERROR" "\tgit binary is not present in the path. Please, check the PATH variable"
  		return -1
	fi

    git_version_pretty=$(git --version | sed "s/git version//g")
	git_version=$(echo $git_version_pretty | sed "s/\([0-9]*\)\..*/\1/g")
	
	if (( git_version < $min_git_version )); then
		log "ERROR" "\tUpdate your git to the latest version, greater than $min_git_version (current is $git_version_pretty)"
		return -1
	fi
	log "INFO" "\tgit version: $git_version_pretty"
	return 0
}

# -----------------------------------------------------------------------------
# Check node installation
# Return: 0 OK, != 0 error
# -----------------------------------------------------------------------------
function check_node_installation {

	node_binary=$(which node)

	if [ -z $node_binary ]
	then
  		log "WARNING" "\tnode binary is not present in the path. Please, check the PATH variable"
  		return 0
	fi

    node_version_pretty=$(node --version) 
	node_version=$(echo $node_version_pretty | sed "s/v//g" | sed "s/\([0-9]*\)\..*/\1/g")
	
	if (( node_version < $min_node_version )); then
		log "WARNING" "\tUpdate your node to the latest version (minimum is $min_node_version) (current is $node_version_pretty)"
		return 0
	fi

	log "INFO" "\tnode version: $node_version_pretty"

	return 0
}

# -----------------------------------------------------------------------------
# Check npm installation
# Return: 0 OK, != 0 error
# -----------------------------------------------------------------------------
function check_npm_installation {

	npm_binary=$(which npm)

	if [ -z $npm_binary ]
	then
  		log "WARNING" "\tnpm binary is not present in the path. Please, check the PATH variable"
  		return 0
	fi

    npm_version_pretty=$(npm --version)
	npm_version=$(echo $npm_version_pretty | sed "s/\..*//g")

	if (( npm_version < $min_npm_version )); then
		log "WARNING" "\tupdate your npm to the latest version (min  is $min_npm_version, current is $npm_version_pretty)"
		return 0
	fi
	log "INFO" "\tnpm version: $npm_version_pretty"
	return 0
}

# -----------------------------------------------------------------------------
# Check bb installation
# Return: 0 OK, != 0 error
# -----------------------------------------------------------------------------
function check_bb_installation {

	bb_binary=$(which bb)

	if [ -z $bb_binary ]
	then
  		log "WARNING" "\tbb binary is not present in the path. Install the latest bb-cli into your machine"
  		return 0
	fi

    bb_version_pretty=$(bb | grep Version | sed "s/Version://g") 
	
	log "INFO" "\tbb version: $bb_version_pretty"
	return 0
}


# -----------------------------------------------------------------------------
# Check mvn installation
# Return: 0 OK, != 0 error
# -----------------------------------------------------------------------------
function check_mvn_installation {
	mvn_binary=$(which mvn)

	if [ -z $mvn_binary ]
	then
  		log "ERROR" "\tmaven binary is not present in the path"
  		return -1
	fi

	#Checking maven version
	mvn_version_pretty=$(mvn --version 2>&1 | grep "Apache Maven" | sed "s/(.*)//g" | sed "s/Apache Maven//g")
	mvn_version=$(echo $mvn_version_pretty | sed "s/\([0-9]*\)\..*/\1/g")

	if (( mvn_version < $min_mvn_version )); then
		log "ERROR" "\tUpdate your maven installation to the latest version (minimum is $min_mvn_version)"
		return -1
	fi
	log "INFO" "\tmaven version: $mvn_version_pretty"
	return 0
}

function check_mvn_repo {
	rm -rf repo-test 2> /dev/null
	git clone https://github.com/marciofk/repo-test.git 2> /dev/null
	if [ $? -ne 0 ]; then
    	log "ERROR" "\tError cloning test project. Please check your network settings"
    	return -1
	fi
	cd repo-test
	log "INFO" "\tTesting mvn connectivity. It may take some time"

	before=$(date +%s)
	mvn -Dmaven.repo.local=localrepo dependency:purge-local-repository clean install >/dev/null 2>&1
	if [ $? -ne 0 ]; then
    	log "ERROR" "\tError downloading repositories. Check your maven configuration and network settings"
    	return -1
	fi
	after=$(date +%s)
	let total_time=after-before
	cd ..
	log "INFO" "\tTotal time: $total_time seconds"

	if (( total_time > $max_time_mvn_task && total_time < $lim_time_mvn_task)); then
		log "WARNING" "\tThe amount of time to download some artifacts took some time ($total_time sec). Please check your internet connection"
	fi

	if (( total_time >= $lim_time_mvn_task)); then
		log "ERROR" "\tThe amount of time to download some artifacts took too long ($total_time sec). Please check your internet connection"
	fi

	return 0
}

function check_hardware {
	memory=$(system_profiler SPHardwareDataType | grep "  Memory:" | sed "s/Memory://g" | sed "s/GB//g")

	if (( $memory < $min_rec_mem && memory >= $min_req_mem))
	then
   		log "WARNING" "\tThe available memory of $memory GB is below the minimum recommended memory ($min_rec_mem GB)"
	fi

	if (( $memory < $min_req_mem))
	then
   		log "ERROR" "\tThe available memory of $memory GB is below the minimum required memory ($min_req_mem GB)"
	fi

	# Checking processors
	cores=$(system_profiler SPHardwareDataType | grep Cores: | sed "s/.*://g")
	processor=$(system_profiler SPHardwareDataType | grep Processors: | sed "s/.* //g")

	if (( cores * processor < $min_num_core))
	then
   		log "WARNING" "\tYour processor configuration is below the minimum requirement. We recommend using a multicore/multiprocessor machine"
	fi
	
	log "INFO" "\tMemory: $memory GB"
	log "INFO" "\t# of cores: $cores"
	log "INFO" "\t# of processors: $processor"

	return 0;
}

# -----------------------------------------------------------------------------
# Validation body
# -----------------------------------------------------------------------------

log "HEAD" "--------------------------------------------------------------"
log "HEAD" "CXP Bootcamp - ILT Environment Checker for MAC OSX version 1.0"
log "HEAD" "--------------------------------------------------------------\n"

log "HEAD" "Checking environment variables"
check_variables

if [ $? -ne 0 ]; then
    log "INFO" "\tError getting environment variables. Please check the console."
fi

log "HEAD" "Checking Java installation"
check_java_installation

if [ $? -ne 0 ]; then
    log "INFO" "\tError checking the Java installation. Please check the console."
fi

log "HEAD" "Checking Git installation"
check_git_installation

if [ $? -ne 0 ]; then
    log "INFO" "\tError checking the git installation. Please check the console."
fi

log "HEAD" "Checking Maven installation"
check_mvn_installation

if [ $? -ne 0 ]; then
    log "INFO" "\tError checking the maven installation. Please check the console."
fi

log "HEAD" "Checking Node installation"
check_node_installation

if [ $? -ne 0 ]; then
    log "INFO" "\tError checking the node installation. Please check the console."
fi

log "HEAD" "Checking Npm installation"
check_npm_installation

if [ $? -ne 0 ]; then
    log "INFO" "\tError checking the npm installation. Please check the console."
fi

log "HEAD" "Checking bb installation"
check_bb_installation

if [ $? -ne 0 ]; then
    log "INFO" "\tError checking the bb installation. Please check the console."
fi

log "HEAD" "Checking Maven repository access"
check_mvn_repo

if [ $? -ne 0 ]; then
    log "INFO" "\tError connecting the repository. Please check the console."
fi

log "HEAD" "Checking hardware"
check_hardware

if [ $? -ne 0 ]; then
    log "INFO" "\tError checking the hardware. Please check the console."
fi

log "HEAD" "Error count: $err_count"
log "HEAD" "Warning count: $warn_count"
log "HEAD" "Finished"

#EOF
