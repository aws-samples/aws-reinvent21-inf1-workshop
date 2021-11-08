#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source ./fun.sh

for index in ${!DOE_INSTANCE_TYPES[@]}; do
        INSTANCE_TYPE_NAME=$(echo ${DOE_INSTANCE_TYPES[$index]} | sed -e 's/\./-/g')
        BATCH_JOB_QUEUE_NAME=${BATCH_NAME}-queue-${DOE_JOB_TYPES[$index]}-${INSTANCE_TYPE_NAME}
        logs $@
done

