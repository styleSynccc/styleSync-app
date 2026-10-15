# FastFit try-on test setup (local, outside this repo)

FastFit is a third-party model (https://github.com/Zheng-Chong/FastFit,
non-commercial license). It is cloned next to this repo, not inside it.
`fastfit_local_fixes.patch` holds our two changes to it:

1. Only items you upload get replaced. Upstream always erases the whole
   outfit, so uploading just a top also regenerates the pants.
2. Transparent PNG person photos get a white background. Upstream turns
   the transparent area black.

## Steps on a new PC

Needs an NVIDIA GPU. Tested on an RTX 4050 Laptop (6GB VRAM), using about
2.7GB once loaded.

```bash
# 1. Clone FastFit next to styleSync-app, at the commit the patch was made on
cd "<folder that contains styleSync-app>"
git clone https://github.com/Zheng-Chong/FastFit.git
cd FastFit
git checkout 9c96fc019d71a52a01285b1a4b06450cb4826677

# 2. Apply our fixes
git apply ../styleSync-app/tools/fastfit/fastfit_local_fixes.patch

# 3. Python 3.11 virtual environment
python -m venv .venv
.venv\Scripts\activate

# 4. PyTorch with CUDA. Run `nvidia-smi` first: cu124 needs a driver that
#    reports CUDA 12.x. torch must be 2.6 or newer (diffusers needs
#    torch.accelerator); the cu121 index stops at 2.5.1, so don't use it.
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu124

# 5. Everything else
pip install -r requirements.txt
pip install easy-dwpose --no-dependencies

# 6. Run. The first run downloads about 5GB of weights into Models/.
#    Copy Models/ from another machine instead to skip the download.
python app.py
```

Then open http://localhost:7860.

## Known issues

- "no file named diffusion_pytorch_model.safetensors" on startup is a
  harmless warning; it loads the .bin weights instead.
- Use full-body photos. The model does poorly on cropped upper-body shots.
- No hijab support: the model only knows top, bottom, dress, shoe and bag.
