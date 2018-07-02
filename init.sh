#!/bin/bash

set -e

START=$(date +%s)
WAIT=3
STAGE=0
STAGE_FILE=stage.init
if [ ! -f ./${STAGE_FILE} ]; then
  INIT=0
  touch ./${STAGE_FILE}
  echo 0 > ./${STAGE_FILE} 
else
  INIT=1
fi
getScript () {
  URL=$1
  SCRIPT=$2
  curl -s -o ./$SCRIPT $URL/$SCRIPT
  chmod +x ./$SCRIPT
}
show_help () {
cat << USAGE
usage: $0
  To use this auto deployment tool, master and node (nonessential) info should be offered.
  As an instance:
  - generate a file named master.csv (node.csv),
  - master (node) IPs are in terms of CSV, as {MASTER_IP_1},{MASTER_IP_2},{MASTER_IP_3}.
  -
  In addition, if all the hosts staisfy that:
  === all the ssh usernames are root,
  === all the ssh passwords are the same.
  put the password into ./passwd.log
  -
  After master, node and password info configured, run this script.
USAGE
if [[ "0" == "$INIT" ]]; then
  cat << USAGE
  ---
  ---
  ---
  If you run the script for the first time,
  the help document shown for default.
  Re-run the script to function.
  ---
USAGE
  FILE=master.csv.tmpl
  if [ ! -f "$FILE" ]; then
    touch $FILE 
    echo "1.1.1.1,1.1.1.2,1.1.1.3" > $FILE
    sed -i s/" "/","/g $FILE
  fi
  FILE2=node.csv.tmpl
  [ -f "$FILE2" ] || cp $FILE $FILE2 
  FILE=passwd.log.tmpl
  if [ ! -f "$FILE" ]; then 
    touch $FILE
    echo "ssh-passwod" > $FILE
  fi
fi
sleep $WAIT
exit 0
}
if [[ "0" == "$INIT" ]]; then
  show_help
fi  
# Get Opts
while getopts "h" opt; do 
    case "$opt" in
    h)  show_help
        ;;
    ?)
        echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - unkonw argument."
        exit 1
        ;;
    esac
done
PROJECT="test-demo"
BRANCH=master
URL=https://raw.githubusercontent.com/humstarman/${PROJECT}-impl/${BRANCH}
TOOLS=${URL}/tools
THIS_FILE=$0
PREFIX=$THIS_FILE
PREFIX=${PREFIX##*/}
PREFIX=${PREFIX%.*}
MAIN=${URL}/${PREFIX}
###
#if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
###
[[ "$(cat ./${STAGE_FILE})" == "0" ]] && echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - checking environment ... "
# check curl & 
if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
  if [ ! -x "$(command -v curl)" ]; then
    if [ -x "$(command -v yum)" ]; then
      yum makecache
      yum install -y curl
    fi
    if [ -x "$(command -v apt-get)" ]; then
      apt-get update
      apt-get install -y curl
    fi
  fi
fi
[[ "$(cat ./${STAGE_FILE})" == "0" ]] && curl -s $TOOLS/check-master-node.sh | /bin/bash
[[ "$(cat ./${STAGE_FILE})" == "0" ]] && curl -s $TOOLS/check-ansible.sh | /bin/bash
MASTER=$(sed s/","/" "/g ./master.csv)
#echo $MASTER
N_MASTER=$(echo $MASTER | wc | awk -F ' ' '{print $2}')
#echo $N_MASTER
[[ "$(cat ./${STAGE_FILE})" == "0" ]] && echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $N_MASTER masters: $(cat ./master.csv)."
NODE_EXISTENCE=true
if [ ! -f ./node.csv ]; then
  NODE_EXISTENCE=false
else
  if [ -z "$(cat ./node.csv)" ]; then
    NODE_EXISTENCE=false
  fi
fi
if $NODE_EXISTENCE; then
  NODE=$(sed s/","/" "/g ./node.csv)
  #echo ${NODE}
  N_NODE=$(echo $NODE | wc | awk -F ' ' '{print $2}')
  #echo $N_NODE
  [[ "$(cat ./${STAGE_FILE})" == "0" ]] && echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $N_NODE nodes: $(cat ./node.csv)."
else
  [[ "$(cat ./${STAGE_FILE})" == "0" ]] && echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - no node to install."
fi
# mk env file
FILE=info.env
if [ ! -f "$FILE" ]; then
  cat > $FILE << EOF
export MASTER="$MASTER"
export N_MASTER=$N_MASTER
export NODE_EXISTENCE=$NODE_EXISTENCE
export NODE="$NODE"
export N_NODE=$N_NODE
export URL=$URL
EOF
fi
###
if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
###
  curl -s $TOOLS/mk-ansible-available.sh | /bin/bash
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - connectivity checked."
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - environment checked."
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - prepare to install."
  ## 1 stop selinux
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - shutdown Selinux."
  curl -s -o ./shutdown-selinux.sh $TOOLS/shutdown-selinux.sh
  ansible all -m script -a ./shutdown-selinux.sh
  ## 2 stop firewall
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - stop firewall."
  curl -s -o ./stop-firewall.sh $TOOLS/stop-firewall.sh
  ansible all -m script -a ./stop-firewall.sh
  ## 3 mkdirs
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - prepare directories."
  curl -s $MAIN/batch-mkdir.sh | /bin/bash
###
fi
###

# 1 environment variables
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  ## 1 download scripts
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - config cluster environment variables ... "
  #getScript $URL cluster-environment-variables.sh
  curl -s $MAIN/cluster-environment-variables.sh | /bin/bash
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cluster environment variables configured. "
###
echo $STAGE > ./${STAGE_FILE}
fi
###

# 2 generate CA pem
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  curl -s $MAIN/generate-ca-pem.sh | /bin/bash
#getScript $URL generate-ca-pem.sh 
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 3 deploy ha etcd cluster
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  curl -s $MAIN/deploy-etcd.sh | /bin/bash
#getScript $URL deploy-etcd.sh
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 4 prepare kubernetes 
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
### at first, install Kubernetes
  curl -s $MAIN/install-k8s.sh | /bin/bash
#getScript $URL install-k8s.sh
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 5 deploy kubectl
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
### then deploy kubectl
  curl -s $MAIN/deploy-kubectl.sh | /bin/bash
#getScript $URL deploy-kubectl.sh
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 6 deploy flanneld
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  curl -s $MAIN/deploy-flanneld.sh | /bin/bash
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 7 deploy master 
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  curl -s $MAIN/deploy-master.sh | /bin/bash
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 8 deploy node
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
#getScript $URL deploy-node.sh
  curl -s $MAIN/deploy-node.sh | /bin/bash
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 9 clearance 
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  [ -f "./node.csv" ] || touch node.csv
  curl -s $TOOLS/clearance.sh | /bin/bash
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# ending
MASTER=$(sed s/","/" "/g ./master.csv)
N_MASTER=$(echo $MASTER | wc -w)
if [ ! -f ./node.csv ]; then
  N_NODE=0
else
  NODE=$(sed s/","/" "/g ./node.csv)
  N_NODE=$(echo $NODE | wc -w)
  [ -z "$N_NODE" ] && N_NODE=0
fi 
TOTAL=$[${N_MASTER}+${N_NODE}]
END=$(date +%s)
ELAPSED=$[$END-$START]
MINUTE=$[$ELAPSED/60]
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - summary: "
echo " - Kubernetes installation elapsed: $ELAPSED sec, approximately $MINUTE ~ $[$MINUTE+1] min."
echo " - Kubernetes paltform: "
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
## make backup
THIS_DIR=$(cd "$(dirname "$0")";pwd)
curl -s $TOOLS/mk-backup.sh | /bin/bash
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - backup important info from $THIS_DIR to /var/k8s/bak."
sleep $WAIT 
exit 0
