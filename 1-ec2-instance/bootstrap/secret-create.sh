#!/bin/bash

# Set the user:pass below and then execute this script to create the secret

export NEURON_YUM_REPO_URL=https://user:pass@yum.repos.beta.neuron.annapurna.aws.a2z.com
export NEURON_PIP_REPO_URL=https://user:pass@pip.repos.beta.neuron.annapurna.aws.a2z.com

aws secretsmanager create-secret --name NEURON_REPOS --secret-string "{\"NEURON_YUM_REPO_URL\":\"$NEURON_YUM_REPO_URL\",\"NEURON_PIP_REPO_URL\":\"https://$NEURON_PIP_REPO_URL\"}"

