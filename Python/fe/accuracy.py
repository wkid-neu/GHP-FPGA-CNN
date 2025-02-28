import onnxruntime as ort
import numpy as np
import utils
import yaml
from tqdm import trange

class OriAcc:
    """Accuracy of the original model."""
    def __init__(
        self,
        ori_model_fp: str,  # file path of original onnx model
        eval_dataset,  # evaluation dataset
        res_fp: str  # file path of results (.yaml)
    ) -> None:
        self.ori_model_fp: str = ori_model_fp
        self.eval_dataset = eval_dataset
        self.res_fp: str = res_fp
    
    def run(self) -> None:
        """Run inference tasks."""
        top1_count = 0
        top5_count = 0

        ori_model_sess = ort.InferenceSession(self.ori_model_fp)
        output_name = ori_model_sess.get_outputs()[0].name
        input_name = ori_model_sess.get_inputs()[0].name

        for i in trange(len(self.eval_dataset), desc="Accuracy of original model"):
            image, label = self.eval_dataset[i]
            raw_infer_result = ori_model_sess.run([output_name], {input_name: np.expand_dims(image, axis=0)})
            infer_result = np.array(raw_infer_result[0])
            top1_result = utils.topk(infer_result, 1)
            top5_result = utils.topk(infer_result, 5)

            if int(top1_result[0][0]) == int(label):
                top1_count += 1
            if int(label) in top5_result[0].tolist():
                top5_count += 1 
        top1_acc = top1_count/len(self.eval_dataset)
        top5_acc = top5_count/len(self.eval_dataset)

        res = {
            "n_samples": len(self.eval_dataset),
            "ori_top1_count": top1_count,
            "ori_top1_acc": top1_acc,
            "ori_top5_count": top5_count,
            "ori_top5_acc": top5_acc
        }
        with open(self.res_fp, mode="w", encoding="utf8") as f:
            yaml.safe_dump(res, f, sort_keys=False)

class QuanAcc:
    """Accuracy of the quantized model."""
    def __init__(
        self,
        quant_model_fp: str,  # file path of the quantized onnx model
        eval_dataset,  # evaluation dataset
        res_fp: str  # file path of results (.yaml)
    ) -> None:
        self.quant_model_fp: str = quant_model_fp
        self.eval_dataset = eval_dataset
        self.res_fp: str = res_fp
    
    def run(self) -> None:
        """Run inference tasks."""
        top1_count = 0
        top5_count = 0

        quant_model_sess = ort.InferenceSession(self.quant_model_fp)
        output_name = quant_model_sess.get_outputs()[0].name
        input_name = quant_model_sess.get_inputs()[0].name

        for i in trange(len(self.eval_dataset), desc="Accuracy of quantized model"):
            image, label = self.eval_dataset[i]
            raw_infer_result = quant_model_sess.run([output_name], {input_name: np.expand_dims(image, axis=0)})
            infer_result = np.array(raw_infer_result[0])
            top1_result = utils.topk(infer_result, 1)
            top5_result = utils.topk(infer_result, 5)

            if int(top1_result[0][0]) == int(label):
                top1_count += 1
            if int(label) in top5_result[0].tolist():
                top5_count += 1 
        top1_acc = top1_count/len(self.eval_dataset)
        top5_acc = top5_count/len(self.eval_dataset)

        res = {
            "n_samples": len(self.eval_dataset),
            "quant_top1_count": top1_count,
            "quant_top1_acc": top1_acc,
            "quant_top5_count": top5_count,
            "quant_top5_acc": top5_acc
        }
        with open(self.res_fp, mode="w", encoding="utf8") as f:
            yaml.safe_dump(res, f, sort_keys=False)

class HwAcc:
    """Accuracy of the Validation Graph."""
    def __init__(
        self,
        val_model_fp: str,  # file path of the Validation Graph
        eval_dataset,  # evaluation dataset
        res_fp: str  # file path of results (.yaml)
    ) -> None:
        self.val_model_fp: str = val_model_fp
        self.eval_dataset = eval_dataset
        self.res_fp: str = res_fp

    def run(self) -> None:
        """Run inference tasks."""
        top1_count = 0
        top5_count = 0

        val_model_sess = ort.InferenceSession(self.val_model_fp)
        output_name = val_model_sess.get_outputs()[0].name
        input_name = val_model_sess.get_inputs()[0].name

        for i in trange(len(self.eval_dataset), desc="Accuracy of Validation Graph"):
            image, label = self.eval_dataset[i]
            raw_infer_result = val_model_sess.run([output_name], {input_name: np.expand_dims(image, axis=0)})
            infer_result = np.array(raw_infer_result[0])
            top1_result = utils.topk(infer_result, 1)
            top5_result = utils.topk(infer_result, 5)

            if int(top1_result[0][0]) == int(label):
                top1_count += 1
            if int(label) in top5_result[0].tolist():
                top5_count += 1 
        top1_acc = top1_count/len(self.eval_dataset)
        top5_acc = top5_count/len(self.eval_dataset)

        res = {
            "n_samples": len(self.eval_dataset),
            "hw_top1_count": top1_count,
            "hw_top1_acc": top1_acc,
            "hw_top5_count": top5_count,
            "hw_top5_acc": top5_acc
        }
        with open(self.res_fp, mode="w", encoding="utf8") as f:
            yaml.safe_dump(res, f, sort_keys=False)

if __name__=="__main__":
    from dataset import ImageNetVal
    # oa = OriAcc(
    #     ori_model_fp="../ort_quant/squeezenet1_0.onnx",
    #     eval_dataset=ImageNetVal(),
    #     res_fp="test.yaml"
    # )
    # oa.run()

    qa = QuanAcc(
        quant_model_fp="../ort_quant/squeezenet1_0-quan.onnx",
        eval_dataset=ImageNetVal(),
        res_fp="test.yaml"
    )
    qa.run()
