#!/bin/bash
set -e
B=$1
if [ -z "$B" ];
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - input the branch wanted to be replaced !!!"
  sleep 3
  exit 1
fi
TARGET="BRANCH="
find ./ -type f | xargs sed -i /"$TARGET"/ c "${TARGET}=${B}"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - branch change to ${B}"
exit 0
