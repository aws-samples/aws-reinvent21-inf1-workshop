######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

import os
import random
import torch
import torch.neuron
from torchvision import transforms
from PIL import Image
from common_settings import default_image_size, default_batch_size, default_model_name
import neuronperf
import neuronperf.torch
import json
import boto3

image_size = int(os.getenv('IMAGE_SIZE', default_image_size))
batch_size = int(os.getenv('BATCH_SIZE', default_batch_size))
os.environ['TOKENIZERS_PARALLELISM'] = 'false'
data_dir = './data'   # image data directory
num_request_samples = 10  # number of images to preprocess. example_inputs tensors will be selected from this set.

preprocess = transforms.Compose([
    transforms.Resize(image_size),
    transforms.CenterCrop(image_size),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225]
    )])

# Neuron file name
neuron_model_file = '%s_inf_%d_%d.pt'%(default_model_name, image_size, batch_size)

# Load Images from the Folder
img_preprocessed_list = []
jpg_file_list = os.listdir(data_dir)
jpg_file_list = [x for x in jpg_file_list if '.jpg' in x]
jpg_file_list_sample = random.sample(jpg_file_list, num_request_samples)

for cur_image_file in jpg_file_list_sample:
    cur_image = Image.open('%s/%s' % (data_dir, cur_image_file)).convert('RGB')
    cur_image_preprocessed = preprocess(cur_image)
    cur_image_preprocessed_unsqueeze = torch.unsqueeze(cur_image_preprocessed, 0)
    img_preprocessed_list.append(cur_image_preprocessed_unsqueeze)

# Prepare example_inputs Tensor
example_inputs = torch.cat(random.choices(img_preprocessed_list, k=batch_size))

# Perform Neuronperf benchmarking, save results to S3
results = neuronperf.torch.benchmark(neuron_model_file, example_inputs, [batch_size], n_models=[4]) # FIXME: n_models should not be hard-coded
print(json.dumps(results, indent=2))

bucket = os.environ.get('S3_BUCKET_NAME', None)
if bucket:
    fname = f"neuronperf_results_resnet50_inf_{image_size}_{batch_size}.json"
    s3 = boto3.client("s3")
    s3.put_object(Bucket=bucket, Key=fname, Body=json.dumps(results, indent=2).encode())
