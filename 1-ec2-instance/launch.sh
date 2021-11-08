#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

# This script launches an EC2 instance in a public subnet of the default vpc
# and protects it with a security group which allows ssh connections only from the 
# client's current IP address. It also creates an SSH key pair (~/.ssh/${EC2_KEY_PAIR}.pem)
# for access to the instance if the key pair name specified in ec2.conf does not already exist.
# All settings are specified in ./ec2.conf
# The instance name can optionally be specified as an argument

function usage() {
        echo ""
        echo "Usage $0 [instance_name]"
        exit 0
}

# Read configuration
echo ""
echo "Reading ec2 configuration ..."
source ./fun.sh

if [ "$1" == "--help" ]; then
        usage
fi

if [ ! "$1" == "" ]; then
        EC2_INSTANCE_NAME=$1
fi

if [ "$EC2_INSTANCE_NAME" == "" ]; then
        echo ""
        echo "EC2_INSTANCE_NAME not defined"
        echo "All settings in ec2.conf except EC2_SUBNET_ID are required."
        echo "Please configure ec2.conf, then try again or supply instance_name as a command line argument"
        usage
fi

# Check if instance already exists
echo ""
echo "Checking instances ..."
aws ec2 describe-instances --query "Reservations[*].Instances[*].{InstanceId:InstanceId,InstanceType:InstanceType,PrivateIpAddress:PrivateIpAddress,SubnetId:SubnetId,Status:State.Name,Name:Tags[?Key=='Name']|[0].Value}" --output table | grep $EC2_INSTANCE_NAME | grep -v terminated | grep -v shutting-down
if [ "$?" == "0" ]; then
        echo "Instance $EC2_INSTANCE_NAME already exists."
        echo "Will not launch another instance with the same name."
        exit 0
fi

# Create SSH key pair if it does not exist
keypair

# Determine VPC_ID 
VPC_ID=$(vpc)
echo "VPC_ID=$VPC_ID"

# Get SUBNET_ID
EC2_SUBNET_ID=$(subnet)

# Create security group if it does not exist and authorize connections from current client IP
security_group

# Create instance profile if it does not exist
instance_profile

# Launch instance
echo ""
echo "Launching instance $EC2_INSTANCE_NAME ..."
export AWS_PAGER=""
CMD="aws ec2 run-instances --image-id $EC2_IMAGE_ID --block-device-mappings \"DeviceName=${EC2_DEVICE_NAME},Ebs={DeleteOnTermination=true,VolumeSize=${EC2_VOLUME_SIZE_GB},VolumeType=gp3,Encrypted=true}\" --instance-type $EC2_INSTANCE_TYPE --iam-instance-profile \"Name=$EC2_INSTANCE_PROFILE_NAME\" --network-interfaces \"AssociatePublicIpAddress=$EC2_ASSIGN_PUBLIC_IP,DeviceIndex=0,Groups=$EC2_SG_ID,SubnetId=$EC2_SUBNET_ID\" --tag-specifications \"ResourceType=instance,Tags=[{Key=Name,Value=$EC2_INSTANCE_NAME}]\" --key-name $EC2_KEY_NAME"
echo "$CMD"
eval "$CMD"
