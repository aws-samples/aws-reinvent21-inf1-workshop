#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

. ec2.conf

echo ""
echo "Connecting to instance $EC2_INSTANCE_NAME ..."

echo ""
echo "Getting IP address ..."
EC2_INSTANCE_IP=$(./describe.sh | grep PublicIpAddress | cut -d '"' -f 4)

if [ "$EC2_INSTANCE_IP" == "" ]; then
        echo "Public IP Address is not available."
        echo "Please describe instance and check details"
        echo "or try again later"
        exit 1
fi

echo ""
echo "Connecting to $EC2_INSTANCE_IP"
CMD="ssh -i ${HOME}/.ssh/${EC2_KEY_NAME}.pem ${EC2_SSH_USER}@${EC2_INSTANCE_IP}"
echo "$CMD"
eval "$CMD"

