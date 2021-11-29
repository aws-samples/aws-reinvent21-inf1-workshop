#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source ./ec2.conf

function vpc() {
        # Determine VPC_ID and SUBNET_ID where to launch instance
        echo ""
        echo "Getting VPC and Subnet ..."
        if [ "$EC2_SUBNET_ID" == "" ]; then
                SUBNET_ROW=$(aws ec2 describe-subnets --query "Subnets[*].{Name:Tags[?Key=='Name']|[0].Value,CidrBlock:CidrBlock,AvailabilityZone:AvailabilityZone,IPs:AvailableIpAddressCount,Public:MapPublicIpOnLaunch,SubnetId:SubnetId,VpcId:VpcId}" --output table | grep 1a | grep True | grep None)
                VPC_ID=$(echo "$SUBNET_ROW" | cut -d '|' -f 8 | cut -d ' ' -f 3)
        else
                VPC_ID=$(aws ec2 describe-subnets --query "Subnets[*].{SubnetId:SubnetId,VpcId:VpcId}" --output table | grep $EC2_SUBNET_ID | cut -d '|' -f 3 | cut -d ' ' -f 3)
        fi
        echo "$VPC_ID"
}

function subnet() {
        if [ "$EC2_SUBNET_ID" == "" ]; then
                SUBNET_ROW=$(aws ec2 describe-subnets --query "Subnets[*].{Name:Tags[?Key=='Name']|[0].Value,CidrBlock:CidrBlock,AvailabilityZone:AvailabilityZone,IPs:AvailableIpAddressCount,Public:MapPublicIpOnLaunch,SubnetId:SubnetId,VpcId:VpcId}" --output table | grep True | grep None | head -n 1)
                EC2_SUBNET_ID=$(echo "$SUBNET_ROW" | cut -d '|' -f 7 | cut -d ' ' -f 3)
        fi

        echo "$EC2_SUBNET_ID"
}

function keypair() {
        # Create SSH key pair if it does not exist
        echo ""
        echo "Checking key pairs ..."
        aws ec2 describe-key-pairs --query "KeyPairs[*].{KeyPairId:KeyPairId,KeyName:KeyName,KeyType:KeyType}" --output table | grep $EC2_KEY_NAME > /dev/null
        if [ "$?" == "0" ]; then
                echo "KeyPair $EC2_KEY_NAME already exists"
        else
                echo "Creating key pair $EC2_KEY_NAME ..."
                mkdir -p ${HOME}/.ssh
                aws ec2 create-key-pair --key-name $EC2_KEY_NAME --query 'KeyMaterial' --output text > ${HOME}/.ssh/${EC2_KEY_NAME}.pem
                chmod 600 ${HOME}/.ssh/${EC2_KEY_NAME}.pem
        fi
}

function instance_profile() {
        # Create instance profile if it does not exist
        echo ""
        echo "Checking instance profile ..."
        if [ "$EC2_INSTANCE_PROFILE_NAME" == "" ]; then
                EC2_INSTANCE_PROFILE_NAME=inf1-instance-profile
        fi
        INSTANCE_ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name $EC2_INSTANCE_PROFILE_NAME --query InstanceProfile.Roles[0].RoleName --output text 2>/dev/null)
        if [ "$?" == "0" ]; then
                echo "Instance profile $EC2_INSTANCE_PROFILE_NAME already exists."
        else
                echo "Creating instance profile $EC2_INSTANCE_PROFILE_NAME ..."
                aws iam create-instance-profile --instance-profile-name $EC2_INSTANCE_PROFILE_NAME
                aws iam get-role --role-name $EC2_INSTANCE_PROFILE_NAME 2>/dev/null
                if [ "$?" == "0" ]; then
                        echo "Role $EC2_INSTANCE_PROFILE_NAME found"
                else
                        echo "Creating role $EC2_INSTANCE_PROFILE_NAME ..."
                        echo '{"Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Principal": { "Service": "ec2.amazonaws.com" }, "Action": "sts:AssumeRole" } ] }' > ./ec2-assume-role-policy.json
                        aws iam create-role --role-name $EC2_INSTANCE_PROFILE_NAME --assume-role-policy-document file://ec2-assume-role-policy.json
                        echo "Attaching policy arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore ..."
                        aws iam attach-role-policy --role-name $EC2_INSTANCE_PROFILE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
                        rm -f ./ec2-assume-role-policy.json
			echo "Creating policy SecretsManagerReadOnly ..."
			echo '{"Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Resource": "*", "Action": [ "secretsmanager:GetSecretValue" ] } ] }' > ./secretsmanager-readonly-policy.json
			POLICY_ARN=$(aws iam create-policy --policy-name SecretsManagerReadOnly --policy-document file://secretsmanager-readonly-policy.json --query Policy.Arn --output text)
			echo "Attaching policy $POLICY_ARN ..."
			aws iam attach-role-policy --role-name $EC2_INSTANCE_PROFILE_NAME --policy-arn $POLICY_ARN
                        rm -f ./secretsmanager-readonly-policy.json
                fi
                aws iam add-role-to-instance-profile --instance-profile-name $EC2_INSTANCE_PROFILE_NAME --role-name ssm-managed-instance
        fi
}

function security_group_id() {
        aws ec2 describe-security-groups --query "SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,VpcId:VpcId}"  --output table | grep $EC2_SG_NAME > /dev/null
        if [ "$?" == "0" ]; then
                if [ "$1" == "verbose" ]; then
                        echo "Security group $EC2_SG_NAME found"
                fi
                EC2_SG_ID=$(aws ec2 describe-security-groups --query "SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,VpcId:VpcId}"  --output table | grep $EC2_SG_NAME | cut -d '|' -f 2 | cut -d ' ' -f 3)
	else
		if [ "$1" == "verbose" ]; then
			echo "Security group $EC2_SG_AME not found"
		fi
        fi
	echo "$EC2_SG_ID"
}

function security_group() {
        if [ "$1" == "verbose" ]; then
                echo ""
                echo "Checking security group $EC2_SG_NAME ..."
        fi
        aws ec2 describe-security-groups --query "SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,VpcId:VpcId}"  --output table | grep $EC2_SG_NAME > /dev/null
        if [ "$?" == "0" ]; then
                if [ "$1" == "verbose" ]; then
                        echo "Security group $EC2_SG_NAME already exists"
                fi
                EC2_SG_ID=$(aws ec2 describe-security-groups --query "SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,VpcId:VpcId}"  --output table | grep $EC2_SG_NAME | cut -d '|' -f 2 | cut -d ' ' -f 3)
        else
                if [ "$1" == "verbose" ]; then
                        echo "Creating security group $EC2_SG_NAME ..."
                fi
                EC2_SG_ID=$(aws ec2 create-security-group --group-name $EC2_SG_NAME --description "allow ssh access" --vpc-id "${VPC_ID}" --query GroupId --output text)
		sleep 2
        fi
        IP=$(curl -s https://checkip.amazonaws.com)
        if [ "$1" == "verbose" ]; then
                echo "Authorizing connections from client IP $IP ..."
        fi
        aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 22 --cidr ${IP}/32 > /dev/null 2>&1

        echo "$EC2_SG_ID"
}

function launch_template() {
        CMD="aws ec2 describe-launch-templates --query 'LaunchTemplates[?LaunchTemplateName==\`${EC2_TEMPLATE_NAME}\`].{LaunchTemplateId:LaunchTemplateId}' --output text"
        local TEMPLATE_ID=$(eval "$CMD")
        echo "$TEMPLATE_ID"
}
