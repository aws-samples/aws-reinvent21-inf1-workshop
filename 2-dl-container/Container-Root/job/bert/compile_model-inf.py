######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

import os
import torch
import torch.neuron
from transformers import AutoTokenizer, AutoModelForSequenceClassification
from common_settings import default_max_length, default_batch_size, default_model_name

max_length = int(os.getenv('MAX_LENGTH', default_max_length))
batch_size = int(os.getenv('BATCH_SIZE', default_batch_size))
model_name = (os.getenv('MODEL_NAME', default_model_name))
# Setting up NeuronCore groups
# This value should be 4 on inf1.xlarge and inf1.2xlarge, 16 for inf1.6xlarge
num_cores = 4
nc_env = ','.join(['1'] * num_cores)
os.environ['NEURONCORE_GROUP_SIZES'] = nc_env
os.environ['TOKENIZERS_PARALLELISM'] = 'False'

sequence = 'I am going to a movie'
neuron_model_file = '%s_inf_%d_%d.pt'%(model_name, max_length, batch_size)

# Get tokenizer and create encoded inputs
tokenizer = AutoTokenizer.from_pretrained(model_name)
encoded_inputs = tokenizer.encode_plus(sequence, max_length=max_length, padding='max_length', truncation=True,
                                       return_tensors='pt')
input_ids_tensor = encoded_inputs['input_ids']
batch_input_ids_tensor = torch.cat([input_ids_tensor] * batch_size)
attention_mask_tensor = encoded_inputs['attention_mask']
batch_attention_mask_tensor = torch.cat([attention_mask_tensor] * batch_size)

# batch_encoded_inputs = [encoded_inputs['input_ids']] * batch_size,
# Get the model and predict
orig_model = AutoModelForSequenceClassification.from_pretrained(model_name, return_dict=False)

# create input tuple for neuron model
neuron_input = batch_input_ids_tensor, batch_attention_mask_tensor
orig_output = orig_model(*neuron_input)
print('Original Model Output:', orig_output)

# Compile the model
neuron_model = torch.neuron.trace(orig_model, neuron_input)
# Save the compiled model for later use
neuron_model.save(neuron_model_file)

# Load the saved model and perform inference
neuron_model_reloaded = torch.jit.load(neuron_model_file)
neuron_output = neuron_model_reloaded(*neuron_input)
print('Neuron Model Output:', neuron_output)
