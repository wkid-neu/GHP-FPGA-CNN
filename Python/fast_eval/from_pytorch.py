import torch

def extract(model_path: str, res_file_path: str) -> None:
    """Extract supported layers from the given PyTorch model and wirte them into the csv file."""
    state_dict = torch.load(model_path)
    for k, v in state_dict.items():
        print(k)
