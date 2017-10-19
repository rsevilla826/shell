#!/bin/sh

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
#
# PDI (Pentaho Data Integration) System return codes
# Internal Kitchen return codes:
#           0 : The job ran without a problem.
#           1 : Errors occurred during processing
#           2 : An unexpected error occurred during loading / running of the job
#           7 : The job couldn't be loaded from XML or the Repository
#           8 : Error loading steps or plugins (error in loading one of the plugins mostly)
#           9 : Command line usage printing
#
# Internal Pan return codes:
#           0 : The transformation ran without a problem.
#           1 : Errors occurred during processing
#           2 : An unexpected error occurred during loading / running of the transformation
#           3 : Unable to prepare and initialize this transformation
#           7 : The transformation couldn't be loaded from XML or the Repository
#           8 : Error loading steps or plugins (error in loading one of the plugins mostly)
#           9 : Command line usage printing
#
#==============================================================================================

### Setup Java Environment
export JAVA_HOME="/usr/local/bin/jdk1.8.0_72"
export PENTAHO_JAVA_HOME="/usr/local/bin/jdk1.8.0_72"

### Commandline Arguments
PDI_JOB=$1
LOG_LEVEL=${2:-Basic}
LOG_DATE=`date +'%Y%m%d'`

# Where is PDI
export RUN_PDI="/data/pentaho/data-integration"

### Variables
export BASE_DIR="/data/etl/prd_etl_process"
export BIN_DIR="${BASE_DIR}/bin"
export CFG_DIR="${BASE_DIR}/cfg"
export TRANS_DIR="${BASE_DIR}/trans"
export JOB_DIR="${BASE_DIR}/jobs"
export LOG_DIR="${BASE_DIR}/logs"
export CTL_FILE="run_param.cfg"

# Control variable values derived from run_param.cfg file
# RedShift
export HOST_EDW=`cat ${CFG_DIR}/${CTL_FILE} | awk '/'HOST_EDW'/ {print $2}'`
export PORT_EDW=`cat ${CFG_DIR}/${CTL_FILE} | awk '/'PORT_EDW'/ {print $2}'`
export DATABASE_EDW=`cat ${CFG_DIR}/${CTL_FILE} | awk '/'DATABASE_EDW'/ {print $2}'`
export LOGIN_EDW=`cat ${CFG_DIR}/${CTL_FILE} | awk '/'LOGIN_EDW'/ {print $2}'`
export PASS_EDW=`cat ${CFG_DIR}/${CTL_FILE} | awk '/'PASS_EDW'/ {print $2}'`

# MS SQL Server
export SQLSRV_HOST=`cat ${CFG_DIR}/${CTL_FILE} | awk '/'SQLSRV_HOST'/ {print $2}'`
export SQLSRV_PORT=`cat ${CFG_DIR}/${CTL_FILE} | awk '/'SQLSRV_PORT'/ {print $2}'`
export SQLSRV_USER=`cat ${CFG_DIR}/${CTL_FILE} | awk '/'SQLSRV_USER'/ {print $2}'`
export SQLSRV_PWD=`cat ${CFG_DIR}/${CTL_FILE} | awk '/'SQLSRV_PWD'/ {print $2}'`

# Jobs/Trans base directories
export JOBS=`cat ${CFG_DIR}/${CTL_FILE} | awk '/'JOBS'/ {print $2}'`
export TRANS=`cat ${CFG_DIR}/${CTL_FILE} | awk '/'TRANS'/ {print $2}'`

### Create lock file to prevent duplicate runs
if ls ${LOG_DIR}/${PDI_JOB}*.lock 1> /dev/null 2>&1; then
        /usr/bin/mutt -s "Aborting: Duplicate run detected for ${PDI_JOB} at `date`" email_me@replace_me.com < /dev/null
        exit 20
else
	touch ${LOG_DIR}/${PDI_JOB}.lock
fi

### Get PDI object type by extension
PDI_TYPE=`echo ${PDI_JOB} | awk -F . '{print $NF}'`
cd "${RUN_PDI}"

### Invoke either kitchen or pan to run PDI objects
if [ "${PDI_TYPE}" = "ktr" ]; then

	if [ ! -f ${TRANS_DIR}/${PDI_JOB} ]; then
		echo "ERROR: PDI Object ${PDI_JOB} does not exists" > ${LOG_DIR}/${PDI_JOB}_${LOG_DATE}.log 2>&1
		RV=20
	else
		${RUN_PDI}/pan.sh /file:${TRANS_DIR}/${PDI_JOB} /level:${LOG_LEVEL} /param:TRANS=${TRANS} /param:JOBS=${JOBS} /param:HOST_EDW=${HOST_EDW} /param:PORT_EDW=${PORT_EDW} /param:DATABASE_EDW=${DATABASE_EDW} /param:LOGIN_EDW=${LOGIN_EDW} /param:PASS_EDW=${PASS_EDW} /param:SQLSRV_HOST=${SQLSRV_HOST} /param:SQLSRV_PORT=${SQLSRV_PORT} /param:SQLSRV_USER=${SQLSRV_USER} /param:SQLSRV_PWD=${SQLSRV_PWD} /norep > ${LOG_DIR}/${PDI_JOB}_${LOG_DATE}.log 2>&1

		RV=$?
		# PAN will return the following possible codes
		if [ ${RV} -eq 0 ]; then
			RETURN_MSG="${PDI_JOB} - The transformation ran without a problem"
		elif [ ${RV} -eq 1 ]; then
			RETURN_MSG="${PDI_JOB} - Errors occurred during processing"
		elif [ ${RV} -eq 2 ]; then
			RETURN_MSG="${PDI_JOB} - An unexpected error occurred during loading / running of the transformation"
		elif [ ${RV} -eq 3 ]; then
			RETURN_MSG="${PDI_JOB} - Unable to prepare and initialize this transformation"
		elif [ ${RV} -eq 7 ]; then
			RETURN_MSG="${PDI_JOB} - The transformation couldn't be loaded from XML or the Repository"
		elif [ ${RV} -eq 8 ]; then
			RETURN_MSG="${PDI_JOB} - Error loading steps or plugins (error in loading one of the plugins mostly)"
		elif [ ${RV} -eq 9 ]; then
			RETURN_MSG="${PDI_JOB} - Command line usage printing"
		fi
		
	fi

elif [ "${PDI_TYPE}" = "kjb" ]; then

	if [ ! -f ${JOB_DIR}/${PDI_JOB} ]; then
		echo "ERROR: PDI Object ${PDI_JOB} does not exists" > ${LOG_DIR}/${PDI_JOB}_${LOG_DATE}.log 2>&1
		RV=30
	else

		${RUN_PDI}/kitchen.sh /file:${JOB_DIR}/${PDI_JOB} /level:${LOG_LEVEL} /param:TRANS=${TRANS} /param:JOBS=${JOBS} /param:HOST_EDW=${HOST_EDW} /param:PORT_EDW=${PORT_EDW} /param:DATABASE_EDW=${DATABASE_EDW} /param:LOGIN_EDW=${LOGIN_EDW} /param:PASS_EDW=${PASS_EDW} /param:SQLSRV_HOST=${SQLSRV_HOST} /param:SQLSRV_PORT=${SQLSRV_PORT} /param:SQLSRV_USER=${SQLSRV_USER} /param:SQLSRV_PWD=${SQLSRV_PWD} /norep > ${LOG_DIR}/${PDI_JOB}_${LOG_DATE}.log 2>&1

		RV=$?
		# Kitchen will return the following possible codes
		if [ ${RV} -eq 0 ]; then
			RETURN_MSG="${PDI_JOB} - The transformation ran without a problem"
		elif [ ${RV} -eq 1 ]; then
			RETURN_MSG="${PDI_JOB} - Errors occurred during processing"
		elif [ ${RV} -eq 2 ]; then
			RETURN_MSG="${PDI_JOB} - An unexpected error occurred during loading / running of the job"
		elif [ ${RV} -eq 7 ]; then
			RETURN_MSG="${PDI_JOB} - The job couldn't be loaded from XML or the Repository"
		elif [ ${RV} -eq 8 ]; then
			RETURN_MSG="${PDI_JOB} - Error loading steps or plugins (error in loading one of the plugins mostly)"
		elif [ ${RV} -eq 9 ]; then
			RETURN_MSG="${PDI_JOB} - Command line usage printing"
		fi
	fi

else
	echo "ERROR: Unknown PDI object type" > ${LOG_DIR}/${PDI_JOB}_${LOG_DATE}.log 2>&1
	RV=40
fi

if [ ${RV} -gt 0 ]; then
	echo "ERROR: $PDI_JOB abended with return code ${RV}" >> ${LOG_DIR}/${PDI_JOB}_${LOG_DATE}.log
	echo "PDI RETURN MESSAGE: Return code ${RV} - ${RETURN_MSG}" >> ${LOG_DIR}/${PDI_JOB}_${LOG_DATE}.log
	echo "**** TO RESTART THE JOB YOU MUST DELETE THE LOCK FILE ${LOG_DIR}/${PDI_JOB}.lock ****" >> ${LOG_DIR}/${PDI_JOB}_${LOG_DATE}.log 2>&1
	exit ${RV}
else
	echo "$PDI_JOB - END!!!" >> ${LOG_DIR}/${PDI_JOB}_${LOG_DATE}.log 2>&1
	echo "PDI RETURN MESSAGE: Return code ${RV} - ${RETURN_MSG}" >> ${LOG_DIR}/${PDI_JOB}_${LOG_DATE}.log
	
	# Remove lock file when complete
	rm -f ${LOG_DIR}/${PDI_JOB}.lock
fi
