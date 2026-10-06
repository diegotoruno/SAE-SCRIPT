"""Install the pinned official Luau CLI, verify it, then compile and test."""
import hashlib
import io
import os
from pathlib import Path
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent
VERSION = "0.741"
PLATFORMS = {
    "linux": ("ubuntu", "134dc762ad26232af83e43f98dec03ff6030dd3a4452f9408b9d50ccea025503"),
    "win32": ("windows", "be90c3223f3dc26777ef234244c2b1eae16b3c574f1ab7d1446972f72c28cab1"),
    "darwin": ("macos", "839cc1de39b0f765fbaea8e89421c12acfed6bd3d8d2cc2a2d3fc64bdde32b0f"),
}


def check():
    platform, digest = PLATFORMS[sys.platform]
    target = ROOT / ".tools" / VERSION
    target.mkdir(parents=True, exist_ok=True)
    archive = target / "luau.zip"
    if not archive.exists():
        url = f"https://github.com/luau-lang/luau/releases/download/{VERSION}/luau-{platform}.zip"
        request = urllib.request.Request(url, headers={"User-Agent": "SAE-SCRIPT-CI"})
        with urllib.request.urlopen(request, timeout=60) as response:
            archive.write_bytes(response.read())
    data = archive.read_bytes()
    assert hashlib.sha256(data).hexdigest() == digest, "Luau download checksum mismatch"
    with zipfile.ZipFile(io.BytesIO(data)) as package:
        for tool in ("luau", "luau-compile"):
            name = tool + (".exe" if os.name == "nt" else "")
            executable = target / name
            executable.write_bytes(package.read(name))
            executable.chmod(0o755)
    suffix = ".exe" if os.name == "nt" else ""
    compiler = target / ("luau-compile" + suffix)
    runtime = target / ("luau" + suffix)
    files = ["map_egg_search.luau", "egg_filter_panel.luau", "hopper_runtime.luau",
             "loader.luau", "chilli_hopper.luau", "ci_tests.luau", "dist/chilli_hopper.luau"]
    for filename in files:
        result = subprocess.run([str(compiler), str(ROOT / filename)],
                                cwd=ROOT, capture_output=True, text=True,
                                encoding="utf-8", errors="replace")
        if result.returncode:
            raise RuntimeError(f"Compile failed: {filename}\n{result.stdout}\n{result.stderr}")
        print(f"Compile OK: {filename}")
    subprocess.run([str(runtime), "ci_tests.luau"], cwd=ROOT, check=True)


if __name__ == "__main__":
    check()
