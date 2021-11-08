#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source ./dlc.conf

echo ""
echo "Configuring AWS client ..."
aws configure

echo ""
echo "Editing ./dlc.conf ..."
vi dlc.conf

echo ""
echo "Checking registry ${IMAGE} ..."
RESULT=$(aws ecr describe-repositories --query "repositories[*].repositoryName" --output yaml | grep ${IMAGE})
if [ "$?" == "0" ]; then
	echo "Registry ${IMAGE} already exists"
else
	echo "Creating registry ${IMAGE} ..."
	CMD="aws ecr create-repository --repository-name ${IMAGE}"
	echo "$CMD"
	eval "$CMD"
fi

