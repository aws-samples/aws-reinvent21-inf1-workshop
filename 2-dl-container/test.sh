#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source dlc.conf

echo "Testing ${IMAGE} ..."

docker container run ${RUN_OPTS} -it --rm ${REGISTRY}${IMAGE}${TAG} sh -c "for t in \$(ls /test*.sh); do echo Running test \$t; \$t; done;"

