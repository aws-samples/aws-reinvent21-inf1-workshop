######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

import os
import torch
import subprocess
import torch.neuron
from transformers import AutoModelForSequenceClassification, AutoTokenizer
import numpy as np
import time
import random
from essential_generators import DocumentGenerator
from common_settings import default_max_length, default_batch_size, default_model_name
import neuronperf
import neuronperf.torch
import json
import boto3

max_length = int(os.getenv('MAX_LENGTH', default_max_length))
batch_size = int(os.getenv('BATCH_SIZE', default_batch_size))
model_name = (os.getenv('MODEL_NAME', default_model_name))
os.environ['TOKENIZERS_PARALLELISM'] = 'False'
num_request_samples = 10 # Total number of samples to generate

# Neuron file name
neuron_model_file = '%s_inf_%d_%d.pt'%(model_name, max_length, batch_size)

# Get tokenizer and create encoded inputs
tokenizer = AutoTokenizer.from_pretrained(model_name)
gen = DocumentGenerator()
sequence_list, encoded_input_list = [], []
for _ in np.arange(num_request_samples):
    sequence = gen.sentence()
    encoded_inputs = tokenizer.encode_plus(sequence, max_length=max_length, 
            padding='max_length', truncation=True, return_tensors='pt')
    sequence_list.append(sequence)
    encoded_input_list.append(encoded_inputs)

# Prepare example_inputs Tensor
input_id_list, attention_mask_list = [], []
for _ in range(batch_size):
    tmp_i = random.choice(encoded_input_list)
    input_id_list.append(tmp_i['input_ids'])
    attention_mask_list.append(tmp_i['attention_mask'])
batch_input_ids_tensor = torch.cat(input_id_list)
batch_attention_mask_tensor = torch.cat(attention_mask_list)
example_inputs = batch_input_ids_tensor, batch_attention_mask_tensor

# Perform Neuronperf benchmarking, save results to S3
results = neuronperf.torch.benchmark(neuron_model_file, example_inputs, [batch_size], n_models=[4]) # FIXME: n_models should not be hard-coded
print(json.dumps(results, indent=2))

bucket = os.environ.get('S3_BUCKET_NAME', None)
if bucket:
    fname = f"neuronperf_results_{model_name}_inf_{max_length}_{batch_size}.json"
    s3 = boto3.client("s3")
    s3.put_object(Bucket=bucket, Key=fname, Body=json.dumps(results, indent=2).encode())
