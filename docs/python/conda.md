# Conda环境

## conda 自定义环境

wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh

chmod +x ~/miniconda.sh
执行 miniconda.sh

新开shell

./root/miniconda3/bin/conda init  （没用）

# 接收 main channel 的 TOS
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main

# 接收 R channel 的 TOS
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

conda create -n comfyenv111 python=3.12 -y


conda info  --envs


conda activate comfyenv

conda deactivate
conda remove --name comfyenv111 --all -y
