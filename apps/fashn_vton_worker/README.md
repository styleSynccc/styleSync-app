# StyleSync FASHN VTON worker

Skirt try-on uses clothing masking, 30 sampling steps, and guidance 3.0 to
reduce retention of the original pants. The parser checks for a skirt in
the result. If it cannot detect one, the worker retries with another seed
once, then returns an error instead of saving the failed result. This is a
model-based check, not a guarantee of exact garment fidelity.

The worker also serves `POST /extract-garment` for closet uploads. For Tops,
Pants, and Skirts photographed on a person, it uses FASHN Human Parser to isolate
only the selected clothing class. The main API crops and centers the masked
garment on white before saving it. Product-only images keep background
removal. Keep the worker running when uploading Tops, Pants, or Skirts; a detection
failure rejects the upload instead of saving the whole person. This applies
to new uploads; existing closet photos need to be added again to be processed.

This isolated local service runs the maskless
[FASHN VTON v1.5](https://github.com/fashn-AI/fashn-vton-1.5) pipeline under
the Apache-2.0 license.

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

Accessories can be selected in VTON alongside a top, bottoms, and shoes. Up to
five accessories are supported per result (hats, glasses, jewelry, or bags). They
run sequentially in selection order, each using the previous generated result.
Choose different accessory types; items in the same location can replace one another.
The picker shows selected count and accessory credit subtotal. Accessories
run last using hosted Try-On Max at Balanced 1K, currently 2 credits per successful
output; they are never selected automatically. Use a clear photo of the accessory
alone. Existing gallery accessories are synchronized from the closet on refresh.
The full twin frame is retained for accessories so hats and bags have room.
Real placement accuracy depends on the input and needs evaluation with credits.

The local open-source model handles Tops, Pants, and Skirts. Shoes are sent by the main
API to FASHN Try-On Max because the local v1.5 model has no footwear category.
Create the key in the FASHN developer dashboard and keep it on the backend;
never add it to Flutter or commit it to this repository. Shoe generation uses
paid FASHN API credits. If `FASHN_API_KEY` is absent, Tops/Pants keep working
and selecting Shoes returns a clear configuration error.

After starting the FASHN worker, test it with:

```powershell
.\apps\fashn_vton_worker\.venv\Scripts\python.exe .\apps\fashn_vton_worker\smoke_test.py
```
