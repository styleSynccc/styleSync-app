"""Capture reproducible, sanitized local QA output without installing dependencies."""
from __future__ import annotations

import argparse
import importlib.metadata
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import time
from datetime import datetime, timezone, timedelta

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "testing_evidence"
PYTHON = ROOT / "apps/ai_service/.venv/Scripts/python.exe"
MOBILE = ROOT / "apps/mobile_app"
BACKEND = ROOT / "apps/ai_service"


def clean(value: str) -> str:
    value = re.sub(r"(?i)(Bearer\s+)[A-Za-z0-9._~-]+", r"\1[REDACTED]", value)
    value = re.sub(r"(?i)([?&]token=)[^\s&\"']+", r"\1[REDACTED]", value)
    value = re.sub(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", "[REDACTED_JWT]", value)
    for name, secret in os.environ.items():
        if any(word in name.upper() for word in ("TOKEN", "PASSWORD", "SECRET", "API_KEY")) and len(secret) >= 8:
            value = value.replace(secret, "[REDACTED]")
    return value


def stamp() -> str:
    return datetime.now(timezone(timedelta(hours=8))).isoformat()


def capture(name: str, command: list[str], cwd: Path, timeout: int = 900) -> dict:
    target = EVIDENCE / "logs" / name
    if target.exists():
        raise FileExistsError(f'Preserve existing evidence: {target}. Choose a new --label.')
    target.parent.mkdir(parents=True, exist_ok=True)
    started = stamp()
    start = time.monotonic()
    try:
        result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, encoding="utf-8", errors="replace", timeout=timeout)
        output, code = result.stdout, result.returncode
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or b""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        output += "\nQA runner timeout; execution incomplete.\n"
        code = 124
    except OSError as exc:
        output, code = str(exc), 127
    output = clean(output)
    if "adb_devices" in name:
        output = re.sub(r"(?m)^(\S+)(\s+(?:device|offline|unauthorized)\b)", r"[DEVICE_SERIAL_REDACTED]\2", output)
    meta = {"command": command, "cwd": str(cwd), "started_at": started, "ended_at": stamp(),
            "seconds": round(time.monotonic() - start, 3), "exit_code": code,
            "log": str(target.relative_to(EVIDENCE))}
    target.write_text(output, encoding="utf-8")
    target.with_suffix(target.suffix + ".meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(json.dumps(meta), flush=True)
    print(output[-3500:], flush=True)
    return meta


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["environment", "python-baseline", "flutter-baseline", "python-added", "flutter-added"])
    parser.add_argument('--label', help='Distinct log label when repeating a run for a documented reason')
    args = parser.parse_args()
    if args.label and not re.fullmatch(r'[A-Za-z0-9_-]+', args.label):
        parser.error('--label must contain only letters, numbers, underscores or hyphens')
    action = args.action
    for folder in ("screenshots", "logs/flutter", "logs/fastapi", "logs/firebase", "logs/integration", "reports"):
        (EVIDENCE / folder).mkdir(parents=True, exist_ok=True)
    for uc in range(1, 13):
        (EVIDENCE / "screenshots" / f"UC-{uc:02d}").mkdir(exist_ok=True)
    if action == "environment":
        packages = {}
        for name in ("pytest", "httpx", "fastapi", "numpy", "opencv-python-headless", "pillow", "mediapipe", "rembg", "google-auth", "uvicorn", "python-multipart"):
            try:
                packages[name] = importlib.metadata.version(name)
            except importlib.metadata.PackageNotFoundError:
                packages[name] = "NOT INSTALLED"
        ports = {}
        for port in (4000, 4400, 8000, 8002, 8080, 9099, 9199):
            with socket.socket() as sock:
                sock.settimeout(.3)
                ports[str(port)] = sock.connect_ex(("127.0.0.1", port)) == 0
        data = {"captured_at": stamp(), "python": sys.version, "executable": sys.executable,
                "packages": packages, "tools": {name: shutil.which(name) for name in ("flutter", "dart", "python", "pytest", "firebase", "java", "adb")},
                "localhost_tcp_open": ports,
                "emulator_environment_set": {name: bool(os.getenv(name)) for name in ("FIREBASE_AUTH_EMULATOR_HOST", "FIRESTORE_EMULATOR_HOST", "STORAGE_EMULATOR_HOST")}}
        (EVIDENCE / "logs/integration/environment.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
        print(json.dumps(data, indent=2), flush=True)
        capture("flutter/version.log", [shutil.which("flutter"), "--version"], MOBILE, 90)
        firebase = shutil.which("firebase.cmd") or shutil.which("firebase")
        if firebase:
            capture("firebase/version.log", [firebase, "--version"], MOBILE, 60)
        sdk = Path(os.getenv("LOCALAPPDATA", "")) / "Android/Sdk"
        adb = sdk / "platform-tools/adb.exe"
        if adb.exists():
            capture("integration/adb_devices.log", [str(adb), "devices", "-l"], ROOT, 30)
        emulator = sdk / "emulator/emulator.exe"
        if emulator.exists():
            capture("integration/android_avds.log", [str(emulator), "-list-avds"], ROOT, 30)
    elif action.startswith("python"):
        added = action.endswith("added")
        label = args.label or ("added" if added else "baseline")
        if (EVIDENCE / f'logs/fastapi/{label}.xml').exists():
            raise FileExistsError('Choose a new --label to preserve the existing JUnit result.')
        command = [str(PYTHON), "-m", "pytest", "-vv", "-ra", "--tb=short", "-p", "no:cacheprovider",
                   f"--junitxml={EVIDENCE / ('logs/fastapi/' + label + '.xml')}"]
        if added:
            command.append("tests/test_functional_gaps.py")
        capture(f"fastapi/{label}.log", command, BACKEND)
    else:
        added = action.endswith("added")
        label = args.label or ("added" if added else "baseline")
        if (EVIDENCE / f'logs/flutter/{label}.jsonl').exists():
            raise FileExistsError('Choose a new --label to preserve the existing Flutter result.')
        os.environ['STYLESYNC_QA_FONT_DIR'] = str(Path(shutil.which('flutter')).resolve().parents[1] / 'bin/cache/artifacts/material_fonts')
        command = [shutil.which("flutter"), "test", "--no-pub", "--reporter", "expanded",
                   "--file-reporter", f"json:{EVIDENCE / ('logs/flutter/' + label + '.jsonl')}"]
        if added:
            command.append("test/functional_gaps_test.dart")
        capture(f"flutter/{label}.log", command, MOBILE)


if __name__ == "__main__":
    main()
