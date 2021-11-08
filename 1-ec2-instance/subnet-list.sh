#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

. ./ec2.conf

echo ""
echo "Listing subnets ..."

CMD="aws ec2 describe-subnets --query \"Subnets[*].{Name:Tags[?Key=='Name']|[0].Value,CidrBlock:CidrBlock,AvailabilityZone:AvailabilityZone,IPs:AvailableIpAddressCount,Public:MapPublicIpOnLaunch,SubnetId:SubnetId,VpcId:VpcId}\" --output table"

echo "$CMD"
eval "$CMD"

