#!/bin/bash

set -e

START=$(date +%s)
FLAG=$1
WAIT=3
STAGE=0
STAGE_FILE=stage.node
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
  echo " - This script is for joining node(s) to Kubernetes cluster."
  echo " ==="
  echo " - This script MUST run on a Kubernets MASTER !!!"
  echo " ==="
  echo " - The info about new node(s) should be offered."
  echo " - As an instance:"
  echo " - generate a file named new.csv,"
  echo " - new node IPs are in terms of CSV, as {IP_1},{IP_2},{IP_3}."
  echo " -"
  if [[ "0" == "$INIT" ]]; then
    echo "---"
    echo "---"
    echo "---"
    echo "If you run the script for the first time,"
    echo "the help document shown for default."
    echo "Re-run the script to function."
    echo "---"
    FILE=new.csv.tmpl
    if [ ! -f "$FILE" ]; then
      touch $FILE
      echo "1.1.1.1,1.1.1.2,1.1.1.3" > $FILE
      sed -i s/" "/","/g $FILE
    fi
  fi
  sleep $WAIT
  exit 0
fi
PROJECT="test-demo"
URL=https://raw.githubusercontent.com/humstarman/${PROJECT}-join-node/master

# check environment 
if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
  curl -s $URL/check-env.sh | /bin/bash 
  curl -s $URL/check-ansible.sh | /bin/bash 
fi

# 1 CA
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $URL/update-ca-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 2 etcd 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $URL/update-etcd-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 3 kubectl 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $URL/update-kubectl-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 4 flanneld 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $URL/update-flanneld-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 5 kubernetes 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $URL/update-kubernetes-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 6 kubelet 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $URL/update-kubelet-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 7 kube-proxy 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $URL/update-kube-proxy-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 8 restart services 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $URL/restart-svc.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 9 clearance 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - Kubernetes permmisson has been updated. "
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - clearance ... "
  mkdir -p ./tmp
  ls | grep -v -E "*.ba.sh|*.csv|stage.*|tmp" | xargs -I {} mv {} ./tmp
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - temporary files have been moved to ./tmp. "
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - you can delete ./tmp for free. "
  echo $STAGE > ./${STAGE_FILE}
fi
