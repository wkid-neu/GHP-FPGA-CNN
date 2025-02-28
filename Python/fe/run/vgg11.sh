proj_dir=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6
export PYTHONPATH=$proj_dir
python3 ${proj_dir}/fe/main.py --cfg_fp ${proj_dir}/fe/run_cfg/vgg11.yaml
