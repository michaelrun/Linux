#!/usr/bin/bash

set -ex
LEGCY_IMAGE="legcykernelintdximage.qcow2"

ARGS=" -a ${LEGCY_IMAGE} -x"

# Setup guest environments
ARGS+=" --edit '/etc/default/grub:s/GRUB_DEFAULT=0/GRUB_DEFAULT=1>2/'"
ARGS+=" --run-command 'update-grub'"
echo "${ARGS}"
eval virt-customize "${ARGS}"
