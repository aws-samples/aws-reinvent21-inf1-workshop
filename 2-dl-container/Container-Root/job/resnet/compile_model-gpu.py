######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

import os
import torch
import torchvision
from PIL import Image
from torchvision import transforms
from common_settings import default_image_size, default_batch_size, default_model_name

image_size = int(os.getenv('IMAGE_SIZE', default_image_size))
batch_size = int(os.getenv('BATCH_SIZE', default_batch_size))

print('Image Size: %d, Batch Size: %d'%(image_size, batch_size))
ts_model_file = '%s_gpu_%d_%d.pt'%(default_model_name,image_size, batch_size)

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
batch_img_cat_tensor_gpu = batch_img_cat_tensor.cuda()

model_ft_gpu = torchvision.models.resnet50(pretrained=True).cuda()
model_ft_gpu.eval()
# REmove None Attributes
# https://forums.developer.nvidia.com/t/torchscripted-pytorch-lightning-module-fails-to-load/181002
remove_attributes = []
for key, value in vars(model_ft_gpu).items():
    if value is None:
        remove_attributes.append(key)

for key in remove_attributes:
    delattr(model_ft_gpu, key)

out = model_ft_gpu(batch_img_cat_tensor_gpu)
print('Original Model Output:', out)

print('torch.jit.script cuda version')
ts_model = torch.jit.script(model_ft_gpu, (batch_img_cat_tensor_gpu))
out = ts_model(batch_img_cat_tensor_gpu)
ts_model.save(ts_model_file)

# Load the saved model and perform inference
ts_model_reloaded = torch.jit.load(ts_model_file)
ts_output = ts_model_reloaded(batch_img_cat_tensor_gpu)
print('Torchscript Model Output:', ts_output)

