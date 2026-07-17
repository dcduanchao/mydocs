## comfyui

## conda 自定义环境
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh

/home/aiuser/ssddc/miniconda3/bin/conda init

# 接受 main channel 的 TOS
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main

# 接受 R channel 的 TOS
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

conda create -n comfyui python=3.12 -y


conda info  --envs


conda activate comfyui

conda deactivate
conda remove --name  chatts --all -y


pip install --upgrade pip wheel
pip install -r requirements.txt


# 假设 CUDA 11.8
conda install pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia

/home/aiuser/mnt

pip install -r requirements.txt
python main.py --listen --port 8188

CUDA_VISIBLE_DEVICES=1 python main.py --listen --port 8189  --enable-cors-header "*"


安装

# 先删除 ComfyUI 原来的 checkpoints 目录（如果是空或临时目录）
rm -rf /home/aiuser/mnt/comfyui/ComfyUI/models/checkpoints

# 创建符号链接
ln -s /home/aiuser/mnt/sd/stable-diffusion-webui-forge/models/Stable-diffusion \
/home/aiuser/mnt/comfyui/ComfyUI/models/checkpoints


rm -rf	/home/aiuser/mnt/comfyui/ComfyUI/models/loras

ln -s /home/aiuser/mnt/sd/stable-diffusion-webui-forge/models/Lora \
/home/aiuser/mnt/comfyui/ComfyUI/models/loras 


## 参数使用学习
### cfg
CFG 小（比如 2-4） Prompt 影响弱 画面更随意、更自由 容易偏离描述，但画面自然，不僵硬

CFG 中等（7-8 常用） Prompt 和自由度平衡 既能听话，又不太僵硬 适合写实、风景、动物生成

CFG 太大（12-20） 模型会“死命贴合” Prompt
容易出现： 画面过度锐化、噪点增加 人物/动物僵硬、不自然 颜色怪异


## Noise 降噪
主要是图片使用 越低越接近原图

### lora
Model Strength = 控制画面细节、风格的“染色程度”

Clip Strength = 控制 Prompt 解释时，LoRA 的权重

推荐组合：

写实/动物/风景：Model 0.6–0.8, Clip 0.6–0.8

二次元/特定人物：Model 0.8–1.0, Clip 0.7–1.0

多个 LoRA 叠加时：适当降低每个 LoRA 强度（避免冲突）

**Model Strength**

控制 LoRA 对 UNet（画面结构、风格） 的影响

范围：0.0 – 1.0（有的能超过 1.0）

0.6–0.8 → 比较自然

1.0 → 很强烈（容易过拟合）

1.2 → 可能崩坏（比如脸型歪、颜色异常）

**Clip Strength**

控制 LoRA 对 文本编码器（Prompt 解析） 的影响

决定 Prompt 和 LoRA 的融合程度

0.5–0.8 → 平衡（一般默认 0.7）

1.0 → Prompt 会非常依赖 LoRA（可能“锁死”风格）

## 采样器

| 参数 (Sampler)         | 模块     | 含义                         |
|----------------------| ------ |----------------------------|
| **Euler normal       | 经典采样器  | ⭐快速、锐利但有噪点，适合草稿和 Prompt 测试 |
| **Eulera **   normal       | 经典采样器  | 比 Euler a 稳定，但生成风格较保守      |
| **DPM++ 2M Karras**  | DPM 系列 | ⭐ 社区通用主流，高质量稳定，细节清晰    二次元 |
| **DPM++ SDE Karras** | DPM 系列 | ⭐ 写实人像最佳，少步数下仍能保持细节        |
| **DPM adaptive**     | DPM 系列 | ⭐自动决定步数，省心但不可控，效果不稳定       |
| **UniPC**            | 高效采样器  | 步数少时质量高，收敛快，适合快速出图         |


## 插件
### wd1.4
| 模型名称                                                                             | 架构                       | 精度    | 速度    | 显存占用 | 适用场景                |
| -------------------------------------------------------------------------------- | ------------------------ | ----- | ----- | ---- | ------------------- |
| **wd-eva02-large-tagger-v3**                                                     | EVA-02 Large (ViT 系列大模型) | ⭐⭐⭐⭐⭐ | 🐢 慢  | 高    | 追求最高精度              |
| **wd-vit-tagger-v3 / wd-v1-4-vit-tagger-v2 / wd-v1-4-vit-tagger**                | Vision Transformer (ViT) | ⭐⭐⭐⭐  | ⚖️ 中等 | 中    | 精度与速度平衡             |
| **wd-swinv2-tagger-v3 / wd-v1-4-swinv2-tagger-v2**                               | Swin Transformer v2      | ⭐⭐⭐⭐  | ⚖️ 中等 | 中偏高  | 高分辨率图像较友好           |
| **wd-convnext-tagger-v3 / wd-v1-4-convnext-tagger-v2 / wd-v1-4-convnext-tagger** | ConvNeXt                 | ⭐⭐⭐   | 🚀 快  | 低    | 批量处理、显卡较弱时          |
| **wd-v1-4-moat-tagger-v2**                                                       | MOAT (卷积+Transformer 混合) | ⭐⭐⭐   | 🚀 快  | 低    | 轻量快速场景              |
| **wd-v1-4-convnextv2-tagger-v2**                                                 | ConvNeXt v2              | ⭐⭐⭐✨  | 🚀 快  | 低    | 相比 ConvNeXt v1 精度略高 |


# ComfyUI 插件清单

| 名字 | Git 地址                                                         | 备注                       |
| -------------------------------------------------------------------------------- |----------------------------------------------------------------|--------------------------|
| cg-use-everywhere | https://github.com/chrisgoringe/cg-use-everywhere.git          | 全局节点                     |
| ComfyUI-Advanced-ControlNet | https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git | 控制网                      |
| comfyui_controlnet_aux | https://github.com/Fannovel16/comfyui_controlnet_aux.git       | 控制网预处理器                  |
| ComfyUI_IPAdapter_plus | https://github.com/cubiq/ComfyUI_IPAdapter_plus.git            | 图像参考                     |
| comfyui_segment_anything | https://github.com/storyicon/comfyui_segment_anything.git      | 自动遮罩                     |
| comfyui-reactor-node | https://github.com/Gourieff/comfyui-reactor-node.git           | 换脸                       |
| ComfyUI_InstantID | https://github.com/cubiq/ComfyUI_InstantID.git                 | XL换脸                     |
| ComfyUI-AnimateDiff-Evolved | https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved.git | 动画                       |
| ComfyUI-VideoHelperSuite | https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git    | 视频合并                     |
| ComfyUI-BrushNet | https://github.com/nullquant/ComfyUI-BrushNet.git              | 局部重绘                     |
| ComfyUI-WD14-Tagger | https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git       | 反推提示词                    |
| comfyui-workspace-manager | https://github.com/11cafe/comfyui-workspace-manager.git        | 左上角工作流管理                 |
| efficiency-nodes-comfyui | https://github.com/jags111/efficiency-nodes-comfyui.git        | **效率节点**                 |
| ComfyUI-ELLA | https://github.com/TencentQQGYLab/ComfyUI-ELLA.git             | 1.5模型精确提示词               |
| rgthree-comfy | https://github.com/rgthree/rgthree-comfy.git                   | 书签开关 / 图像对比              |
| comfyui_dagthomas | https://github.com/dagthomas/comfyui_dagthomas.git             | 自动提示词 (sdxl auto prompt) |
| Derfuu_ComfyUI_ModdedNodes | https://github.com/Derfuu/Derfuu_ComfyUI_ModdedNodes.git       | 按边放大 / 最长边尺寸计算           |
| ComfyUI_Custom_Nodes_AlekPet | https://github.com/AlekPet/ComfyUI_Custom_Nodes_AlekPet.git    | 画板 / 翻译节点                |
| ComfyUI-Easy-Use | https://github.com/yolain/ComfyUI-Easy-Use                     | 节点大合集                    |
| ComfyUI_Comfyroll_CustomNodes | https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git    | 尺寸控制                     |
| ComfyUI_UltimateSDUpscale | https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git         | SD放大                     |
| cg-image-picker | https://github.com/chrisgoringe/cg-image-picker.git            | 图像选择                     |
| sdxl_prompt_styler | https://github.com/twri/sdxl_prompt_styler.git                 | 风格化提示词                   |
| ComfyUI-Styles_CSV_Loader | https://github.com/theUpsider/ComfyUI-Styles_CSV_Loader.git    | 提示词预设节点                  |
| x-flux-comfyui | https://github.com/XLabs-AI/x-flux-comfyui.git                 | FLUX-cn                  |
| ComfyUI-DD-Translation | https://github.com/Dontdrunk/ComfyUI-DD-Translation            | 节点中文翻译        |


## adetailer  细化
模型网站找细化

## wd1.4
# Waifu Diffusion Tagger 模型对比

| 模型名称                        | 架构                | 精度等级 | 速度 | 显存占用 | 适用场景               |
|--------------------------------|---------------------|---------|------|---------|------------------------|
| wd-eva02-large-tagger-v3       | EVA02-large         | ⭐⭐⭐⭐⭐  | 慢   | 很高    | 最高精度需求           |
| wd-vit-tagger-v3               | Vision Transformer  | ⭐⭐⭐⭐   | 中   | 中等    | 精度与速度均衡         |
| wd-swinv2-tagger-v3            | Swin Transformer v2 | ⭐⭐⭐⭐   | 中-慢| 中等    | 细节识别较好           |
| wd-convnext-tagger-v3          | ConvNeXt            | ⭐⭐⭐⭐   | 快   | 较低    | 精度与速度平衡         |
| wd-v1-4-moat-tagger-v2         | MOAT (CNN+Attention)| ⭐⭐⭐    | 中   | 中等    | 折中场景               |
| wd-v1-4-convnextv2-tagger-v2   | ConvNeXt v2         | ⭐⭐⭐⭐   | 中-快| 中等    | 速度与精度兼顾         |
| wd-v1-4-convnext-tagger        | ConvNeXt v1         | ⭐⭐     | 快   | 较低    | 老机器，追求速度       |
| wd-v1-4-vit-tagger-v2          | Vision Transformer v2| ⭐⭐⭐⭐  | 中   | 中等    | ViT 改进版，较准       |
| wd-v1-4-vit-tagger             | Vision Transformer v1| ⭐⭐     | 最快 | 最低    | 显存小、速度优先       |
| wd-v1-4-swinv2-tagger-v2       | Swin Transformer v2 | ⭐⭐⭐    | 中   | 中等    | 分层结构识别           |

---

## 🏆 推荐选择
- **最高精度** → `wd-eva02-large-tagger-v3`
- **速度最快** → `wd-v1-4-vit-tagger`
- **平衡推荐** → `wd-vit-tagger-v3` 或 `wd-v1-4-convnextv2-tagger-v2`  


## controlnet

| Aux 预处理器                 | 描述                                         | 对应 ControlNet 模型            |
| ------------------------ | ------------------------------------------ | --------------------------- |
| **LineartDetector**      | 将彩色图生成线稿                                   | `lineart` / `lineart_anime` |
| **HEDDetector**          | Holistically-nested Edge Detection 边缘检测    | `hed`                       |
| **MLSDDetector**         | Multi-scale Line Segment Detection 多尺度线条检测 | `mlsd`                      |
| **CannyEdgeDetector**    | Canny 边缘检测                                 | `canny`                     |
| **NormalMapDetector**    | 法线图（深度+表面信息）                               | `depth` / `normal`          |
| **OpenPoseDetector**     | 人体关键点 / 姿态检测                               | `openpose`                  |
| **MidasDepthDetector**   | 单张图生成深度图                                   | `depth`                     |
| **SegmentationDetector** | 语义分割 / Mask                                | `segmentation` / `scribble` |


| 模型文件                                                 | 对应 Aux / 用途          | 说明                                        |
| ---------------------------------------------------- | -------------------- | ----------------------------------------- |
| `control_v11e_sd15_ip2p_fp16.safetensors`            | IP2PDetector         | 输入参考图像生成人体姿态或关键点控制，常用于角色生成、动作一致性或多人体场景生成。 |
| `control_v11e_sd15_shuffle_fp16.safetensors`         | ShuffleDetector      | 用于局部或随机位置扰动控制，可增加图像多样性或局部变化，适合细节变化、纹理增强。  |
| `control_v11f1e_sd15_tile_fp16.safetensors`          | TileDetector         | 用于平铺 / Patch 控制，生成重复纹理，适合背景、墙面、地板等连续纹理场景。 |
| `control_v11f1p_sd15_depth_fp16.safetensors`         | DepthDetector        | 利用深度图控制场景空间关系，保证前景/背景层次，适合场景渲染、透视保持。      |
| `control_v11p_sd15_canny_fp16.safetensors`           | CannyEdgeDetector    | 边缘检测控制，生成轮廓、线条或素描风格，适合精细线条保持与二次创作。        |
| `control_v11p_sd15_inpaint_fp16.safetensors`         | InpaintDetector      | 用于局部修补或遮罩控制，适合局部修改、去除对象或补充背景。             |
| `control_v11p_sd15_lineart_fp16.safetensors`         | LineartDetector      | 线稿/素描控制，适合动漫、插画或精细手绘线稿的生成。                |
| `control_v11p_sd15_mlsd_fp16.safetensors`            | MLSDDetector         | MLSD（LSD改进版）线条检测增强控制，适合复杂场景线条提取或轮廓增强。     |
| `control_v11p_sd15_normalbae_fp16.safetensors`       | NormalBaeDetector    | 法线图控制，保留光照方向或表面细节，适合生成有立体感的物体表面。          |
| `control_v11p_sd15_openpose_fp16.safetensors`        | OpenPoseDetector     | 人体关键点/姿态控制，适合角色姿势一致性、多人体动作场景或姿态生成。        |
| `control_v11p_sd15_scribble_fp16.safetensors`        | ScribbleDetector     | 涂鸦/草图控制，允许用户用简单草图指导生成，适合创意草稿到成图。          |
| `control_v11p_sd15_seg_fp16.safetensors`             | SegmentationDetector | 语义分割/Mask 控制，保持对象区域准确，适合场景分层生成或特定区域替换。    |
| `control_v11p_sd15_softedge_fp16.safetensors`        | SoftEdgeDetector     | 模糊/柔化边缘控制，适合柔和风格生成或边缘过渡自然的图像处理。           |
| `control_v11p_sd15s2_lineart_anime_fp16.safetensors` | LineartAnimeDetector | 动漫线稿控制，专为动漫风格线稿设计，适合二次创作或动画插画生成。          |
| `control_v11u_sd15_tile_fp16.safetensors`            | TileDetector         | 平铺/Patch 控制升级版，改进重复纹理生成能力，适合大面积背景或纹理图。    |




| 文件名                                 | SD 版本 | 模型类型 | 特点                          |
| ----------------------------------- | ----- | ---- | --------------------------- |
| `ip-adapter_sd15.safetensors`       | SD15  | 基础   | 标准 SD15 通用控制，轻量、兼容性好        |
| `ip-adapter_sd15_light_v11.bin`     | SD15  | 轻量   | 占用显存更低，速度快，精度略低             |
| `ip-adapter_sd15_vit-G.safetensors` | SD15  | 高精度  | 使用 ViT-G backbone，精度更高，显存稍大 |
| `ip-adapter_sdxl.safetensors`       | SDXL  | 基础   | SDXL 通用控制，精度适中              |
| `ip-adapter_sdxl_vit-h.safetensors` | SDXL  | 高精度  | 使用 ViT-H backbone，高精度，高显存   |


| 模型                          | 类型                          | 备注                            |
| --------------------------- | --------------------------- | ----------------------------- |
| `AnyPorn SD 1.5`            | Stable Diffusion checkpoint | NSFW 专用 SD 1.5 版本             |
| `FutaMix` / `RealisticNude` | SD 1.5 / 2.1                | 仅限私人研究使用，公开传播违法               |
| `r18_sd`                    | SD 1.5                      | 成人角色生成模型，HuggingFace 私有库或需要授权 |



| 类型                                     | 控制内容       | 常用预处理器                    | 使用场景           | 说明                   |
| -------------------------------------- | ---------- | ------------------------- | -------------- | -------------------- |
| 🧍 **OpenPose / DWPose**               | 人体姿态（骨架）   | OpenPose / DWPose         | 姿态迁移、人像动作控制    | 控制人物动作，常用于换姿势、舞蹈、动作图 |
| ✏️ **Canny**                           | 边缘线条（轮廓）   | Canny Edge Detector       | 图像结构保持、风格迁移    | 用原图轮廓生成相同结构但不同风格     |
| 🌊 **Depth / Zoe / MiDaS**             | 深度信息（远近）   | Depth Preprocessor        | 保持构图、透视        | 控制画面空间感、景深结构         |
| 🖋️ **Lineart / Lineart Anime**        | 线稿提取       | Lineart Preprocessor      | 动漫风格重绘、草图上色    | 从线稿生成完整画面            |
| ✍️ **Sketch / Scribble**               | 手绘草图       | Scribble Preprocessor     | 草图上色           | 控制画面结构但保留自由风格        |
| 🧱 **MLSD**                            | 直线结构（建筑线）  | MLSD Preprocessor         | 建筑、室内、几何图形生成   | 保持透视、直线结构            |
| 💡 **Normal Map**                      | 法线贴图（表面方向） | Normal Map Detector       | 3D 感觉增强        | 控制物体表面方向、立体光感        |
| 🧩 **Segmentation / Semantic**         | 语义分割（区域分类） | Segmentation Preprocessor | 换背景、场景布局       | 区分天空、人物、建筑、地面等       |
| 🧠 **IPAdapter / FaceID / CLIPVision** | 图像风格 / 特征  | IPAdapter / Face Adapter  | 保持脸部 / 风格 / 特征 | 跨图风格迁移、人脸保持一致        |
| 🔲 **Tile / Inpaint / Shuffle**        | 局部控制       | Tile / Inpaint            | 超分辨率、修复        | 控制局部生成、无缝拼接          |
| 🔺 **Scribble XDoG / SoftEdge**        | 柔和边缘控制     | XDoG / SoftEdge           | 艺术线条、速写风       | 比 Canny 更柔和的线稿控制     |
| 📸 **Reference / Style Adapter**       | 风格参照       | Reference Adapter         | 风格迁移           | 保持参考图风格，结构自由         |
| 🕹️ **ControlNet Shuffle**             | 随机像素结构     | Shuffle                   | 材质迁移、纹理生成      | 抽象风格用途               |
| 🏙️ **ADE20K / Segment Anything**      | 高级语义分割     | ADE20K / SAM              | 精准区域编辑         | AI 自动识别语义区域          |
