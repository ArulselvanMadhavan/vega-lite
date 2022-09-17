import json
import torch
import re
from save_load_meta_data import load_meta_data

data_dir = 'data/meta_data/'  # Data directory
full_meta_data = load_meta_data(data_dir)

word_matches = re.compile("[\w]+")

def get_node(id, name, parent):
    return {"id":id, "name":name, "parent":parent}

entries = []
ROOT = "bert"
nodes_dict = {ROOT:0}

entries.append(get_node(0, ROOT, None))

def del_none(d):
    # For Python 3, write `list(d.items())`; `d.items()` won’t work
    for key, value in list(d.items()):
        if value is None:
            del d[key]
        elif isinstance(value, dict):
            del_none(value)
    return d  # For convenience

# Get Ids
def check_and_assign_id(params):
    for i in range(1, len(params)):
        parent = params[i - 1]
        cur = params[i]
        if nodes_dict.get(cur, None) is None:
            cur_id = len(nodes_dict)
            nodes_dict[cur] = cur_id
            par_id = nodes_dict[parent]
            entries.append(get_node(cur_id, cur, par_id))

for name, data in full_meta_data.items():
    words = word_matches.findall(name)
    root = words[0]
    # Temp hack for qa_outputs
    if len(words) < 5:
        print(f"Adding {name} to root")
        check_and_assign_id([ROOT, name])
        continue
    
    l1 = ".".join(words[1:4])
    l2 = ".".join(words[4:])
        
    check_and_assign_id([root, l1, l2])

with open("data/tree.json", "w+") as f:
    json.dump([del_none(e) for e in entries], f)
    
