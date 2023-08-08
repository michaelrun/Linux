#!/bin/bash

TD_IMG="./tdximage.qcow2"
ARGS=" -a ${TD_IMG} -x"
# Setup guest environments
#ARGS+=" --copy-in ./media:/root/tdx_test/"
#ARGS+=" --copy-in ./pbench.sh:/root/tdx_test/"
ARGS+=" --copy-in ./mysql_bench.sh:/root/tdx_test/"
ARGS+=" --copy-in ./cal.sh:/root/tdx_test/"
#ARGS+=" --copy-in ./vmlinuz-jammy:/root/"

echo "${ARGS}"
eval virt-customize "${ARGS}"
