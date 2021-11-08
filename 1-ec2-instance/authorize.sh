#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

. ec2.conf

# Create security group if it does not exist
echo ""
echo "Checking security group $EC2_SG_NAME ..."
aws ec2 describe-security-groups --query "SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,VpcId:VpcId}"  --output table | grep $EC2_SG_NAME > /dev/null
if [ "$?" == "0" ]; then
        echo "Security group $EC2_SG_NAME already exists"
        EC2_SG_ID=$(aws ec2 describe-security-groups --query "SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,VpcId:VpcId}"  --output table | grep $EC2_SG_NAME | cut -d '|' -f 2 | cut -d ' ' -f 3)
        IP=$(curl -s https://checkip.amazonaws.com)
        echo "Authorizing connections from client IP $IP ..."
        aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 22 --cidr ${IP}/32 
        if [ "$?" == "0" ]; then
                echo "Authorized."
        fi
else
        echo "Security group $EC2_SG_NAME not found ..."
        echo "Cannot authorize."
fi

