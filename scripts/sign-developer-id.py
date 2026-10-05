#!/usr/bin/env python3
"""Sign a fresh ClipNest copy inside-out, using the approved login-Keychain identity.

No certificate/key creation, private-key export, credential input, notarization upload,
or installed application modification. --execute is required for a new output copy.
"""
import argparse
import pathlib
import plistlib
import re
import subprocess

TEAM = "C2C48NP2VN"
KEYCHAIN = pathlib.Path.home() / "Library/Keychains/login.keychain-db"

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("source_app", type=pathlib.Path)
parser.add_argument("output_directory", type=pathlib.Path)
parser.add_argument("--execute", action="store_true", help="Create and sign a fresh copy; default only checks the plan")
parser.add_argument("--identity", required=True, help="Public SHA1 fingerprint of the approved Developer ID Application certificate")
options = parser.parse_args()
IDENTITY = options.identity.upper()
assert re.fullmatch(r"[0-9A-F]{40}", IDENTITY), "Use a certificate fingerprint, not an ambiguous name"
source = options.source_app.resolve(strict=True)
output = options.output_directory.absolute()
assert source.name == "ClipNest.app" and source.is_dir(), "Expected ClipNest.app"
assert not output.exists(), "Refusing to overwrite any previous output"
info = plistlib.loads((source / "Contents/Info.plist").read_bytes())
assert info["CFBundleIdentifier"] == "app.clipnest.mac", "Wrong application"
assert info["LSUIElement"] is True and info["LSMinimumSystemVersion"] == "13.0"
assert info.get("SUPublicEDKey"), "Sparkle public key must remain embedded"

def signing_nodes(app):
    framework = app / "Contents/Frameworks/Sparkle.framework"
    inner = framework / "Versions/B"
    return [(inner / "XPCServices/Installer.xpc", False),
            (inner / "XPCServices/Downloader.xpc", True),
            (inner / "Autoupdate", False), (inner / "Updater.app", False),
            (framework, False), (app, False)]

for node, _ in signing_nodes(source):
    assert node.exists(), f"Missing required signing component: {node}"
    assert node.resolve().is_relative_to(source), "Bundled symlink escapes source application"
print(f"Plan: ClipNest {info['CFBundleShortVersionString']} build {info['CFBundleVersion']}, team {TEAM}")
print("Six signing nodes, inside-out; Hardened Runtime and secure timestamp; no --deep signing")
print("Downloader entitlements preserved; no new permission or relaxed library validation")
if not options.execute:
    raise SystemExit(0)

identities = subprocess.check_output(["security", "find-identity", "-v", "-p", "codesigning", str(KEYCHAIN)], text=True)
assert sum(IDENTITY in line and "Developer ID Application:" in line and f"({TEAM})" in line for line in identities.splitlines()) == 1, "Approved signing identity unavailable"
output.mkdir(parents=True)
app = output / "ClipNest.app"
subprocess.run(["ditto", "--norsrc", "--noextattr", str(source), str(app)], check=True)

for node, preserve in signing_nodes(app):
    command = ["codesign", "--force", "--sign", IDENTITY, "--keychain", str(KEYCHAIN), "--options", "runtime", "--timestamp"]
    if preserve:
        command.append("--preserve-metadata=entitlements")
    subprocess.run(command + [str(node)], check=True)

for node, _ in signing_nodes(app):
    subprocess.run(["codesign", "--verify", "--strict", str(node)], check=True)
    details = subprocess.run(["codesign", "--display", "--verbose=4", str(node)], check=True, capture_output=True, text=True).stderr
    assert f"TeamIdentifier={TEAM}" in details, f"Wrong team for {node}"
    assert "runtime" in details and "Timestamp=" in details, f"Runtime/timestamp missing: {node}"
    entitlements = subprocess.run(["codesign", "--display", "--entitlements", ":-", str(node)], check=True, capture_output=True).stdout
    if entitlements.strip():
        values = plistlib.loads(entitlements)
        assert not values.get("com.apple.security.get-task-allow"), "Debug entitlement forbidden"
        assert not values.get("com.apple.security.cs.disable-library-validation"), "Do not relax library validation"

subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
print(f"PASS: all six components use {TEAM}, valid signatures, runtime, secure timestamps")
print(f"Fresh signed candidate: {app}")
