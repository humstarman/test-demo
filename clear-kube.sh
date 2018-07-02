#!/bin/bash

set -e

START=$(date +%s)
FLAG=$1
WAIT=3
STAGE=0
STAGE_FILE=stage.clear
if [ ! -f ./${STAGE_FILE} ]; then
  INIT=0
  touch ./${STAGE_FILE}
  TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
  echo $TOKEN > ./${STAGE_FILE} 
  FLAG="--help"
else
  INIT=1
fi
function getScript(){
  URL=$1
  SCRIPT=$2
  curl -s -o ./$SCRIPT $URL/$SCRIPT
  chmod +x ./$SCRIPT
}
if [[ "-h" == "$FLAG" || "--help" == "$FLAG" ]]; then
  echo " - Dangerous script !!!"
  echo " - This script is to used to clear Kubenetes in this cluster !!!"
  echo " - Dangerous script !!!"
  echo " - Dangerous script !!!"
  echo " -"
  echo " - use this token: "
  [ -z "$TOKEN" ] && TOKEN=$(cat ./${STAGE_FILE})
  echo " - $TOKEN"
  echo " - as the input of this script, and MUST on Kubernetes MASTER to function."
  if [[ "0" == "$INIT" ]]; then
    echo "---"
    echo "---"
    echo "---"
    echo "If you run the script for the first time,"
    echo "the help document shown for default."
    echo "Re-run the script to function."
    echo "---"
  fi
  sleep $WAIT
  exit 0
fi
if [[ "$@" != "$(cat ./${STAGE_FILE})" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - token mismatched !!!"
  sleep $WAIT
  exit 1
fi
PROJECT="test-demo"
BRANCH=master
URL=https://raw.githubusercontent.com/humstarman/${PROJECT}-impl/${BRANCH}
TOOLS=${URL}/tools
THIS_FILE=$0
PREFIX=$THIS_FILE
PREFIX=${PREFIX##*/}
PREFIX=${PREFIX%.*}
MAIN=${URL}/${PREFIX}

# 0 set env 
curl -s $TOOLS/restore-info-from-backup.sh | /bin/bash
curl -s $TOOLS/check-needed-files.sh | /bin/bash
curl -s $TOOLS/check-ansible.sh | /bin/bash 

# 1 clearance 
COMPONENT="node"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - clear $COMPONENT ... "
getScript $MAIN clear-${COMPONENT}.sh
ansible all -m script -a ./clear-${COMPONENT}.sh
COMPONENTS="master etcd"
for COMPONENT in $COMPONENTS; do
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - clear $COMPONENT ... "
  getScript $MAIN clear-${COMPONENT}.sh
  ansible master -m script -a ./clear-${COMPONENT}.sh
done

# ending
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - Kubernetes cluster cleared."
exit 0
