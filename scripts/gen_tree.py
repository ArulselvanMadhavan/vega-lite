import json
import torch
import re
import sys
from save_load_meta_data import load_meta_data

data_dir = 'data/meta_data/'  # Data directory
full_meta_data = load_meta_data(data_dir)

word_matches = re.compile("[\w]+")

def get_node(id, name, parent):
    return {"id":id, "name":name, "parent":parent}

entries = []

names = [name for name, data in full_meta_data.items()]
def sort_fn(name):
    words = word_matches.findall(name)
    if len(words) > 3:
        return int(words[3])
    else:
        return sys.maxsize
names = sorted(names, key=sort_fn)

# name - bert.encoder.layer.0.attention
# root; l1; l2;
# root, l1 -> already exists; need new nodes if they don't
# l2 -> full name is unique but split name will have lots of duplicates
id_count = 0

def check_and_insert(d, k, n, pid):
    global id_count
    if d.get(k, None) is None:
        d[k] = {"name":n, "id":id_count, "parent":pid}
        id_count = id_count + 1
    return 

def chunks_from_name(name):
    words = word_matches.findall(name)
    return words

def group_per_depth(words):
    if len(words) < 5:
        return [".".join(words)]
    else:
        return [words[0], ".".join(words[1:4]), ".".join(words[4:])]
    
nodes_dict = {}
for name in names:
    data = full_meta_data[name]
    words = chunks_from_name(name)
    words_per_depth = group_per_depth(words)
    if len(words_per_depth) == 1:
        check_and_insert(nodes_dict, name, name, 0)
        continue
    else:
        root = words[0]
        check_and_insert(nodes_dict, root, root, None)
        for p in range(1, len(words_per_depth)):
            so_far = ".".join(words_per_depth[:p+1])
            pid = nodes_dict[".".join(words_per_depth[:p])]["id"]
            check_and_insert(nodes_dict, so_far, words_per_depth[p], pid)

with open("data/tree.json", "w+") as f:
    json.dump(list(nodes_dict.values()), f)
    
