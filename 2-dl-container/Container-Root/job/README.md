# Steps for Benchmarking

The benchmarking is performed in a sequence of steps. The rationale and the high level thought process behind the steps is described below.

## Choice of Accelerator Hardware

The users can select their accelerator harware to be either an AWS Inferentia or NVIDIA-GPU for inference. The container sandbox is built for the specific hardware with the necessary libraries. The container build instructions have been created for running standard Bert type NLP and Computer Vision models. Users can test their custom models by augmenting the container build with custom libraries.

## Compile the Model

In this step, the pretrained models and tokenizers are fetched from a public source (HuggingFace BERT models or Torch Vision Resnet50 models). Below we show the steps for a BERT model.

```
# Get the model and predict
orig_model = AutoModelForSequenceClassification.from_pretrained(model_name, return_dict=False)

# Get tokenizer and create encoded inputs
tokenizer = AutoTokenizer.from_pretrained(model_name)
```
Depending on the model and the input size, it is possible to batch the requests to increase the loading on the accelerator. The compilation process prepares the batched input template. The values for batch_size are controllable via the ENV variables.

```
encoded_inputs = tokenizer.encode_plus(sequence, max_length=max_length, padding='max_length', truncation=True,
                                       return_tensors='pt')
input_ids_tensor = encoded_inputs['input_ids']
batch_input_ids_tensor = torch.cat([input_ids_tensor] * batch_size)
attention_mask_tensor = encoded_inputs['attention_mask']
batch_attention_mask_tensor = torch.cat([attention_mask_tensor] * batch_size)
```

The model is compiled using the torch.jit.trace to create the torch-script file for the specific batch size.

For the Inferentia (Neuron) model
```
# create input tuple for neuron model
neuron_input = batch_input_ids_tensor, batch_attention_mask_tensor
orig_output = orig_model(*neuron_input)
print('Original Model Output:', orig_output)

# Compile the model
neuron_model = torch.neuron.trace(orig_model, neuron_input)
# Save the compiled model for later use
neuron_model.save(neuron_model_file)
```

For a GPU Model
```
ts_input = batch_input_ids_tensor.cuda(), batch_attention_mask_tensor.cuda()

# Compile the model into torchscript
ts_model = torch.jit.trace(orig_model_cuda, ts_input)
# Save the compiled model for later use
ts_model.save(ts_model_file)
```

The compiled models are saved in the local volume for the Benchmarking step.

## Benchmark the Model

The benchmarking is performed on a previously compiled model for a specific batch size by submitting a target number of requests. 

Multiple clients are loaded in separate threads to simulate higher loading on the accelerator. As each task is completed by the thread, it records the latency and overall elapsed time is computed as the queue is completed.

```
begin = time.time()
futures = []
# Submit all tasks and wait for them to finish
# https://stackoverflow.com/questions/51601756/use-tqdm-with-concurrent-futures
with tqdm(total=num_requests) as pbar:
    with ThreadPoolExecutor(num_threads) as pool:
        for i in range(num_requests):
            futures.append(pool.submit(task, models[i % len(models)], random.choice(encoded_input_list)))
        for _ in concurrent.futures.as_completed(futures):
            pbar.update(1)

test_time = time.time() - begin
```

At the end, the percentile statistics (P50, P90, P95) are extracted from the list of latency numbers. In addition the average throughput over the entire num_requests is also calculated

```
print('Latency: %d samples: (P50, P90, P95)'%(len(latency_list)))
print(np.percentile(np.array(latency_list), [50, 90, 95]))
print('Total time taken for %d * (%d x sentences) is %0.4f seconds' % (num_requests, batch_size, test_time))
print('Throughput (sentences * batch_size /sec) = %0.4f' % (num_requests * batch_size / test_time))
```

For the Inferentia accelerator, each chip has multiple cores. Multiple copies of the models can be loaded simultaneously on each core to obtain a dramatic increase in the throughput. Loading the same model across multiple cores is achieved by setting the NEURONCORE_GROUP_SIZES environment variable.

```
num_neuron_chips = int(subprocess.getoutput('ls /dev/neuron* | wc -l'))
num_cores = 4 * num_neuron_chips
nc_env = ','.join(['1'] * num_cores)
print('Neuron Core Group Sizes: %s'%(nc_env))
os.environ['NEURONCORE_GROUP_SIZES'] = nc_env
```

## Example Use cases

The above multi step benchmarking approach has been applied for BERT and Resnet examples.
