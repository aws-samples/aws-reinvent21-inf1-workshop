#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source dlc.conf

# Build Docker image
docker image build ${BUILD_OPTS} -t ${REGISTRY}${IMAGE}${TAG} -f Dockerfile-${PROCESSOR} .
