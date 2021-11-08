#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

print_help() {
	echo ""
	echo "Usage: $0"
	echo ""
	echo "   This script assists with logging in to a private AWS elastic container registry (ECR)."
	echo "   In order to login successfully, the environment in which this script is running, must be configured"
	echo "   with an IAM role allowing access to ECR in the target AWS account."
	echo ""
}

if [ "$1" == "" ]; then

    	source dlc.conf

	# Login to container registry
        echo "Logging in to registry $REGISTRY ..."
        CMD="aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY"
        echo "${CMD}"
        eval "${CMD}"
else
	print_help
fi

