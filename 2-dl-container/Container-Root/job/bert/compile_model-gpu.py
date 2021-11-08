######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################


import os
import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification
from common_settings import default_max_length, default_batch_size, default_model_name

max_length = int(os.getenv('MAX_LENGTH', default_max_length))
batch_size = int(os.getenv('BATCH_SIZE', default_batch_size))
model_name = (os.getenv('MODEL_NAME', default_model_name))

sequence = 'I am going to a movie'
ts_model_file = '%s_gpu_%d_%d.pt'%(model_name, max_length, batch_size)

# Get tokenizer and create encoded inputs
tokenizer = AutoTokenizer.from_pretrained(model_name)
encoded_inputs = tokenizer.encode_plus(sequence, max_length=max_length, padding='max_length', truncation=True,
                                       return_tensors='pt')
input_ids_tensor = encoded_inputs['input_ids']
batch_input_ids_tensor = torch.cat([input_ids_tensor] * batch_size)

attention_mask_tensor = encoded_inputs['attention_mask']
batch_attention_mask_tensor = torch.cat([attention_mask_tensor] * batch_size)

# Get the model and predict
orig_model = AutoModelForSequenceClassification.from_pretrained(model_name, return_dict=False)
# Push model into cuda
orig_model_cuda = orig_model.cuda()
# create input tuple for neuron model
# ts_input = encoded_inputs['input_ids'].cuda(), encoded_inputs['attention_mask'].cuda()
ts_input = batch_input_ids_tensor.cuda(), batch_attention_mask_tensor.cuda()

orig_output = orig_model_cuda(*ts_input)
print('Original Model Output:', orig_output)

# Compile the model into torchscript
ts_model = torch.jit.trace(orig_model_cuda, ts_input)
# Save the compiled model for later use
ts_model.save(ts_model_file)
# neuron_model.save(neuron_model_file)

# Load the saved model and perform inference
ts_model_reloaded = torch.jit.load(ts_model_file)
ts_output = ts_model_reloaded(*ts_input)
print('Torchscript Model Output:', ts_output)
