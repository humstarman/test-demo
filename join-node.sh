#!/bin/bash

set -e

# set env
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
URL=https://raw.githubusercontent.com/humstarman/${PROJECT}-impl/master
TOOLS=${URL}/tools
MAIN=${URL}/join-node

# 0 check environment 
if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
  curl -s $TOOLS/check-k8s-cluster.sh | /bin/bash
  curl -s $TOOLS/check-needed-files.sh | /bin/bash 
  curl -s $TOOLS/check-new-one.sh | /bin/bash 
  curl -s $TOOLS/check-ansible.sh | /bin/bash 
  curl -s $TOOLS/mk-ansible-available.sh | /bin/bash
  ## 1 shutdown selinux
  curl -s -o ./shutdown-selinux.sh $TOOLS/shutdown-selinux.sh
  ansible new -m script -a ./shutdown-selinux.sh
  ## 2 stop firewall
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - stop firewall."
  curl -s -o ./stop-firewall.sh $TOOLS/stop-firewall.sh
  ansible new -m script -a ./stop-firewall.sh
  ## 3 mkdirs
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - prepare directories."
  curl -s $MAIN/batch-mkdir.sh | /bin/bash
fi

# 1 set env 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/cluster-environment-variables.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 2 cp CA pem
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/cp-ca-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 3 prepare kubernetes node componenets
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/cp-kubernetes-node-components.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 4 cp kubectl 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/cp-kubectl.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 5 deploy flanneld 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $URL/deploy-flanneld.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 5 deploy node 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $URL/deploy-node.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 6 clearance 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $TOOLS/clearance.sh | /bin/bash
  echo $STAGE > ./${STAGE_FILE}
fi

# ending
[ -z "$N_NODE" ] && N_NODE=0
TOTAL=$[${N_MASTER}+${N_NODE}]
END=$(date +%s)
ELAPSED=$[$END-$START]
MINUTE=$[$ELAPSED/60]
NEW=$(sed s/","/" "/g ./new.csv)
N_NEW=$(echo $NEW | wc -w)
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - summary: "
if [[ "1" == "N_NEW" ]]; then
  echo " - add only one new node into Kubernetes cluster elapsed: $ELAPSED sec, approximately $MINUTE ~ $[$MINUTE+1] min."
else
  echo " - add $N_NEW new nodes into Kubernetes cluster elapsed: $ELAPSED sec, approximately $MINUTE ~ $[$MINUTE+1] min."
fi
echo " - Previous Kubernetes paltform: "
echo " - Total nodes: $TOTAL"
echo " - With masters: $N_MASTER"
echo " --- "
TOTAL=$[${TOTAL}+${N_NEW}]
echo " - Current Kubernetes paltform: "
echo " - Total nodes: $TOTAL"
echo " - With masters: $N_MASTER"
FILE=approve-pem.sh
if [ ! -f "$FILE" ]; then
  cat > $FILE << EOF
#!/bin/bash
CSRS=\$(kubectl get csr | grep Pending | awk -F ' ' '{print \$1}')
if [ -n "\$CSRS" ]; then
  for CSR in \$CSRS; do
    kubectl certificate approve \$CSR
  done
fi
EOF
  chmod +x $FILE
fi
echo " - For a little while, use the script ./$FILE to approve kubelet certificate."
echo " - use 'kubectl get csr' to check the register."
## re-set env
curl -s $TOOLS/re-set-env.sh | /bin/bash
## make backup
THIS_DIR=$(cd "$(dirname "$0")";pwd)
nohup curl -s $TOOLS/mk-backup.sh | /bin/bash
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - backup import info from $THIS_DIR to /var/k8s/bak."
echo " - this process runs in backgroud, so no need to wait."
sleep $WAIT
exit 0
