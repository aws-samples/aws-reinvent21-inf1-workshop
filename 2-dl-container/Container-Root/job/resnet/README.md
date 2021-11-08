# GPU Instructions
## Torchscript the Model

```
root@eb433875a410:/app/resnet# python compile_model-gpu.py 
Downloading: "https://download.pytorch.org/models/resnet50-19c8e357.pth" to /root/.cache/torch/hub/checkpoints/resnet50-19c8e357.pth
100%|███████████████████████████████████████| 97.8M/97.8M [00:00<00:00, 207MB/s]
Original Model Output: tensor([[-0.7677, -0.4907, -1.1417,  ..., -3.2462,  0.8563,  2.7893],
        [-0.7677, -0.4907, -1.1417,  ..., -3.2462,  0.8563,  2.7893],
        [-0.7677, -0.4907, -1.1417,  ..., -3.2462,  0.8563,  2.7893],
        [-0.7677, -0.4907, -1.1417,  ..., -3.2462,  0.8563,  2.7893]],
       device='cuda:0', grad_fn=<AddmmBackward>)
torch.jit.script cuda version
Torchscript Model Output: tensor([[-0.7677, -0.4907, -1.1417,  ..., -3.2462,  0.8563,  2.7893],
        [-0.7677, -0.4907, -1.1417,  ..., -3.2462,  0.8563,  2.7893],
        [-0.7677, -0.4907, -1.1417,  ..., -3.2462,  0.8563,  2.7893],
        [-0.7677, -0.4907, -1.1417,  ..., -3.2462,  0.8563,  2.7893]],
       device='cuda:0', grad_fn=<AddmmBackward>)
```

Torchscript file will be created
```
-rw-r--r-- 1 root root 102605200 Oct 11 19:12 resnet50-ts-256.pt
```


## Benchmark the Model

Directly load pre trained model
```
test_time, latency_array = benchmark(num_models, num_threads, num_requests, model_file, torchscript=False)


root@eb433875a410:/app/resnet# python direct_benchmark-gpu.py 
Loading Models To Memory
Starting benchmark
100%|███████████████████████████████████████| 1000/1000 [00:17<00:00, 56.62it/s]
Latency: (P50, P90, P95)
[0.01669574 0.0180295  0.01868927]
Total time taken for 1000 * (4 x sentences) is 17.6630 seconds
Throughput (sentences * batch_size /sec) = 226.4627
```

Torchscript model

```
test_time, latency_array = benchmark(num_models, num_threads, num_requests, model_file, torchscript=True)


root@eb433875a410:/app/resnet# python direct_benchmark-gpu.py 
Loading Models To Memory
Starting benchmark
100%|███████████████████████████████████████| 1000/1000 [00:18<00:00, 55.52it/s]
Latency: (P50, P90, P95)
[0.01676476 0.01796355 0.01840786]
Total time taken for 1000 * (4 x sentences) is 18.0125 seconds
Throughput (sentences * batch_size /sec) = 222.0686

```

Very similar performance from both the models

# Neuron Instructions
## Compile the model
```
bash-4.2# python compile_model-inf.py 

Original Model Output: tensor([[-0.7677, -0.4907, -1.1417,  ..., -3.2462,  0.8563,  2.7893],
        [-0.7677, -0.4907, -1.1417,  ..., -3.2462,  0.8563,  2.7893],
        [-0.7677, -0.4907, -1.1417,  ..., -3.2462,  0.8563,  2.7893],
        [-0.7677, -0.4907, -1.1417,  ..., -3.2462,  0.8563,  2.7893]],
       grad_fn=<AddmmBackward>)

Neuron Model Output: tensor([[-0.7773, -0.5195, -1.0859,  ..., -3.2188,  0.8359,  2.7812],
        [-0.7773, -0.5234, -1.0859,  ..., -3.2188,  0.8320,  2.7812],
        [-0.7695, -0.5195, -1.0859,  ..., -3.2188,  0.8320,  2.7656],
        [-0.7773, -0.5195, -1.0859,  ..., -3.2188,  0.8320,  2.7656]])

```

File will be created
```
-rw-r--r-- 1 root root 43039402 Oct 11 18:25 resnet50_inf_256.pt
```

## Run the Model
```
bash-4.2# python direct_benchmark-inf.py 

Loading Models To Memory
100%|██████████████████████████████████████████████████████████████████████████████████████████████████████| 1000/1000 [00:15<00:00, 65.54it/s]

Latency: (P50, P90, P95)
[0.01497936 0.01529675 0.0154126 ]
Total time taken for 1000 * (4 x sentences) is 15.2613 seconds
Throughput (sentences * batch_size /sec) = 262.1005
```