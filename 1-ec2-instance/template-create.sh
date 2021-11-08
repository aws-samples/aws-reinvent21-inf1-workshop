#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source ./ec2.conf

EC2_TEMPLATE=./bootstrap/launch-template-${EC2_TEMPLATE_NAME}.json

if [ -f $EC2_TEMPLATE ]; then
	echo ""
	echo "Creating Launch Template from $EC2_TEMPLATE ..."
	CMD="aws ec2 create-launch-template --cli-input-json file://${EC2_TEMPLATE}"
	echo "$CMD"
	eval "$CMD"
else
	echo ""
	echo "$EC2_TEMPLATE not found"
	echo "Please specify values for all variables in the EC2 Instance Configuration section of ./ec2.conf"
	echo "Then execute script ./template-configure.sh to generate a launch template"
	echo "Review and mofify the template json if needed and then, run $0 again."
	echo ""
fi
