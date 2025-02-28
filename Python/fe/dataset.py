from torchvision.datasets import ImageNet
from torchvision import transforms

imagenet_val_root = "/home/hp50/Desktop/Python/"
factor = 50

class ImageNetVal:
    def __init__(self) -> None:
        preprocess = transforms.Compose([
            transforms.Resize(256),
            transforms.CenterCrop(224),  # 299 for inception serials
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ])
        self.ds = ImageNet(root=imagenet_val_root, split="val", transform=preprocess)

    def __len__(self):
        return self.ds.__len__()//factor

    def __getitem__(self, index):
        return self.ds.__getitem__(index*factor)

if __name__=="__main__":
    ds = ImageNetVal()
    print(ds[0])
