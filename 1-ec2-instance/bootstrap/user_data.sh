#!/bin/bash

# FROM AMI id: ami-0e7c9613c521607fc

LOG=/tmp/user_data.log
date > $LOG

echo ""
echo "==================================================="
echo "Executing custom user_data script ..."
echo "See log $LOG for details"
echo "--------------------------------------------------"
echo ""

# Install basic tools
sudo yum install -y unzip jq git >> $LOG

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" >> $LOG
unzip awscliv2.zip >> $LOG
sudo ./aws/install >> $LOG

# Use defaults if neuron repo url's are not set in environment or secretsmanager
if [ "$NEURON_YUM_REPO_URL" == "" ]; then
	NEURON_YUM_REPO_URL=$(aws secretsmanager get-secret-value --secret-id NEURON_REPOS --query SecretString --output text | jq -r .NEURON_YUM_REPO_URL)
	if [[ "$NEURON_YUM_REPO_URL" == "" || "$NEURON_YUM_REPO_URL" == "null" ]]; then
        	NEURON_YUM_REPO_URL=https://yum.repos.neuron.amazonaws.com
	fi
fi

if [ "$NEURON_PIP_REPO_URL" == "" ]; then
        NEURON_PIP_REPO_URL=$(aws secretsmanager get-secret-value --secret-id NEURON_REPOS --query SecretString --output text | jq -r .NEURON_PIP_REPO_URL)
        if [[ "$NEURON_PIP_REPO_URL" == "" || "$NEURON_PIP_REPO_URL" == "null" ]]; then
        	NEURON_PIP_REPO_URL=https://pip.repos.neuron.amazonaws.com
	fi
fi

# Remove old package versions
echo "" >> $LOG
echo "Removing old neuron packages ..." >> $LOG
sudo yum autoremove -y aws-neuron-dkms aws-neuron-runtime-base aws-neuron-tools >> $LOG

# Configure neuron repo
echo "" >> $LOG
echo "Configuring neuron repo ..." >> $LOG
tee /tmp/neuron.repo > /dev/null <<EOF
[neuron]
name=Neuron YUM Repository
baseurl=${NEURON_YUM_REPO_URL}
enabled=1
metadata_expire=0
EOF

sudo mkdir -p /etc/yum.repos.d
sudo mv -f /tmp/neuron.repo /etc/yum.repos.d/neuron.repo
sudo rpm --import ${NEURON_YUM_REPO_URL}/GPG-PUB-KEY-AMAZON-AWS-NEURON.PUB >> $LOG

# Install latest version of neuron and other tools
echo "" >> $LOG
echo "Installing neuron packages ..." >> $LOG
sudo yum update -y >> $LOG
sudo yum install -y \
     git \
     aws-neuron-dkms \
     aws-neuron-runtime-base \
     aws-neuron-tools >> $LOG
sudo yum list | grep neuron >> $LOG

# Add neuron to path
echo "" >> $LOG
echo "Checking neuron path ..." >> $LOG
cat /etc/environment | grep PATH | grep /opt/aws/neuron/bin
if [ "$?" == "0" ]; then
        echo "Neuron path is configured" >> $LOG
else
        echo "Configuring neuron path ..." >> $LOG
        echo "export PATH=$PATH:/opt/aws/neuron/bin" | sudo tee -a /etc/environment
	source /etc/environment
fi

# Install SSM agent
echo "" >> $LOG
echo "Installing SSM agent ..." >> $LOG
sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm >> $LOG
sudo systemctl enable amazon-ssm-agent >> $LOG
sudo systemctl start amazon-ssm-agent >> $LOG
sudo systemctl status amazon-ssm-agent >> $LOG

