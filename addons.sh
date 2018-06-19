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
  echo " -"
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
PROJECT="test-demo"
# https://raw.githubusercontent.com/humstarman/test-demo-addons/master/coredns/coredns.yaml
URL=https://raw.githubusercontent.com/humstarman/${PROJECT}-impl/master
TOOLS=${URL}/tools
THIS_FILE=$0
PREFIX=$THIS_FILE
PREFIX=${PREFIX##*/}
PREFIX=${PREFIX%.*}
MAIN=${URL}/${PREFIX}

if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
  curl -s $TOOLS/check-k8s-cluster.sh | /bin/bash 
fi

# 1 CoreDNS
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  COMPONENT="coredns"
  kubectl create -f $MAIN/${COMPONENT}/coredns.yaml
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $COMPONENT deployed."
  echo $STAGE > ./${STAGE_FILE}
fi

# 2 Dashboard
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  COMPONENT="dashboard"
  COMPONENT_URL=$MAIN/$COMPONENT
  kubectl create -f $COMPONENT_URL/rbac.yaml
  kubectl create -f $COMPONENT_URL/configmap.yaml
  kubectl create -f $COMPONENT_URL/secret.yaml
  kubectl create -f $COMPONENT_URL/service.yaml
  kubectl create -f $COMPONENT_URL/controller.yaml
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $COMPONENT deployed."
  echo $STAGE > ./${STAGE_FILE}
fi

# 3 Prometheus 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  COMPONENT="prometheus"
  COMPONENT_URL=$MAIN/$COMPONENT
  kubectl create -f $COMPONENT_URL/manifests-all.yaml
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $COMPONENT deployed."
  echo $STAGE > ./${STAGE_FILE}
fi

# 4 nginx ingress
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  COMPONENT="ingress"
  COMPONENT_URL=$MAIN/$COMPONENT
  kubectl create -f $COMPONENT_URL/namespace.yaml
  kubectl create -f $COMPONENT_URL/rbac.yaml
  kubectl create -f $COMPONENT_URL/default-backend.yaml
  kubectl create -f $COMPONENT_URL/configmap.yaml
  kubectl create -f $COMPONENT_URL/tcp-services-configmap.yaml
  kubectl create -f $COMPONENT_URL/udp-services-configmap.yaml
  kubectl create -f $COMPONENT_URL/service.yaml
  kubectl create -f $COMPONENT_URL/with-rbac.yaml
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $COMPONENT deployed."
  echo $STAGE > ./${STAGE_FILE}
fi
