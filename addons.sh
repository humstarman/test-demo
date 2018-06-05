#!/bin/bash

set -e

START=$(date +%s)
FLAG=$1
WAIT=3
STAGE=0
STAGE_FILE=stage.addons
if [ ! -f ./${STAGE_FILE} ]; then
  INIT=0
  touch ./${STAGE_FILE}
  echo 0 > ./${STAGE_FILE} 
  FLAG="--help"
else
  INIT=1
fi
if false; then
INIT=1
FLAG=$1
if [[ "0" == "$INIT" ]]; then
  sed -i s/"^INIT=0$"/"INIT=1"/g $0
  FLAG="--help"
fi
fi
function getScript(){
  URL=$1
  SCRIPT=$2
  curl -s -o ./$SCRIPT $URL/$SCRIPT
  chmod +x ./$SCRIPT
}
if [[ "-h" == "$FLAG" || "--help" == "$FLAG" ]]; then
  echo " - Usage:"
  echo " - This script is for the installation of:"
  echo " - CoreDNS"
  echo " - Dashboard"
  echo " - Nginx Ingress"
  echo "-"
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
PROJECT=$0
PROJECT=${PROJECT##*/}
PROJECT=${PROJECT%%.*}
# https://raw.githubusercontent.com/humstarman/test-demo-addons/master/coredns/coredns.yaml
URL=https://raw.githubusercontent.com/humstarman/${PROJECT}-addons/master

if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
  curl -s $URL/check-k8s-cluster.sh | /bin/bash 
fi

# 1 CoreDNS
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  kubectl create -f $URL/coredns/coredns.yaml
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - CoreDns deployed."
  echo $STAGE > ./${STAGE_FILE}
fi

# 2 Dashboard
