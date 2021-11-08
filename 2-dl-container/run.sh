#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source dlc.conf

if [ -z "$1" ]; then
        MODE=-d
else
        MODE=-it
fi

echo "docker container run ${RUN_OPTS} ${MODE} ${REGISTRY}${IMAGE}${TAG} $@"
docker container run ${RUN_OPTS} ${MODE} ${REGISTRY}${IMAGE}${TAG} $@

