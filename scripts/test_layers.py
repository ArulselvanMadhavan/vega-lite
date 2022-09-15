import torch
from save_load_meta_data import load_meta_data
import re
import csv
import json

data_dir = 'data/meta_data/'  # Data directory
full_meta_data = load_meta_data(data_dir)
layer_outputs = {}

sample_layer_name = "bert.encoder.layer.4.attention.self.key_data"
# layer_id = get_layer_id()       # 4
# layer_name = get_layer_name()   # key_data
# value = flatten(torch.tensor)   # []
word_matches = re.compile("[\w]+")

def get_layer_id_and_name(lname):
    return word_matches.findall(lname)

print(get_layer_id_and_name(sample_layer_name))

output = {}
for name, data in full_meta_data.items():
    name_list = get_layer_id_and_name(name)
    if len(name_list) <= 3:
        print("Skipping ", name)
        continue
    layer_id = name_list[3]
    layer_name = ".".join(name_list[4:])

    inputs = data['inputs']
    weights = data['weights']
    bias = data['bias']    

    layer_data = [torch.flatten(bias).tolist(), torch.flatten(weights).tolist()]
    if output.get(layer_id) is None:
        output.update({layer_id:{layer_name:layer_data}})
    else:
        lval = output.get(layer_id)
        lval[layer_name] = layer_data

    
# simple sort        
final_out = [{}] * len(output)
layer_items = [0] * len(output)
total_rows = 0
for k, v in output.items():
    final_out[int(k)] = v
    layer_items[int(k)] = v.keys()
    total_rows += len(v.keys())
    
print("Total Layers:",len(output), len(final_out))
print(data.keys())

tensors = ["bias", "weight"]
# for t in range(0, len(tensors)):
#     name = tensors[t]
#     records = [None] * total_rows
#     rcount = 0
#     for i in range(0, len(final_out)):
#         ldata = final_out[i]
#         for k, v in ldata.items():
#             records[rcount] = {"layer_name":f"layer_{i}", "layer_member":k, f"{name}": v}
#             rcount += 1
#     with open(f"{name}.json", "w+") as f:
#         json.dump(records, f)
        
# for t in range(1, len(tensors)):
#     name = tensors[t]
#     with open(f"{name}.csv", "w+") as f:
#         writer = csv.writer(f)
#         writer.writerow(["layer_name", "layer_member", "value"])
#         total = 0
#         for i in range(0, len(final_out)):
#             ldata = final_out[i]
#             row_id = 0
#             for k, v in list(ldata.items())[:1]:
#                 prop = v[t]
#                 prop_len = len(prop)
#                 rows = list(zip([f"layer_{i}"]*prop_len, [k]*prop_len, prop))
#                 writer.writerows(rows)
#                 row_id += prop_len
#             total += row_id
#         print(f"{name}-Total:", total)

from sklearn.neighbors import KernelDensity
        
for t in range(1, len(tensors)):
    name = tensors[t]
    with open(f"{name}.csv", "w+") as f:
        writer = csv.writer(f)
        writer.writerow(["layer_name", "layer_member", "value", "density"])
        total = 0
        for i in range(0, len(final_out)):
            ldata = final_out[i]
            row_id = 0
            for k, v in list(ldata.items())[:1]:
                prop = v[t]
                # instantiate and fit the KDE model
                kde = KernelDensity(bandwidth=1.0, kernel='gaussian')
                kde.fit(prop)
                X = kde.sample(100)
                logprob = kde.score_samples(X)
                print(len(X), len(logprob))


#print(layer_items)
# with open("bias.csv", "w+") as f:
#     writer = csv.writer(f)
        
    # inputs = data['inputs'].cuda()
    # weights = data['weights']
    # bias = data['bias']

    # # Create the layer
    # if data['layer_type'] == 'Linear':
    #     out_features, in_features = weights.shape
    #     layer = torch.nn.Linear(in_features, out_features).cuda()
    # elif data['layer_type'] == 'Conv2d':
    #     in_channels = inputs.shape[1]
    #     out_channels = weights.shape[0]
    #     kernel_size = weights.shape[2:]
    #     layer = torch.nn.Conv2d(in_channels, out_channels, kernel_size).cuda()
        
    # # Copy weights and bias, pass inputs through layer
    # with torch.no_grad():
    #     layer.weight = weights
    #     layer.bias = bias
    #     output = layer(inputs)
    
    # # Save the layer outputs for testing
    # print(data['layer_name'], ': ', output.shape)
    # layer_outputs[data['layer_name']] = output
