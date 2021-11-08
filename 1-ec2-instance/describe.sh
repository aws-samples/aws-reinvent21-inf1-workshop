#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source ./ec2.conf

function usage(){
        echo ""
        echo "Usage: $0 [instnce_name]"
        echo ""
}

if [ "$1" == "--help" ]; then
        usage
        exit 0
fi

if [ ! "$1" == "" ]; then
        EC2_INSTANCE_NAME=$1
fi

if [ "$EC2_INSTANCE_NAME" == "" ]; then
        echo ""
        echo "EC2_INSTANCE_NAME must be specified"
        echo "Please configure ec2.conf or pass it as a command line argument."
        exit 1
fi

# Get instance id
echo ""
echo "Getting instance id ..."
INSTANCE_ID=$(./list.sh | grep ${EC2_INSTANCE_NAME} | grep -v terminated | grep -v shutting-down | head -n 1| cut -d '|' -f 2 | cut -d ' ' -f 3)
if [ "$INSTANCE_ID" == "Name" ]; then
        #Edge case when there is only one line in the table
        INSTANCE_ID=$(./list.sh | grep InstanceId | cut -d '|' -f 3 | cut -d ' ' -f 3)
	INSTANCE_ID=$(echo -n $INSTANCE_ID)
fi
if [ "$INSTANCE_ID" == "" ]; then
        echo "Instance $EC2_INSTANCE_NAME not found."
        echo "This instance may have been terminated"
        exit 1
else
        echo "Found instance $EC2_INSTANCE_NAME with id $INSTANCE_ID"
fi

# Describe instance by id
echo ""
echo "Describing instance id $INSTANCE_ID ..."
CMD="aws ec2 describe-instances --instance-ids $INSTANCE_ID"
echo "$CMD"
eval "$CMD"
echo ""

