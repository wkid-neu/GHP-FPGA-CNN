"""
Convert A Verilog header file to a yaml file.
Note that only macros are allowed in the verilog file.
"""

import yaml
import argparse

def parse_macros_from_file(fp: str):
    ret = {}
    with open(fp, mode="r", encoding="utf8") as f:
        content = f.read()
    lines = content.split("\n")
    for line in lines:
        # blank line
        if line=="":
            continue
        # comment line
        if line.startswith("//"):
            continue
        # comment after content
        cmt_idx = line.find("//")
        if cmt_idx > -1:
            line = line[:cmt_idx]
        
        # parse macros
        if line.startswith("`define"):
            ls = line.split()
            if len(ls) == 2:
                k, v = ls[1], ""
            elif len(ls) == 3:
                k, v = ls[1], ls[2]
            else:
                raise ValueError(f"Invalid line {line}")
            ret[k] = v
    return ret

def main(vh_fp: str, yaml_fp: str):
    macros = parse_macros_from_file(vh_fp)
    with open(yaml_fp, mode="w", encoding="utf8") as f:
        yaml.safe_dump(macros, f, sort_keys=False)

if __name__=="__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--vh_fp")
    parser.add_argument("--yaml_fp")
    args = parser.parse_args()

    vh_fp = str(args.vh_fp)
    yaml_fp = str(args.yaml_fp)

    main(vh_fp, yaml_fp)
