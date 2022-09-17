import torch
import glob
import os


class Recorder:
    # Records the input activations at each layer
    def __init__(self, name):
        self.module_name = name
            
    def __call__(self, module, inputs):
        self.inputs = inputs[0].detach().cpu()


def save_meta_data(model, inputs):
    # This is the function that was used to originally save the data
    GEMM_LAYERS = [
        'Linear',
        'Conv1d',
        'Conv2d',
        'Conv3d',
        'ConvTranspose1d',
        'ConvTranspose2d',
        'ConvTranspose3d'
    ]

    # Attach recorder, pass inputs
    def attach_hooks(model):
        recorders = {}
        for n, m in model.named_modules():
            if type(m).__name__ in GEMM_LAYERS:
                recorders[n] = Recorder(n)
                m.register_forward_pre_hook(recorders[n])
        return recorders

    # Attach recorders as hooks to model to record activations
    recorders = attach_hooks(model)

    # Make sure inputs are prepared for passing through the model
    try:
        model(inputs)
    except:
        model(**inputs)

    for n, m in model.named_modules():
        meta_data = {}
        if type(m).__name__ in GEMM_LAYERS:
            meta_data['layer_name'] = n
            meta_data['layer_type'] = type(m).__name__
            meta_data['input_shape'] = recorders[n].inputs.shape
            meta_data['weight_shape'] = m.weight.shape
            meta_data['inputs'] = recorders[n].inputs
            meta_data['weights'] = m.weight
            meta_data['bias'] = m.bias
            meta_data['batch_size'] = recorders[n].inputs.shape[0]
            meta_data['inputs_stats'] = {
                'mean': torch.mean(recorders[n].inputs),
                'std': torch.std(recorders[n].inputs)
            }
            meta_data['weight_stats'] = {
                'mean': torch.mean(m.weight),
                'std': torch.std(m.weight)
            }
            torch.save(meta_data, f'meta_data/{n}_data.pt')


def load_meta_data(data_dir):
    full_meta_data = {}
    # Load meta data from the specified directory
    for name in glob.glob(os.path.join(data_dir, "*.pt")):
        if name.endswith(".pt"):
            module_name = os.path.basename(os.path.splitext(name)[0])
            full_meta_data[module_name] = torch.load(
                os.path.join(data_dir, module_name + ".pt")
            )
    return full_meta_data
