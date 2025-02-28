import os

models = [
    "alexnetb", 
    "inceptionv3", "inceptionv4",
    "resnet18", "resnet34", "resnet50", "resnet101", "resnet152", 
    "selecsls42b", "selecsls60", 
    "squeezenet_v1_0", "squeezenet_v1_1", 
    "vgg11", "vgg13", "vgg16", "vgg19", 
    "vovnet27s"
]

accs = [
    "M32P32Q16R16S8",
    "M32P64Q16R16S8",
    "M32P96Q16R16S8",
    "M64P64Q16R16S8",
]

for model_name in models:
    for acc_name in accs:
        dir_name = f"{model_name}_{acc_name}"
        if not os.path.exists(dir_name):
            os.makedirs(dir_name)