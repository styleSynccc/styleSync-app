# StyleSync CatVTON worker

This isolated local service wraps the official
[CatVTON](https://github.com/Zheng-Chong/CatVTON) inference pipeline for the
StyleSync API. CatVTON is licensed CC BY-NC-SA 4.0 and may only be used here
for non-commercial/research purposes.

From PowerShell at the repository root:

```powershell
.\apps\catvton_worker\setup.ps1
.\apps\catvton_worker\start.ps1
```

The first generation downloads several gigabytes of model weights and can take
several minutes. Downloads are resumable and use Hugging Face's accelerated
transfer helper. The worker defaults to 384x512 FP16 inference for the 6 GB GPU
on this development machine. Override `CATVTON_WIDTH`, `CATVTON_HEIGHT`, or
`CATVTON_STEPS` before starting the worker when needed.

In a second PowerShell terminal, start the main API as usual:

```powershell
cd apps/ai_service
..\..\API\venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

The Flutter emulator talks to port 8000 through `10.0.2.2`; the main API talks
to the CatVTON worker locally on port 8001.

With the worker running, either supported category can be smoke-tested using
the repository's sample assets:

```powershell
.\apps\catvton_worker\.venv\Scripts\python.exe .\apps\catvton_worker\smoke_test.py
.\apps\catvton_worker\.venv\Scripts\python.exe .\apps\catvton_worker\smoke_test.py --category Pants
```
