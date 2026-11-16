"""Summarize this execution's native test results without rerunning tests."""
import hashlib
import json
import subprocess
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from pathlib import Path

RUN = Path(__file__).resolve().parent
ROOT = RUN.parents[2]


def flutter_results(path):
    suites, tests, errors, outcomes = {}, {}, defaultdict(list), []
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        event = json.loads(line)
        if event["type"] == "suite":
            suites[event["suite"]["id"]] = event["suite"]["path"]
        elif event["type"] == "testStart":
            tests[event["test"]["id"]] = event["test"]
        elif event["type"] == "error":
            errors[event["testID"]].append(event)
        elif event["type"] == "testDone":
            test = tests[event["testID"]]
            # Runner setup/teardown and loading events are not test cases.
            if event["hidden"]:
                continue
            outcomes.append({
                "suite": "flutter", "file": suites[test["suiteID"]],
                "name": test["name"], "line": test.get("line"),
                "status": "skipped" if event["skipped"] else event["result"],
                "errors": errors[event["testID"]],
            })
    return outcomes


outcomes = flutter_results(RUN / "flutter.jsonl")
for suite in ("backend", "worker"):
    for case in ET.parse(RUN / f"{suite}.xml").iter("testcase"):
        status = "success"
        errors = []
        for tag in ("failure", "error", "skipped"):
            node = case.find(tag)
            if node is not None:
                status = "skipped" if tag == "skipped" else tag
                errors.append({"message": node.get("message"), "detail": node.text})
        outcomes.append({"suite": suite, "file": case.get("classname"),
                         "name": case.get("name"), "status": status,
                         "duration_seconds": case.get("time"), "errors": errors})

metadata = {s: json.loads((RUN / f"{s}.meta.json").read_text(encoding="utf-8-sig"))
            for s in ("flutter", "backend", "worker")}
counts = {s: Counter(t["status"] for t in outcomes if t["suite"] == s) for s in metadata}
failures = [t for t in outcomes if t["status"] not in ("success", "skipped")]
historical = ROOT / "testing_evidence/logs/flutter/suite_20261116_run2.jsonl"
previous_failures = {t["name"] for t in flutter_results(historical)
                     if t["status"] not in ("success", "skipped")}
current_failures = {t["name"] for t in failures if t["suite"] == "flutter"}
revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
tracked_diff = subprocess.check_output(["git", "diff", "HEAD", "--name-only"], cwd=ROOT, text=True).splitlines()
summary = {"revision": revision, "timezone": "Asia/Kuala_Lumpur",
           "metadata": metadata, "counts": counts, "tests": outcomes,
           "historical_flutter_failure_names_match": current_failures == previous_failures,
           "new_flutter_failure_names_vs_historical": sorted(current_failures - previous_failures),
           "tracked_files_changed_after_run": tracked_diff}
(RUN / "results.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

report = ["# Unit and regression test results", "",
          "Executed 16 November 2026, 23:23:34-23:23:58 Asia/Kuala_Lumpur (UTC+08:00).",
          f"Revision: `{revision}`. Existing cached dependencies were used.", "",
          "**Result: 268 passed, 6 failed, 0 skipped across 274 tests.** The full Flutter, backend and worker suites were executed once. This includes existing unit, widget, API/component and mocked workflow regression checks; these categories overlap and are not additional test runs.", "",
          "| Suite | Passed | Failed | Skipped | Exit code |",
          "| --- | ---: | ---: | ---: | ---: |"]
for suite, counter in counts.items():
    failed = sum(v for k, v in counter.items() if k not in ("success", "skipped"))
    report.append(f"| {suite} | {counter['success']} | {failed} | {counter['skipped']} | {metadata[suite]['exit_code']} |")
report += ["", "## Failures", "",
           "All six failures occur in `apps/mobile_app/test/generation_confirmation_test.dart`. Each assertion expects a credit total in the dialog title, but finds zero matching widgets. The implementation in `apps/mobile_app/lib/widgets/generation_confirmation.dart` displays `Generate outfit?` and a plain `Generate` button; it does not display the calculated credit total.", "",
           "| Test | Expected title | Source assertion |", "| --- | --- | --- |"]
expected = {"VTON shows the total and cancellation declines generation": (9, 42),
            "Inspo confirms exactly one three-credit generation": (3, 76),
            "cost confirmation remains usable in landscape": (24, 118),
            "Fast confirmation shows its own total": (3, 203),
            "Balanced confirmation shows its own total": (6, 203),
            "Quality confirmation shows its own total": (9, 203)}
for failure in failures:
    credits, line = expected[failure["name"]]
    report.append(f"| {failure['name']} | Generate for {credits} credits? | generation_confirmation_test.dart:{line} |")
report += ["", "These six failure names match the earlier [suite execution](../../reports/suite_20261116_run2_Results.md) and its native JSONL results. No additional failing test names were observed against that historical run. This comparison does not establish that the earlier run used identical source or coverage. Cancellation, approval and landscape usability assertions later in these six tests are not reached after the first failure.", "",
           "## Coverage and limits", "",
           "The run exercises authentication/profile validation, password reset, wardrobe upload/cancellation/category selection, twin workflows, try-on and inspiration request/confirmation behavior, outfit persistence/preview, planner dates/cancellation/reminders, image/pose/mask handling, API validation/ownership, provider payloads, and garment extraction/skirt retry behavior.", "",
           "Firebase, image pickers, notification channels, provider HTTP and model engines are faked where applicable. No Android device interaction, real Firebase persistence, reminder delivery or live AI visual quality was executed. The manual/integration procedures in [Functional_Gap_Manual_Guide.md](../../reports/Functional_Gap_Manual_Guide.md) remain unexecuted by this run. A single passing Flutter `Placeholder test` checks `1 + 1 == 2` and supplies no functional coverage.", "",
           "Both Python suites emit one Starlette deprecation warning about TestClient's use of HTTPX. These warnings do not fail the suites. The worker tests ran using the existing backend virtual environment because the worker has no installed virtual environment; mocked worker logic was tested without downloading models.", "",
           "## Evidence and reproduction", "",
           "[Machine-readable results](results.json) include every test outcome, failure details, commands, working directories, timestamps and exit codes. [SHA-256 manifest](manifest.json) records the artifacts.", ""]
for suite in metadata:
    native = "flutter.jsonl" if suite == "flutter" else f"{suite}.xml"
    report += [f"- {suite}: [terminal log]({suite}.log), [native results]({native}), [execution metadata]({suite}.meta.json)."]
report += ["", "Commands were executed from each application's directory:", "", "```powershell"]
for suite in metadata:
    report += [f"# {metadata[suite]['cwd']}", metadata[suite]["command"]]
report += ["```", "", "Existing tests regenerated three widget screenshots. New captures are preserved under `widget_screenshots/`; original images were backed up under `original_widget_screenshots/` and restored to their original paths. No application code, test source, dependencies or configuration was changed. The tracked diff after restoration is empty.", "", "## Per-file outcomes", "",
           "| Suite | File/class | Passed | Failed | Skipped |", "| --- | --- | ---: | ---: | ---: |"]
by_file = defaultdict(Counter)
for test in outcomes:
    by_file[(test["suite"], test["file"])][test["status"]] += 1
for (suite, path), counter in sorted(by_file.items()):
    label = Path(path).name if suite == "flutter" else path
    failed = sum(v for k, v in counter.items() if k not in ("success", "skipped"))
    report.append(f"| {suite} | {label} | {counter['success']} | {failed} | {counter['skipped']} |")
assert sum(c["success"] for c in counts.values()) == 268
assert len(failures) == 6 and len(outcomes) == 274
assert not tracked_diff, tracked_diff
assert current_failures == previous_failures
(RUN / "Results.md").write_text("\n".join(report) + "\n", encoding="utf-8")
manifest = [{"path": str(p.relative_to(RUN)).replace("\\", "/"),
             "bytes": p.stat().st_size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
            for p in sorted(RUN.rglob("*")) if p.is_file() and p.name != "manifest.json"]
(RUN / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print(json.dumps({"counts": counts, "total": len(outcomes),
                  "historical_failure_names_match": current_failures == previous_failures,
                  "tracked_diff": tracked_diff, "report": str(RUN / "Results.md")}, indent=2))
