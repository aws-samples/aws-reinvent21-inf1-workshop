######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

import os
import torch
import torch.neuron
from PIL import Image
import torchvision
from torchvision import transforms
from common_settings import default_image_size, default_batch_size, default_model_name

image_size = int(os.getenv('IMAGE_SIZE', default_image_size))
batch_size = int(os.getenv('BATCH_SIZE', default_batch_size))
# Setting up NeuronCore groups
# This value should be 4 on inf1.xlarge and inf1.2xlarge, 16 for inf1.6xlarge
num_cores = 4
nc_env = ','.join(['1'] * num_cores)
os.environ['NEURONCORE_GROUP_SIZES'] = nc_env
os.environ['TOKENIZERS_PARALLELISM'] = 'False'

neuron_model_file = '%s_inf_%d_%d.pt'%(default_model_name,image_size, batch_size)

img_cat = Image.open("data/cat.png").convert('RGB')

#
# Create a preprocessing pipeline
#
preprocess = transforms.Compose([
    transforms.Resize(image_size),
    transforms.CenterCrop(image_size),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225]
    )])

#
# Pass the image for preprocessing and the image preprocessed
#
img_cat_preprocessed = preprocess(img_cat)
img_cat_preprocessed_unsqueeze = torch.unsqueeze(img_cat_preprocessed, 0)
batch_img_cat_tensor = torch.cat([img_cat_preprocessed_unsqueeze] * batch_size)

model_ft = torchvision.models.resnet50(pretrained=True)
model_ft.eval()

# REmove None Attributes
# https://forums.developer.nvidia.com/t/torchscripted-pytorch-lightning-module-fails-to-load/181002
remove_attributes = []
for key, value in vars(model_ft).items():
    if value is None:
        remove_attributes.append(key)

for key in remove_attributes:
    delattr(model_ft, key)

orig_output = model_ft(batch_img_cat_tensor)
print('Original Model Output:', orig_output)

# Compile the model
neuron_model = torch.neuron.trace(model_ft,
                                  batch_img_cat_tensor) #,
#                                  compiler_args = ['--neuroncore-pipeline-cores', str(num_cores)])
# Save the compiled model for later use
neuron_model.save(neuron_model_file)

# Load the saved model and perform inference
neuron_model_reloaded = torch.jit.load(neuron_model_file)
neuron_output = neuron_model_reloaded(batch_img_cat_tensor)
print('Neuron Model Output:', neuron_output)
