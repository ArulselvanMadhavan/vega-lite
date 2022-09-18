from gen_tree import chunks_from_name, group_per_depth, nodes_dict, names
import torch
import csv
from save_load_meta_data import load_meta_data

data_dir = 'data/meta_data/'  # Data directory
full_meta_data = load_meta_data(data_dir)
metrics = ["bias"]
sample_len = 200
with open("stats.csv", "w+") as f:
    writer = csv.writer(f)
    writer.writerow(["id", "metric", "layer_name", "layer_member", "value", "density"])
    for name in names:
        data = full_meta_data[name]
        words = chunks_from_name(name)
        words_per_depth = group_per_depth(words)
        for m in metrics:
            m_data = data[m]
            m_data = torch.flatten(m_data).tolist()[:sample_len]
            layer_id = nodes_dict[".".join(words_per_depth)]["id"]
            if len(words_per_depth) == 3:
                rows = list(zip([layer_id] * sample_len,
                                [m] * sample_len,
                                [words_per_depth[1]] * sample_len,
                                [words_per_depth[2]] * sample_len,
                                m_data,
                                [1]*sample_len))
            else:
                rows = list(zip([layer_id] * sample_len,
                                [m] * sample_len,
                                [words_per_depth[0]] * sample_len,
                                [words_per_depth[0]] * sample_len,
                                m_data,
                                [1]*sample_len))
            writer.writerows(rows)
        
        
