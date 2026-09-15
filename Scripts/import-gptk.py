#!/usr/bin/env python3
"""Validate and import Apple's GPTK 4 redist into an assembled development app."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

MODULES = ('d3d10', 'd3d11', 'd3d12', 'dxgi', 'nvapi64', 'nvngx-on-metalfx')
LEGACY = ('atidxx64', 'nvngx')


def inspect(source):
    source = Path(source).resolve(strict=True)
    lib = source / 'redist/lib'
    framework = lib / 'external/D3DMetal.framework'
    info = framework / 'Resources/Info.plist'
    required = [info, framework / 'D3DMetal', lib / 'external/libd3dshared.dylib',
                source / 'License.rtf', source / 'Read Me.rtf', source / 'Acknowledgements.rtf']
    required += [lib / f'wine/{arch}/{name}.{ext}'
                 for name in MODULES for arch, ext in
                 [('x86_64-windows', 'dll'), ('x86_64-unix', 'so')]]
    for path in required:
        if not path.is_file():
            raise ValueError(f'Missing GPTK file: {path}')
        if not path.resolve().is_relative_to(source):
            raise ValueError(f'GPTK file escapes the supplied directory: {path}')
    # Preserve only relative links internal to the payload, including framework links.
    for path in lib.rglob('*'):
        if path.is_symlink():
            if os.path.isabs(os.readlink(path)) or not path.resolve(strict=True).is_relative_to(lib):
                raise ValueError(f'Invalid GPTK symlink: {path}')
    with info.open('rb') as stream:
        metadata = plistlib.load(stream)
    version = metadata.get('CFBundleShortVersionString', '')
    if not version.startswith('4.'):
        raise ValueError(f'Expected GPTK 4, found {version!r}')
    # Catch new/missing payload names rather than silently making a mixed runtime.
    for arch, ext in [('x86_64-windows', 'dll'), ('x86_64-unix', 'so')]:
        names = {p.name for p in (lib / 'wine' / arch).iterdir() if not p.name.startswith('.')}
        expected = {f'{name}.{ext}' for name in MODULES}
        if names != expected:
            raise ValueError(f'Unrecognized GPTK file set in {arch}: {sorted(names)}')
    return source, lib, version, metadata.get('CFBundleVersion', version)


def remove(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.exists():
        shutil.rmtree(path)


def import_payload(source, app):
    source, lib, version, build = inspect(source)
    app = Path(app).absolute()
    if app.is_symlink():
        raise ValueError('App output must not be a symlink')
    app = app.resolve(strict=True)
    with (app / 'Contents/Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    if info.get('CFBundleIdentifier') != 'com.d4mac.app.dev.gptk4':
        raise ValueError('GPTK import requires a GPTK 4 development app bundle')
    runtime = app / 'Contents/SharedSupport/Wine'
    resources = app / 'Contents/Resources'
    if not (runtime / 'bin/wine').is_file():
        raise ValueError('Stage the baseline Wine runtime before importing GPTK')
    # Never follow an output symlink into the baseline runtime or another app.
    for path in [runtime, resources, runtime / 'lib', runtime / 'lib/external',
                 runtime / 'lib/wine', runtime / 'lib/wine/x86_64-windows',
                 runtime / 'lib/wine/x86_64-unix']:
        if not path.resolve().is_relative_to(app):
            raise ValueError(f'Output path escapes the app: {path}')
    entries = ['external/D3DMetal.framework', 'external/libd3dshared.dylib']
    entries += [f'wine/{arch}/{name}.{ext}' for name in MODULES
                for arch, ext in [('x86_64-windows', 'dll'), ('x86_64-unix', 'so')]]
    # Remove the old framework first: an overlay would retain GPTK 3-only files.
    for relative in entries:
        dst = runtime / 'lib' / relative
        remove(dst)
        dst.parent.mkdir(parents=True, exist_ok=True)
        src = lib / relative
        if src.is_symlink():
            dst.symlink_to(os.readlink(src))
        else:
            subprocess.run(['/usr/bin/ditto', str(src), str(dst)], check=True)
    # Refresh runtime aliases too; Wine's search path must not find GPTK 3 stubs.
    for primary, alias in [('d3d12.dll', 'd3d12_d3dmetal.dll'), ('dxgi.dll', 'dxgi_d3dmetal.dll')]:
        relative = f'wine/x86_64-windows/{alias}'
        dst = runtime / 'lib' / relative
        remove(dst)
        shutil.copy2(runtime / 'lib/wine/x86_64-windows' / primary, dst)
        entries.append(relative)
    for name in LEGACY:
        for arch, ext in [('x86_64-windows', 'dll'), ('x86_64-unix', 'so')]:
            remove(runtime / f'lib/wine/{arch}/{name}.{ext}')
    for name in ('License.rtf', 'Read Me.rtf', 'Acknowledgements.rtf'):
        dst = resources / ('Apple-GPTK-' + name)
        remove(dst)
        shutil.copy2(source / name, dst)
    hashes = {}
    for relative in entries:
        root = runtime / 'lib' / relative
        paths = sorted(root.rglob('*')) if root.is_dir() else [root]
        for path in paths:
            key = str(path.relative_to(runtime))
            if path.is_symlink():
                hashes[key] = {'symlink': os.readlink(path)}
            elif path.is_file():
                hashes[key] = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    manifest = {'version': version, 'build': build,
                'peFiles': [f'{name}.dll' for name in MODULES], 'unsignedPayloadFiles': hashes}
    destination = resources / 'GPTK.json'
    remove(destination)
    destination.write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Imported D3DMetal {version} into {app}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', help='Mounted evaluation environment root (contains redist and License.rtf)')
    parser.add_argument('--app', help='Assembled GPTK 4 development .app; omit to validate only')
    args = parser.parse_args()
    try:
        if args.app:
            import_payload(args.source, args.app)
        else:
            _, _, version, build = inspect(args.source)
            print(f'Validated D3DMetal {version} (build {build})')
    except (ValueError, OSError, plistlib.InvalidFileException, subprocess.CalledProcessError) as error:
        print(f'error: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
