#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source ./fun.sh

function usage(){
        echo ""
        echo "Usage: $0 [template_name]"
        echo ""
        exit 0
}

if [ "$1" == "--help" ]; then
        usage
fi

if [ ! "$1" == "" ]; then
        EC2_TEMPLATE_NAME="$1"
fi

echo ""
echo "Launching instance from template $1 ..."

# Get template id
EC2_TEMPLATE_ID=$(launch_template)
echo "EC2_TEMPLATE_ID=$EC2_TEMPLATE_ID"

# Check if template exists
if [ "$EC2_TEMPLATE_ID" == "" ]; then
        echo ""
        echo "Template $EC2_TEMPLATE_NAME not found."
        echo "Please ensure template is created first."
        echo "Execute ./template-configure.sh and ./template-create.sh"
        echo "then try this script again."
else

	# Check if instance already exists
	echo ""
	echo "Checking instances ..."
	aws ec2 describe-instances --query "Reservations[*].Instances[*].{InstanceId:InstanceId,InstanceType:InstanceType,PrivateIpAddress:PrivateIpAddress,SubnetId:SubnetId,Status:State.Name,Name:Tags[?Key=='Name']|[0].Value}" --output text | grep $EC2_INSTANCE_NAME | grep -v terminated | grep -v shutting-down
	if [ "$?" == "0" ]; then
        	echo "Instance $EC2_INSTANCE_NAME already exists."
        	echo "Will not launch another instance with the same name."
	else
        	echo ""
        	CMD="aws ec2 run-instances --launch-template LaunchTemplateId=$EC2_TEMPLATE_ID --query 'Instances[*].{InstanceId:InstanceId}' --output text"
        	INSTANCE_ID=$(eval "$CMD")
        	if [ "$?" == "0" ]; then
                	echo ""
                	echo "Instance $INSTANCE_ID launched from template $EC2_TEMPLATE_NAME"

                	echo ""
                	echo "Setting instance name $EC2_INSTANCE_NAME ..."
                	CMD="aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=$EC2_INSTANCE_NAME"
                	echo "$CMD"
                	eval "$CMD"
        	else
                	echo ""
                	echo "Failed to launch instance from template $1"
        	fi
	fi
fi
echo ""
