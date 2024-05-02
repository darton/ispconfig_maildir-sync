#!/bin/bash

REMOTESERVER='192.168.1.1' #remote ispconfig ip address or fqdn name
DOMAINS=("example.com" "example.org" "example.net")

DEBUG=true
SCRIPT_DIR=$(dirname $(readlink -f "$0"))
SCRIPT_NAME=$(basename $0)

PID_FILE_NAME="$(basename -s .sh "$0").pid"
LOCK_FILE_PATH="${SCRIPT_DIR}/${PID_FILE_NAME}"

LOG_DIR="${SCRIPT_DIR}"
LOG_FILE_NAME="$(basename -s .sh "$0").log"
LOG_FILE_PATH="${LOG_DIR}/${LOG_FILE_NAME}"

MAILPATH='/var/vmail'

### Functions ###
Clean(){
trap '' INT TERM EXIT  # Clear traps
rm -f "${LOCK_FILE_PATH}"
Log "info" "Stop"
exit $?
}

Log(){
[[ -f "${LOG_FILE_PATH}" ]] || touch "${LOG_FILE_PATH}"
local message="${@:2}"
local flag="${1}"
local logdate=$(date +"%FT%T.%3N%:z")
MESSAGE_TEMPLATE="Time:${logdate} ScriptName:${SCRIPT_NAME} level:${flag~~} Message:${message}"
if [[ "${DEBUG}" == "true" ]]; then
  echo "${MESSAGE_TEMPLATE}" | tee -a "${LOG_FILE_PATH}"
else
  if [[ "${flag}" == "error" ]] || [[ "${flag}" == "info" ]]; then
    echo "${MESSAGE_TEMPLATE}" | tee -a "${LOG_FILE_PATH}"
  fi
fi
}

CreateLockFile(){
Log "info" "Start"
if [ -f "${LOCK_FILE_PATH}" ] && kill -0 $(cat "${LOCK_FILE_PATH}") 2> /dev/null;then
  Log "error" "Script is already running"
  exit 1
fi
echo $$ > "${LOCK_FILE_PATH}" || { Log "error" "Unable to create lock file"; exit 3; }
}

RemoveLockFile(){
rm -f "${LOCK_FILE_PATH}" || { Log "error" "Unable to remove lock file"; exit 4; }
}

MaildirSync(){
for domain in "${DOMAINS[@]}"; do
  for item in $(ssh "${REMOTESERVER}" "ls ${MAILPATH}/${domain}"); do
    rsync -aPv --compress --delete -e ssh "${REMOTESERVER}:${MAILPATH}/${domain}/${item}"/Maildir/ "${MAILPATH}/${domain}/${item}"/Maildir
  done
done
}

### Start ###
trap Clean INT TERM

CreateLockFile
MaildirSync
RemoveLockFile
