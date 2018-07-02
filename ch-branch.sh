#!/bin/bash
set -e
B=$1
if [ -z "$B" ]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - input the branch wanted to be replaced !!!"
  sleep 3
  exit 1
fi
THIS_FILE=$0
THIS_FILE=${THIS_FILE##*/}
TARGET="BRANCH="
find ./ -type f | grep -v $THIS_FILE |xargs sed -i "/$TARGET/ c ${TARGET}${B}"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - branch change to ${B}"
exit 0
