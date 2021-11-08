######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

import os
import random
import time
import concurrent.futures
from concurrent.futures import ThreadPoolExecutor

import numpy as np
import torch
from essential_generators import DocumentGenerator
from tqdm import tqdm
from transformers import AutoModelForSequenceClassification, AutoTokenizer
from common_settings import default_max_length, default_batch_size, default_model_name

max_length = int(os.getenv('MAX_LENGTH', default_max_length))
batch_size = int(os.getenv('BATCH_SIZE', default_batch_size))
model_name = (os.getenv('MODEL_NAME', default_model_name))

ts_model_file = '%s_gpu_%d_%d.pt'%(model_name, max_length, batch_size)

# Benchmark test parameters - Number of models, threads, total number of requests
num_models = 1  # num_models <= number of cores (4 for inf1.xl and inf1.2xl, 16 for inf1.6xl)
num_threads = 2  # Setting num_threads to num_models works well.
num_requests = 10000
num_request_samples = 10
half_precision = True
print('Max Length: %d, Batch Size: %d, Model Name: %s, Half Precision: %r'%(max_length, batch_size, model_name, half_precision))

# Create a pipeline with the given model
model_dict = dict()
model_dict['return_dict'] = False
# Get tokenizer and create encoded inputs
tokenizer = AutoTokenizer.from_pretrained(model_name)

gen = DocumentGenerator()
sequence_list = []
encoded_input_list = []
for _ in np.arange(num_request_samples):
    sequence = gen.sentence()
    encoded_inputs = tokenizer.encode_plus(sequence, max_length=max_length, padding='max_length', truncation=True,
                                           return_tensors='pt')
    sequence_list.append(sequence)
    encoded_input_list.append(encoded_inputs)


def load_model(file_name, torchscript):
    # Load modelbase
    with torch.cuda.amp.autocast(enabled=half_precision):
        if torchscript:
            model = torch.jit.load(file_name)
            model.eval()
            model = model.cuda()
        else:
            model = AutoModelForSequenceClassification.from_pretrained(model_name, return_dict=False)
            model.eval()
            model = model.cuda()

    return model

latency_list = []

def task(model, encoded_inputs):
    global latency_list
    begin = time.time()


    with torch.cuda.amp.autocast(enabled=half_precision):
        input_ids_tensor = encoded_inputs['input_ids']
        batch_input_ids_tensor = torch.cat([input_ids_tensor] * batch_size)
        attention_mask_tensor = encoded_inputs['attention_mask']
        batch_attention_mask_tensor = torch.cat([attention_mask_tensor] * batch_size)
        ts_input = batch_input_ids_tensor.cuda(), batch_attention_mask_tensor.cuda()
        # neuron_input = encoded_input['input_ids'], encoded_input['attention_mask']
        _ = model(*ts_input)
        latency_time = time.time() - begin

        latency_list.append(latency_time)
    return


def benchmark(num_models, num_threads, num_requests, model_file, torchscript=True):
    # Load a model into each NeuronCore
    print('Loading Models To Memory')
    models = [load_model(model_file, torchscript) for _ in range(num_models)]
    tokenizers = [tokenizer for _ in range(num_models)]
    print('Starting benchmark')
    output_list = []
    begin = time.time()
    futures = []
    # Submit all tasks and wait for them to finish
    # https://stackoverflow.com/questions/51601756/use-tqdm-with-concurrent-futures
    with tqdm(total=num_requests) as pbar:
        with ThreadPoolExecutor(num_threads) as pool:
            for i in range(num_requests):
                # futures.append(pool.submit(task, models[i % len(models)], tokenizers[i % len(models)], random.choice(sequence_list)))
                futures.append(pool.submit(task, models[i % len(models)], random.choice(encoded_input_list)))
                # output_list.append(output.result())
            for _ in concurrent.futures.as_completed(futures):
                pbar.update(1)

    test_time = time.time() - begin

    # return test_time, np.array(output_list)
    return test_time


# test_time, latency_array = benchmark(num_models, num_threads, num_requests, neuron_model_file, torchscript=True)
test_time = benchmark(num_models, num_threads, num_requests, ts_model_file, torchscript=True)
print('Latency: %d samples: (P50, P90, P95)'%(len(latency_list)))
print(np.percentile(np.array(latency_list), [50, 90, 95]))
print('Total time taken for %d * (%d x sentences) is %0.4f seconds' % (num_requests, batch_size, test_time))
print('Throughput (sentences * batch_size /sec) = %0.4f' % (num_requests * batch_size / test_time))
