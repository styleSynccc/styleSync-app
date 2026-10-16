# StyleSync FASHN VTON worker

This isolated local service runs the maskless
[FASHN VTON v1.5](https://github.com/fashn-AI/fashn-vton-1.5) pipeline. Its
Apache-2.0 license is friendlier to a future commercial app than CatVTON's
non-commercial license.

From PowerShell at the repository root:

```powershell
.\apps\fashn_vton_worker\setup.ps1
.\apps\fashn_vton_worker\start.ps1
```

The setup downloads a separate Python environment and roughly 2.25 GB of
model weights. The worker listens on port 8002 and defaults to the upstream
20-step fast preset. Set `$env:FASHN_VTON_STEPS = '30'` before starting it to
use the slower balanced preset. Start the main API in another
terminal:

```powershell
cd apps/ai_service
$env:FASHN_API_KEY = 'your-key' # required only for the Shoes option
..\..\API\venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

The local open-source model handles Tops and Pants. Shoes are sent by the main
API to FASHN Try-On Max because the local v1.5 model has no footwear category.
Create the key in the FASHN developer dashboard and keep it on the backend;
never add it to Flutter or commit it to this repository. Shoe generation uses
paid FASHN API credits. If `FASHN_API_KEY` is absent, Tops/Pants keep working
and selecting Shoes returns a clear configuration error.

Do not keep CatVTON and FASHN loaded simultaneously on a low-VRAM GPU. The API
uses only FASHN by default so model comparisons cannot be confused by a silent
fallback. To select an engine or deliberately enable a fallback before
starting the main API:

```powershell
$env:TRYON_ENGINE = 'fashn'             # or 'catvton'
$env:TRYON_FALLBACK_ENGINE = 'catvton'  # optional; empty by default
```

After starting the FASHN worker, test it with:

```powershell
.\apps\fashn_vton_worker\.venv\Scripts\python.exe .\apps\fashn_vton_worker\smoke_test.py
```
