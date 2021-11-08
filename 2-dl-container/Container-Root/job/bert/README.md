# GPU Instructions
## Compile the Model
```
root@eb433875a410:/app/distilbert# python compile_model-gpu.py 
Downloading: 100%|██████████████████████████████| 258/258 [00:00<00:00, 486kB/s]
Downloading: 100%|█████████████████████████████| 776/776 [00:00<00:00, 1.56MB/s]
Downloading: 100%|███████████████████████████| 226k/226k [00:00<00:00, 47.5MB/s]
Downloading: 100%|██████████████████████████████| 112/112 [00:00<00:00, 215kB/s]
Downloading: 100%|███████████████████████████| 255M/255M [00:03<00:00, 70.8MB/s]
Original Model Output: (tensor([[ 2.9191, -0.9582, -3.7830],
        [ 2.9191, -0.9582, -3.7830],
        [ 2.9191, -0.9582, -3.7830],
        [ 2.9191, -0.9582, -3.7830]], device='cuda:0', grad_fn=<AddmmBackward>),)
Torchscript Model Output: (tensor([[ 2.9191, -0.9582, -3.7830],
        [ 2.9191, -0.9582, -3.7830],
        [ 2.9191, -0.9582, -3.7830],
        [ 2.9191, -0.9582, -3.7830]], device='cuda:0', grad_fn=<AddBackward0>),)

```

The torch script model file will be created
```
-rw-r--r-- 1 root root 267981655 Oct 11 19:07 distilbert-base-uncased-mnli_gpu_128_4.pt
```
## Run the model

Use the Torchscript model
```
test_time, latency_array = benchmark(num_models, num_threads, num_requests, neuron_model_file, torchscript=True)

root@eb433875a410:/app/distilbert# python direct_benchmark-gpu.py 
Loading Models To Memory
Starting benchmark
100%|███████████████████████████████████████| 1000/1000 [00:14<00:00, 67.62it/s]
Latency: (P50, P90, P95)
[0.01338172 0.01469085 0.01504188]
Total time taken for 1000 * (4 x sentences) is 14.7900 seconds
Throughput (sentences * batch_size /sec) = 270.4524
```

Directly use the pre-trained model
```
test_time, latency_array = benchmark(num_models, num_threads, num_requests, neuron_model_file, torchscript=False)


root@eb433875a410:/app/distilbert# python direct_benchmark-gpu.py 
Loading Models To Memory
Starting benchmark
100%|███████████████████████████████████████| 1000/1000 [00:14<00:00, 68.20it/s]
Latency: (P50, P90, P95)
[0.01349926 0.01580031 0.01741778]
Total time taken for 1000 * (4 x sentences) is 14.6633 seconds
Throughput (sentences * batch_size /sec) = 272.7893
```

Very similar performance with both the direct pre-trained model and torchscript model

# Neuron Instructions
## Compile the Model

```
bash-4.2# python compile_model-inf.py 
Downloading: 100%|████████████████████████████████████████████████████████████████████████████████████████████| 776/776 [00:00<00:00, 1.13MB/s]
Downloading: 100%|██████████████████████████████████████████████████████████████████████████████████████████| 232k/232k [00:00<00:00, 41.6MB/s]
Downloading: 100%|█████████████████████████████████████████████████████████████████████████████████████████████| 112/112 [00:00<00:00, 169kB/s]
Downloading: 100%|█████████████████████████████████████████████████████████████████████████████████████████████| 258/258 [00:00<00:00, 301kB/s]
Downloading: 100%|██████████████████████████████████████████████████████████████████████████████████████████| 268M/268M [00:06<00:00, 39.9MB/s]
Original Model Output: (tensor([[ 2.9191, -0.9583, -3.7830],
        [ 2.9191, -0.9583, -3.7830],
        [ 2.9191, -0.9583, -3.7830],
        [ 2.9191, -0.9583, -3.7830]], grad_fn=<AddmmBackward>),)

Neuron Model Output: (tensor([[ 2.8906, -0.9297, -3.7812],
        [ 2.8906, -0.9297, -3.7812],
        [ 2.8906, -0.9297, -3.7812],
        [ 2.8906, -0.9297, -3.7812]]),)

```

This will generate the file

```
-rw-r--r-- 1 root root 165919264 Oct 11 18:39 distilbert-base-uncased-mnli_inf_128_4.pt
```
## Run the Model
```
bash-4.2# python direct_benchmark-inf.py 
Loading Models To Memory
nrtd[8]: [NRTD:session_monitor] Session 16 started
nrtd[8]: [NMGR:kmgr_create_eg] Created EG(29) with 1 NCs, start: 0
nrtd[8]: [NMGR:kmgr_create_eg] Created EG(30) with 1 NCs, start: 1
nrtd[8]: [NMGR:kmgr_create_eg] Created EG(31) with 1 NCs, start: 2
nrtd[8]: [NMGR:kmgr_create_eg] Created EG(32) with 1 NCs, start: 3

Starting benchmark
100%|█████████████████████████████████████████████████████████████████████████████████████████████████████| 1000/1000 [00:09<00:00, 105.70it/s]

Latency: (P50, P90, P95)
[0.00914621 0.00944979 0.0096048 ]
Total time taken for 1000 * (4 x sentences) is 9.4621 seconds
Throughput (sentences * batch_size /sec) = 422.7382
```
