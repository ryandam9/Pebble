#!/usr/bin/env python3
"""Patch freshly generated Flutter platform templates.

iOS: deployment target; camera, photo and location permission text.
Android: app name and location permissions.
Linux: window title.

Idempotent, using only Python stdlib. The generated directories are kept
untracked during the MVP; generated settings must be reviewed for release.
"""
from __future__ import annotations
from pathlib import Path
import re


def configure_ios(root: Path) -> None:
    if not root.exists():
        print("iOS directory not generated; skipping iOS setup.")
        return

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
        if "NSLocationWhenInUseUsageDescription" not in source:
            usage += (
                "\t<key>NSLocationWhenInUseUsageDescription</key>\n"
                "\t<string>Save where you made a purchase.</string>\n"
            )
        if usage:
            position = source.rfind("</dict>")
            if position < 0:
                raise RuntimeError("Invalid Runner Info.plist: missing closing dict")
            source = source[:position] + usage + source[position:]
        info.write_text(source)

    print("Checked iOS 15.5 and camera/photo/location permissions.")


def configure_android(root: Path) -> None:
    manifest = root / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest.exists():
        print("Android directory not generated; skipping Android setup.")
        return
    source = manifest.read_text()
    source = source.replace('android:label="pebble"', 'android:label="Pebble"')
    # GPS for "Current location" on an expense.
    permissions = ""
    for name in ("ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION", "INTERNET"):
        if f"android.permission.{name}" not in source:
            permissions += f'    <uses-permission android:name="android.permission.{name}" />\n'
    if permissions:
        match = re.search(r"<manifest[^>]*>\n", source)
        if match is None:
            raise RuntimeError("Invalid AndroidManifest.xml: missing <manifest> tag")
        source = source[:match.end()] + permissions + source[match.end():]
    manifest.write_text(source)
    print("Checked Android app name and location permissions.")


def configure_linux(root: Path) -> None:
    runner = root / "runner" / "my_application.cc"
    if not runner.exists():
        print("Linux directory not generated; skipping Linux setup.")
        return
    source = runner.read_text()
    # The template titles the window with the lowercase package name.
    source = re.sub(r'(gtk_(?:header_bar|window)_set_title\(\w+, )"pebble"\)', r'\1"Pebble")', source)
    runner.write_text(source)
    print("Checked Linux window title.")


project_root = Path(__file__).resolve().parents[1]
configure_ios(project_root / "ios")
configure_android(project_root / "android")
configure_linux(project_root / "linux")
