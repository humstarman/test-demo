#!/bin/bash

set -e

START=$(date +%s)
FLAG=$1
WAIT=3
STAGE=0
STAGE_FILE=stage.main
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
  echo "To use this auto deployment tool, master and node (nonessential) info should be offered."
  echo "As an instance:"
  echo "- generate a file named master.csv (node.csv),"
  echo "- master (node) IPs are in terms of CSV, as {MASTER_IP_1},{MASTER_IP_2},{MASTER_IP_3}."
  echo "-"
  echo "In addition, if all the hosts staisfy that:"
  echo "=== all the ssh usernames are root, "
  echo "=== all the ssh passwords are the same."
  echo "put the password into ./passwd.log"
  echo "-"
  echo "After master, node and password info configured, run this script."
  if [[ "0" == "$INIT" ]]; then
    echo "---"
    echo "---"
    echo "---"
    echo "If you run the script for the first time,"
    echo "the help document shown for default."
    echo "Re-run the script to function."
    echo "---"
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
fi
#curl -s https://raw.githubusercontent.com/humstarman/kube-install/master/test.sh | /bin/bash
if false; then
if [ "init" == "$1" ]; then
  #curl -s https://raw.githubusercontent.com/humstarman/kube-install/master/test.sh $2 | /bin/bash - $2
  curl -s -o /tmp/test.sh https://raw.githubusercontent.com/humstarman/kube-install/master/test.sh
  chmod +x /tmp/test.sh
  /tmp/test.sh $2
elif [ "join" == "$1" ]; then
  echo 1
else
  echo " - Usage:"
  echo "use 'init' to deploy a master;"
  echo "use 'join' to deploy a node."
fi
fi
PROJECT=$0
PROJECT=${PROJECT##*/}
PROJECT=${PROJECT%%.*}
URL=https://raw.githubusercontent.com/humstarman/${PROJECT}-main/master
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
[[ "$(cat ./${STAGE_FILE})" == "0" ]] && curl -s $URL/check-master-node.sh | /bin/bash
[[ "$(cat ./${STAGE_FILE})" == "0" ]] && curl -s $URL/check-ansible.sh | /bin/bash
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
  curl -s $URL/mk-ansible-available.sh | /bin/bash
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - connectivity checked."
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - environment checked."
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - prepare to install."
  ## 1 stop selinux
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - shutdown Selinux."
  curl -s -o ./shutdown-selinux.sh $URL/shutdown-selinux.sh
  ansible all -m script -a ./shutdown-selinux.sh
  ## 2 stop firewall
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - stop firewall."
  curl -s -o ./stop-firewall.sh $URL/stop-firewall.sh
  ansible all -m script -a ./stop-firewall.sh
  ## 3 mkdirs
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - prepare directories."
  curl -s $URL/batch-mkdir.sh | /bin/bash
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
  curl -s $URL/cluster-environment-variables.sh | /bin/bash
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
  curl -s $URL/generate-ca-pem.sh | /bin/bash
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
  curl -s $URL/deploy-etcd.sh | /bin/bash
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
  curl -s $URL/install-k8s.sh | /bin/bash
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
  curl -s $URL/deploy-kubectl.sh | /bin/bash
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
  curl -s $URL/deploy-flanneld.sh | /bin/bash
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 7 deploy master 
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  curl -s $URL/deploy-master.sh | /bin/bash
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
  curl -s $URL/deploy-node.sh | /bin/bash
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 9 clearance 
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - clearance ... "
  mkdir -p ./tmp
  ls | grep -v -E "kube-install.sh|*.csv|${STAGE_FILE}|tmp" | xargs -I {} mv {} ./tmp
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - temporary files have been moved to ./tmp. "
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - you can delete ./tmp for free. "
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# ending
[ -z "$N_NODE" ] && N_NODE=0
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
sleep $WAIT 
exit 0
