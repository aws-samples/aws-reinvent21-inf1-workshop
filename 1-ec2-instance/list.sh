#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source ./ec2.conf

CMD="aws ec2 describe-instances --query \"Reservations[*].Instances[*].{InstanceId:InstanceId,Keypair:KeyName,InstanceType:InstanceType,PrivateIpAddress:PrivateIpAddress,SubnetId:SubnetId,Status:State.Name,Name:Tags[?Key=='Name']|[0].Value}\" --output table"
echo "$CMD"
eval "$CMD"

