######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

import numpy as np
import os
import random
import time
import torch
import subprocess
import torch.neuron
import torchvision
from PIL import Image
import concurrent.futures
from concurrent.futures import ThreadPoolExecutor
from torchvision import transforms
from tqdm import tqdm
from common_settings import default_image_size, default_batch_size

image_size = int(os.getenv('IMAGE_SIZE', default_image_size))
batch_size = int(os.getenv('BATCH_SIZE', default_batch_size))

preprocess = transforms.Compose([
    transforms.Resize(image_size),
    transforms.CenterCrop(image_size),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225]
    )])

# Setting up NeuronCore groups for inf1.6xlarge with 16 cores
# num_cores = 4 # This value should be 4 on inf1.xlarge and inf1.2xlarge
num_neuron_chips = int(subprocess.getoutput('ls /dev/neuron* | wc -l'))
num_cores = 4 * num_neuron_chips
nc_env = ','.join(['1'] * num_cores)
print('Neuron Core Group Sizes: %s'%(nc_env))
os.environ['NEURONCORE_GROUP_SIZES'] = nc_env
os.environ['TOKENIZERS_PARALLELISM'] = 'false'

# Neuron file name
neuron_model_file = 'resnet50_inf_%d_%d.pt'%(image_size, batch_size)

# Benchmark test parameters - Number of models, threads, total number of requests
num_models = num_cores  # num_models <= number of cores (4 for inf1.xl and inf1.2xl, 16 for inf1.6xl)
num_threads = num_cores  # Setting num_threads to num_models works well.
num_requests = 10000
num_request_samples = 10

# Create a pipeline with the given model
model_dict = dict()
model_dict['return_dict'] = False

# Load Images from the Folder
data_dir = './data'
img_preprocessed_list = []
jpg_file_list = os.listdir(data_dir)
jpg_file_list = [x for x in jpg_file_list if '.jpg' in x]
jpg_file_list_sample = random.sample(jpg_file_list, num_request_samples)

for cur_image_file in jpg_file_list_sample:
    cur_image = Image.open('%s/%s' % (data_dir, cur_image_file)).convert('RGB')

    cur_image_preprocessed = preprocess(cur_image)
    cur_image_preprocessed_unsqueeze = torch.unsqueeze(cur_image_preprocessed, 0)
    img_preprocessed_list.append(cur_image_preprocessed_unsqueeze)


def load_model(file_name):
    # Load modelbase
    model = torch.jit.load(file_name)

    return model

latency_list = []

def task(model, cur_img_preprocess):
    global latency_list
    begin = time.time()

    batch_input_tensor = torch.cat([cur_img_preprocess] * batch_size)

    prediction = model(batch_input_tensor)
    latency_time = time.time() - begin

    latency_list.append(latency_time)
    return


def benchmark(num_models, num_threads, num_requests, model_file):
    # Load a model into each NeuronCore
    print('Loading Models To Memory')
    models = [load_model(model_file) for _ in range(num_models)]
    print('Starting benchmark')
    output_list = []
    begin = time.time()
    futures = []
    # Submit all tasks and wait for them to finish
    # https://stackoverflow.com/questions/51601756/use-tqdm-with-concurrent-futures
    with tqdm(total=num_requests) as pbar:
        with ThreadPoolExecutor(num_threads) as pool:
            for i in range(num_requests):
                futures.append(pool.submit(task, models[i % len(models)], random.choice(img_preprocessed_list)))
                #output_list.append(output.result())
            for _ in concurrent.futures.as_completed(futures):
                pbar.update(1)

    test_time = time.time() - begin

    # return test_time, np.array(output_list)
    return test_time


# test_time, latency_array = benchmark(num_models, num_threads, num_requests, neuron_model_file)
test_time = benchmark(num_models, num_threads, num_requests, neuron_model_file)
print('Latency: (P50, P90, P95)')
print(np.percentile(np.array(latency_list), [50, 90, 95]))
print('Total time taken for %d * (%d images) is %0.4f seconds' % (num_requests, batch_size, test_time))
print('Throughput (num_requests * batch_size /sec) = %0.4f' % (num_requests * batch_size / test_time))
