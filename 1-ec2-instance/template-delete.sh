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
        EC2_TEMPLATE_NAME=$1
fi

EC2_TEMPLATE_ID=$(launch_template)

if [ "$EC2_TEMPLATE_ID" == "" ]; then
        echo ""
        echo "Template $EC2_TEMPLATE_NAME not found."
else
        echo ""
        echo "Deleting launch template $EC2_TEMPLATE_NAME ..."
        CMD="aws ec2 delete-launch-template --launch-template-id $EC2_TEMPLATE_ID"
        eval "$CMD"
        echo ""
        if [ "$?" == "0" ]; then
                echo "Launch template $1 deleted."
        else
                echo "Failed to delete launch template $1"
        fi
        echo ""
fi
