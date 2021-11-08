#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

echo ""
echo "Configuring AWS CLI ..."
aws configure

echo ""
echo "Configuring ec2 instance ..."
vi ec2.conf

echo ""
echo "Configuring ec2 template ..."
./template-config.sh

