#!/bin/bash

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
	elif [[ $1 == "TITLE" ]] 
	then
		color_mod="\033[1;32m"
	elif [[ $1 == "WARNING" ]] 
	then
		color_mod="\033[1;93m"
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
   		log "ERROR" "\tEmpty JAVA_HOME variable. Please set this environment variable to your JDK home directory"
   		var_error=true
	fi

	# M2_HOME variable
	if [ -z "$M2_HOME" ]
	then
	   log "ERROR" "\tEmpty M2_HOME variable. Please set this environment variable to your MAVEN home directory"
	   var_error=true
	fi

	# M2 variable
	if [ -z "$M2" ]
	then
	   log "ERROR" "\tEmpty M2 variable. Please set this environment variable to your MAVEN bin directory"
	   var_error=true
	fi

	# MAVEN_OPTS variable
	if [ -z "$MAVEN_OPTS" ]
	then
	   log "ERROR" "\tEmpty MAVEN_OPTS. Please set this environment variable"
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
	java_version_pretty=$(java -version 2>&1 | head -1 | sed "s/java version//g" | sed 's/"//g')
	java_version=$(echo $java_version_pretty | sed 's/"//g' | sed "s/\.//g" | sed "s/_.*//g")

	if (( java_version < 180 )); then
		log "ERROR" "\tUpdate your JDK installation to at least version 1.8"
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
  		echo "\tGit binary is not present in the path. Please, check the PATH variable"
  		return -1
	fi

    git_version_pretty=$(git --version | sed "s/git version//g")
	git_version=$(echo $git_version_pretty | sed "s/\.//g")
	
	if (( git_version < 200 )); then
		log "ERROR" "\tUpdate your git to the latest version"
		return -1
	fi
	log "INFO" "\tGit version: $git_version_pretty"
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
  		echo "\tMaven binary is not present in the path"
  		return -1
	fi

	#Checking maven version
	mvn_version=$(mvn --version 2>&1 | grep "Apache Maven" | sed "s/(.*)//g" | sed "s/Apache Maven//g" | sed "s/\.//g")
	mvn_version_pretty=$(mvn --version 2>&1 | grep "Apache Maven" | sed "s/(.*)//g")

	if (( mvn_version < 300 )); then
		log "ERROR" "\tUpdate your maven installation to the latest version"
		return -1
	fi
	log "INFO" "\tMaven version: $mvn_version_pretty"
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

	if (( total_time > 300 && total_time < 600)); then
		log "WARNING" "\tThe amount of time to download some artifacts took some time ($total_time sec). Please check your internet connection"
	fi

	if (( total_time >= 600)); then
		log "ERROR" "\tThe amount of time to download some artifacts took too long ($total_time sec). Please check your internet connection"
	fi

	return 0
}

function check_hardware {
	memory=$(system_profiler SPHardwareDataType | grep "  Memory:" | sed "s/Memory://g" | sed "s/GB//g")

	if (( memory < 8 && memory >= 4))
	then
   		log "WARNING" "\tThe available memory of $memory GB is below the minimum amount required (8 GB)"
	fi

	if (( memory < 4))
	then
   		log "ERROR" "\tThe available memory of $memory GB is below the minimum amount required (8 GB)"
	fi

	# Checking processors
	cores=$(system_profiler SPHardwareDataType | grep Cores: | sed "s/.*://g")
	processor=$(system_profiler SPHardwareDataType | grep Processors: | sed "s/.* //g")

	if (( cores * processor < 2))
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

log "TITLE" "Checking environment variables"
check_variables

if [ $? -ne 0 ]; then
    log "ERROR" "\tAborting validation. Please correct the errors and try again"
    exit -1
fi

log "TITLE" "Checking Java installation"
check_java_installation

if [ $? -ne 0 ]; then
    log "ERROR" "\tAborting validation. Please correct the errors and try again"
    exit -1
fi

log "TITLE" "Checking Git installation"
check_git_installation

if [ $? -ne 0 ]; then
    log "ERROR" "Aborting validation. Please correct the errors and try again"
    exit -1
fi

log "TITLE" "Checking Maven installation"
check_mvn_installation

if [ $? -ne 0 ]; then
    log "ERROR" "Aborting validation. Please correct the errors and try again"
    exit -1
fi

log "TITLE" "Checking Maven repository access"
check_mvn_repo

if [ $? -ne 0 ]; then
    log "ERROR" "Aborting validation. Please correct the errors and try again"
    exit -1
fi

log "TITLE" "Checking hardware"
check_hardware

if [ $? -ne 0 ]; then
    log "ERROR" "Aborting validation. Please correct the errors and try again"
    exit -1
fi

log "TITLE" "Finished"

