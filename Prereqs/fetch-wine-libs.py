#!/usr/bin/env python3
"""Stage the x86_64 FreeType/GnuTLS dependency chain for bundling in
D4Mac.app's Wine runtime (Contents/SharedSupport/Wine/lib/external/).

Why this exists
---------------
The bundled Wine is x86_64 (runs under Rosetta). At runtime it dlopen()s a
handful of unix libraries by bare leaf name — `libfreetype.6.dylib` (font
rendering, used by win32u) and `libgnutls.30.dylib` (TLS, used by secur32/
bcrypt). Those names are resolved via DYLD_FALLBACK_LIBRARY_PATH, which the
launcher points at `lib/external` first (see BNetLauncher.swift). If no
x86_64 build of these libs is found there, dyld falls back to /usr/local/lib
— i.e. an *Intel* Homebrew install. Apple Silicon users who only have ARM
Homebrew (/opt/homebrew) get nothing, so Battle.net Setup renders blank text
(no FreeType) and downloads fail (no GnuTLS).

Shipping x86_64 builds of the whole chain inside lib/external fixes this for
every Apple Silicon user, with no Intel Homebrew required.

Where the dylibs come from
--------------------------
Homebrew stopped publishing x86_64 ("Intel") bottles for current formula
versions — `brew fetch --bottle-tag=sonoma` now reports "unavailable". But
Homebrew's GHCR bottle registry keeps every historical bottle permanently
(content-addressed), and current formulae still have x86_64 macOS bottles
sitting there even when the local formula DSL no longer references them. So
we fetch the bottles straight from ghcr.io with an anonymous token — no
Homebrew needed on the build machine at all.

What gets staged
----------------
We fetch the proven formula set, extract every bottle, then BFS the dylib
dependency graph starting from the two libraries Wine actually dlopen()s and
copy only the reachable x86_64 dylibs. Each copied dylib gets its install id
and every Homebrew dependency path rewritten to `@rpath/<leaf>` so dyld
resolves the whole chain out of lib/external (via DYLD_FALLBACK). System libs
(/usr/lib, /System) are left untouched. A missing leaf is a hard error — that
surfaces a new dependency (e.g. a future brotli requirement) instead of
silently shipping a broken chain.
"""

import glob
import json
import os
import shutil
import subprocess
import sys
import tarfile
import urllib.request

# Formulae whose x86_64 bottles supply the FreeType + GnuTLS dependency chain.
FORMULAE = [
    "freetype",
    "gnutls",
    "libpng",
    "gmp",
    "libtasn1",
    "nettle",
    "gettext",
    "p11-kit",
    "libidn2",
    "libunistring",
]

# The libraries Wine dlopen()s by bare leaf name (confirmed via `strings` on
# win32u.so / secur32.so / bcrypt.so). Everything else is pulled in as a
# transitive dependency by the BFS closure below.
SEEDS = ["libfreetype.6.dylib", "libgnutls.30.dylib"]

# x86_64 macOS bottle tags, preferred newest-first. We never want arm64_* or
# *_linux. A formula's newest version usually still has one of these on GHCR.
X86_OS = ["sequoia", "sonoma", "ventura", "monterey", "big_sur", "catalina"]

GHCR = "https://ghcr.io/v2/homebrew/core"
HOMEBREW_PREFIXES = ("@@HOMEBREW", "/opt/homebrew", "/usr/local")


def _token(formula):
    url = (
        f"https://ghcr.io/token?service=ghcr.io"
        f"&scope=repository:homebrew/core/{formula}:pull"
    )
    return json.load(urllib.request.urlopen(url))["token"]


def _get(url, tok, accept):
    req = urllib.request.Request(
        url, headers={"Authorization": f"Bearer {tok}", "Accept": accept}
    )
    return urllib.request.urlopen(req)


def _pick_x86_bottle(formula, tok):
    """Newest version of `formula` that has an x86_64 macOS bottle on GHCR.

    Returns (version, os_tag, blob_layer_digest).
    """
    tags = json.load(_get(f"{GHCR}/{formula}/tags/list", tok, "application/json"))[
        "tags"
    ]
    for version in reversed(tags):  # tags come oldest-first; want newest
        try:
            index = json.load(
                _get(
                    f"{GHCR}/{formula}/manifests/{version}",
                    tok,
                    "application/vnd.oci.image.index.v1+json",
                )
            )
        except Exception:
            continue
        avail = {}
        for m in index.get("manifests", []):
            tag = m.get("annotations", {}).get("org.opencontainers.image.ref.name", "")
            avail[tag] = m["digest"]
        for os_tag in X86_OS:
            for tag, digest in avail.items():
                if tag.endswith("." + os_tag):
                    manifest = json.load(
                        _get(
                            f"{GHCR}/{formula}/manifests/{digest}",
                            tok,
                            "application/vnd.oci.image.manifest.v1+json",
                        )
                    )
                    return version, os_tag, manifest["layers"][0]["digest"]
    raise SystemExit(f"error: no x86_64 macOS bottle for {formula} on GHCR")


def fetch_and_extract(formula, cache, extract_root):
    tok = _token(formula)
    version, os_tag, layer = _pick_x86_bottle(formula, tok)
    tgz = os.path.join(cache, f"{formula}-{version}.{os_tag}.tar.gz")
    if not os.path.exists(tgz):
        with _get(
            f"{GHCR}/{formula}/blobs/{layer}", tok, "application/octet-stream"
        ) as r, open(tgz, "wb") as f:
            shutil.copyfileobj(r, f)
    with tarfile.open(tgz) as t:
        try:
            t.extractall(extract_root, filter="data")  # py3.12+
        except TypeError:
            t.extractall(extract_root)
    print(f"  {formula:12} {version}.{os_tag}  ({os.path.getsize(tgz)//1024} KB)")


def real_dylibs(extract_root):
    """Map every dylib leaf name -> its real (symlink-resolved) path across
    all bottles. Sonames like libnettle.9.dylib are usually symlinks to a
    fully-versioned file (libnettle.9.0.dylib); dependents reference the
    soname, so we key on both and resolve to the real bytes."""
    out = {}
    for path in glob.glob(f"{extract_root}/*/*/lib/*.dylib"):
        out[os.path.basename(path)] = os.path.realpath(path)
    return out


def deps(dylib):
    """Non-system dependency leaf names of a Mach-O dylib."""
    txt = subprocess.run(["otool", "-L", dylib], capture_output=True, text=True).stdout
    result = []
    for line in txt.splitlines()[1:]:
        path = line.strip().split(" ")[0]
        if path.startswith(HOMEBREW_PREFIXES):
            result.append(os.path.basename(path))
    return result


def closure(seeds, table):
    """BFS the dependency graph; return the set of leaf names to ship."""
    need, queue = set(), list(seeds)
    while queue:
        leaf = queue.pop()
        if leaf in need:
            continue
        if leaf not in table:
            raise SystemExit(
                f"error: dependency {leaf} not provided by any fetched "
                f"bottle — add the formula that ships it to FORMULAE"
            )
        need.add(leaf)
        queue.extend(deps(table[leaf]))
    return need


def rewrite(dylib):
    """Set id and Homebrew deps to @rpath/<leaf> so dyld resolves from
    lib/external. Leaves /usr/lib and /System references alone."""
    leaf = os.path.basename(dylib)
    subprocess.run(
        ["install_name_tool", "-id", f"@rpath/{leaf}", dylib], capture_output=True
    )
    txt = subprocess.run(["otool", "-L", dylib], capture_output=True, text=True).stdout
    for line in txt.splitlines()[1:]:
        path = line.strip().split(" ")[0]
        if path.startswith(HOMEBREW_PREFIXES):
            base = os.path.basename(path)
            subprocess.run(
                ["install_name_tool", "-change", path, f"@rpath/{base}", dylib],
                capture_output=True,
            )


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    out_dir = (
        sys.argv[1] if len(sys.argv) > 1 else os.path.join(script_dir, "wine-libs")
    )
    cache = os.path.join(out_dir, ".cache")
    extract_root = os.path.join(cache, "extract")
    shutil.rmtree(extract_root, ignore_errors=True)
    os.makedirs(extract_root, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)

    print("==> fetching x86_64 bottles from GHCR")
    for formula in FORMULAE:
        fetch_and_extract(formula, cache, extract_root)

    table = real_dylibs(extract_root)
    need = sorted(closure(SEEDS, table))
    print(f"==> staging {len(need)} dylibs (closure of {', '.join(SEEDS)})")

    for leaf in need:
        dst = os.path.join(out_dir, leaf)
        shutil.copy(table[leaf], dst)
        os.chmod(dst, 0o644)
        rewrite(dst)
        arch = subprocess.run(
            ["file", "-b", dst], capture_output=True, text=True
        ).stdout
        tag = "x86_64" if "x86_64" in arch else "??ARCH??"
        print(f"  {leaf:24} [{tag}]")

    shutil.rmtree(cache, ignore_errors=True)
    print(f"\n✓ wine libs staged in {out_dir}")


if __name__ == "__main__":
    main()
