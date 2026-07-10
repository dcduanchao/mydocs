# Linux 下载

## wget 单线程下载

```bash
# 保留远端文件名
wget --content-disposition "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors"

# 下载到当前目录
wget -P ./ --content-disposition "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"

# Civitai token 放 URL 参数
wget -P ./ --content-disposition "url&token=CHANGE_ME"

# Civitai token 放 Header
wget -P ./ --content-disposition \
-H "Authorization: Bearer CHANGE_ME" \
"https://civitai.com/api/download/models/164821?type=Model&format=SafeTensor"
```

## aria2 多线程下载

```bash
yum install -y aria2
# 或
apt install -y aria2
# 或
conda install -c conda-forge aria2

aria2c -v
```

```bash
# 8 线程 + 代理 + 指定文件名
aria2c \
  -x 8 -s 8 -k 1M \
  --out=qwen_image_2512_bf16.safetensors \
  --all-proxy="http://192.168.30.33:7890" \
  "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V1.0.safetensors"
```

```bash
# 线程太多报错就降到 4
aria2c \
  -x 4 -s 4 -k 2M \
  --file-allocation=trunc \
  --auto-file-renaming=false \
  --summary-interval=5 \
  --out=Qwen-Image-Lightning-4steps-V1.0.safetensors \
  --all-proxy="http://192.168.30.33:7890" \
  "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V1.0.safetensors"
```

## Hugging Face 下载

```bash
pip install -U huggingface_hub

hf download \
  lightx2v/Qwen-Image-Lightning \
  Qwen-Image-Lightning-4steps-V1.0.safetensors \
  --local-dir .
```


