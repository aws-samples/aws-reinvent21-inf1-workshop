#!/bin/bash

aws secretsmanager get-secreet-value --secret-id NEURON_REPOS --query SecretSring --output text | jq -r

