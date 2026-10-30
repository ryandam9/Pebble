#!/usr/bin/env python3
"""Patch freshly generated Flutter iOS templates for private camera/OCR use.

Idempotent, using only Python stdlib. The generated directories are kept
untracked during the MVP; generated settings must be reviewed for release.
"""
from __future__ import annotations
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1] / "ios"
if not root.exists():
    print("iOS directory not generated; skipping native setup.")
    raise SystemExit(0)

podfile = root / "Podfile"
if podfile.exists():
    source = podfile.read_text()
    if re.search(r"(?m)^\s*#?\s*platform\s*:ios,", source):
        source = re.sub(
            r"(?m)^\s*#?\s*platform\s*:ios,\s*['\"][\d.]+['\"]",
            "platform :ios, '15.5'",
            source,
            count=1,
        )
    else:
        source = "platform :ios, '15.5'\n" + source
    podfile.write_text(source)

project = root / "Runner.xcodeproj" / "project.pbxproj"
if project.exists():
    source = project.read_text()
    source = re.sub(
        r"IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;",
        "IPHONEOS_DEPLOYMENT_TARGET = 15.5;",
        source,
    )
    project.write_text(source)

info = root / "Runner" / "Info.plist"
if info.exists():
    source = info.read_text()
    usage = ""
    if "NSCameraUsageDescription" not in source:
        usage += (
            "\t<key>NSCameraUsageDescription</key>\n"
            "\t<string>Take photos of receipts to record your expenses.</string>\n"
        )
    if "NSPhotoLibraryUsageDescription" not in source:
        usage += (
            "\t<key>NSPhotoLibraryUsageDescription</key>\n"
            "\t<string>Select a receipt photo to record an expense.</string>\n"
        )
    if usage:
        position = source.rfind("</dict>")
        if position < 0:
            raise RuntimeError("Invalid Runner Info.plist: missing closing dict")
        source = source[:position] + usage + source[position:]
    info.write_text(source)

print("Checked iOS 15.5 and receipt camera/photo permissions.")
