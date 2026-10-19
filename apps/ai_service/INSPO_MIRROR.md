# AI Inspo Mirror

The `/inspo` Flutter screen uploads an inspiration photo and the ID of a saved
twin to the authenticated `POST /v1/inspo` endpoint. The API loads the twin from
the signed-in user's namespace and requests a single Try-On Max generation at
Balanced 1K (currently 2 FASHN credits per successful output).

The source photo goes directly to FASHN as the outfit reference. It is not added
to the closet or processed through local garment extraction. The reference is
not retained by the StyleSync API. The generated result is saved in the existing
API result store, and returned to Flutter for preview. Tapping Save Outfit stores
it using the existing Firebase `users/{uid}/likedOutfits` collection and
`users/{uid}/liked_outfits/` Storage folder, with source `inspo`.

## Start with your API key

For this Windows setup, the private key is stored in `apps/ai_service/.env`
(ignored by Git). Replace its `FASHN_API_KEY` value locally when rotating keys.
Start from the repository root with:

```powershell
.\apps\ai_service\start.ps1
```

This script reads the local key without displaying it. It listens on the PC's
network interfaces for wireless testing by default. Stop the previous API before restarting. An already
running server must be restarted to load a replacement key.

## Wireless phone connection

The current Wi-Fi build uses `http://10.101.72.146:8000`. Keep the PC awake and
both devices on the same Wi-Fi. The USB cable and ADB reverse tunnel are not
needed for this build. Start the backend using `start.ps1` above; its default
`0.0.0.0` binding accepts connections from the phone. If the PC's address changes,
rebuild with `--dart-define=AI_SERVICE_BASE_URL=http://NEW_PC_IP:8000` and install
the updated app. The API key remains on the backend. Use `-BindAddress 127.0.0.1`
when you want to restrict the backend to USB/local testing instead.

In a PowerShell terminal at the repository root, enter the key privately at a
masked prompt, then start the main API. Never commit the key or put it in Flutter.

```powershell
$fashnSecret = Read-Host 'FASHN API key' -AsSecureString
$env:FASHN_API_KEY = [System.Net.NetworkCredential]::new('', $fashnSecret).Password
cd apps/ai_service
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Stop an existing main API process in its terminal before restarting on port 8000.
An environment variable set in a new terminal does not update an already-running
server. For an optional USB connection, retain the reverse tunnel
(`adb reverse tcp:8000 tcp:8000`) and build with
`--dart-define=AI_SERVICE_BASE_URL=http://127.0.0.1:8000`.
The local FASHN worker is not used for Inspo Mirror, but is still needed by the
existing local VTON and clothing-upload features.

## Validation and limitations

Tests mock FASHN: they verify authentication, twin ownership, image validation,
provider payload, result persistence, and provider failures without spending
credits. A real FASHN key and credits are required to evaluate outfit fidelity.
The full-outfit reference workflow is an integration to evaluate, not a guarantee
that every garment, shoe, face detail, or head covering will be preserved.
The result is a 2D image, not clothing applied to a 3D mesh.

Requests are submitted once, with no automatic paid retries. Stay on the page
until generation completes. If a connection is lost after submission, FASHN may
still complete and charge for the output; do not immediately submit it again.
