#!/bin/bash

set -e

START=$(date +%s)
FLAG=$1
WAIT=3
STAGE=0
STAGE_FILE=stage.update
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
  echo " - This script is to update the permissions, including:"
  echo " - CA"
  echo " - ETCD"
  echo " - Admin of Kubectl & kubeconfig file of Kubectl"
  echo " - Flanneld"
  echo " - Kubernetes"
  echo " - Kubelet bootstrapping kubeconfig"
  echo " - Kube-proxy & kubeconfig file of kube-proxy"
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
BRANCH=master
URL=https://raw.githubusercontent.com/humstarman/${PROJECT}-impl/${BRANCH}
TOOLS=${URL}/tools
THIS_FILE=$0
PREFIX=$THIS_FILE
PREFIX=${PREFIX##*/}
PREFIX=${PREFIX%.*}
MAIN=${URL}/${PREFIX}

# 0 clear expired permission & check cfssl tool
if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
  curl -s $TOOLS/check-k8s-cluster.sh | /bin/bash 
  curl -s $TOOLS/restore-info-from-backup.sh | /bin/bash
  curl -s $TOOLS/check-needed-files.sh | /bin/bash
  curl -s $TOOLS/check-ansible.sh | /bin/bash 
  getScript $MAIN clear-expired-pem.sh
  ansible all -m script -a ./clear-expired-pem.sh
  curl -s $MAIN/check-cfssl.sh | /bin/bash 
fi

# 1 CA
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/update-ca-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 2 etcd 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/update-etcd-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 3 kubectl 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/update-kubectl-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 4 flanneld 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/update-flanneld-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 5 kubernetes 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/update-kubernetes-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 6 kubelet 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/update-kubelet-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 7 kube-proxy 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/update-kube-proxy-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 8 restart services 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/restart-svc.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 9 clearance 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - Kubernetes permmisson has been updated. "
  curl -s $TOOLS/clearance.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# ending
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - As updating permmisons, re-approving certificate is needed."
echo " - sleep $WAIT sec, then apporve."
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
for i in $(seq -s " " 1 $WAIT); do
  sleep $WAIT
  ./${FILE}
done
echo " - now, use 'kubectl get node' to check the status."
kubectl get node
echo " - if there is/are NotReady node/nodes, use 'kubectl get csr' to check the register status."
echo " - use ./$FILE to approve certificate."
exit 0
