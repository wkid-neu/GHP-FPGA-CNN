import argparse
import yaml
from fast_eval import from_pytorch
from fast_eval import from_onnx

if __name__=="__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--cfg_fp")
    args = parser.parse_args()

    cfg_fp = str(args.cfg_fp)
    with open(cfg_fp, mode="r", encoding="utf8") as f:
        cfg_data = yaml.safe_load(f)
        model_path = cfg_data["model_path"]
        model_type = cfg_data["model_type"]

    if model_type == "pytorch":
        from_pytorch.extract(model_path, "")
    elif model_type == "onnx":
        from_onnx.extract(model_path, "")
