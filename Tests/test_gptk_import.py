"""Run with: python3 -m unittest discover -s Tests -p 'test_gptk_import.py'"""
import importlib.util
import json
from pathlib import Path
import plistlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('gptk', Path(__file__).parents[1] / 'Scripts/import-gptk.py')
gptk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gptk)


class ImportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'GPTK with spaces'
        self.lib = self.source / 'redist/lib'
        self.framework = self.lib / 'external/D3DMetal.framework'
        resources = self.framework / 'Versions/A/Resources'
        resources.mkdir(parents=True)
        (resources / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': '4.0b2'}))
        (self.framework / 'Versions/A/D3DMetal').write_bytes(b'new framework')
        (self.framework / 'Versions/Current').symlink_to('A')
        (self.framework / 'Resources').symlink_to('Versions/Current/Resources')
        (self.framework / 'D3DMetal').symlink_to('Versions/Current/D3DMetal')
        (self.lib / 'external/libd3dshared.dylib').write_bytes(b'new shared')
        for name in gptk.MODULES:
            pe = self.lib / f'wine/x86_64-windows/{name}.dll'
            pe.parent.mkdir(parents=True, exist_ok=True)
            pe.write_bytes(name.encode())
            so = self.lib / f'wine/x86_64-unix/{name}.so'
            so.parent.mkdir(parents=True, exist_ok=True)
            so.symlink_to('../../external/libd3dshared.dylib')
        for name in ('License.rtf', 'Read Me.rtf', 'Acknowledgements.rtf'):
            (self.source / name).write_text(name)
        self.app = self.root / 'Development.app'
        self.runtime = self.app / 'Contents/SharedSupport/Wine'
        (self.runtime / 'bin').mkdir(parents=True)
        (self.runtime / 'bin/wine').write_bytes(b'original wine')
        (self.app / 'Contents/Resources').mkdir()
        self.info = self.app / 'Contents/Info.plist'
        self.info.write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.d4mac.app.dev.gptk4'}))
        for relative in ['external/D3DMetal.framework/obsolete', 'external/dxmt/keep',
                         'wine/i386-windows/d3d11.dll', 'wine/x86_64-unix/ntdll.so',
                         'wine/x86_64-windows/atidxx64.dll', 'wine/x86_64-unix/nvngx.so',
                         'wine/x86_64-windows/d3d12_d3dmetal.dll']:
            path = self.runtime / 'lib' / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'original')

    def test_import_preserves_wine_dxmt_and_relative_symlinks(self):
        gptk.import_payload(self.source, self.app)
        for relative in ['external/dxmt/keep', 'wine/i386-windows/d3d11.dll', 'wine/x86_64-unix/ntdll.so']:
            self.assertEqual((self.runtime / 'lib' / relative).read_bytes(), b'original')
        self.assertEqual((self.runtime / 'bin/wine').read_bytes(), b'original wine')
        self.assertEqual((self.runtime / 'lib/wine/x86_64-windows/d3d12_d3dmetal.dll').read_bytes(), b'd3d12')
        link = self.runtime / 'lib/wine/x86_64-unix/d3d10.so'
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.read_bytes(), b'new shared')
        self.assertFalse((self.runtime / 'lib/external/D3DMetal.framework/obsolete').exists())
        self.assertFalse((self.runtime / 'lib/wine/x86_64-windows/atidxx64.dll').exists())
        self.assertFalse((self.runtime / 'lib/wine/x86_64-unix/nvngx.so').exists())
        self.assertEqual((self.app / 'Contents/Resources/Apple-GPTK-License.rtf').read_text(), 'License.rtf')
        manifest = json.loads((self.app / 'Contents/Resources/GPTK.json').read_text())
        self.assertEqual(manifest['version'], '4.0b2')
        self.assertIn('d3d10.dll', manifest['peFiles'])
        gptk.import_payload(self.source, self.app)  # repeat without accumulating old files

    def test_missing_payload_fails_before_writing(self):
        (self.lib / 'wine/x86_64-windows/d3d12.dll').unlink()
        with self.assertRaises(ValueError):
            gptk.import_payload(self.source, self.app)
        self.assertTrue((self.runtime / 'lib/external/D3DMetal.framework/obsolete').exists())

    def test_rejects_non_development_app(self):
        self.info.write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.d4mac.app'}))
        with self.assertRaises(ValueError):
            gptk.import_payload(self.source, self.app)

    def test_rejects_unknown_version_or_file_set(self):
        info = self.framework / 'Resources/Info.plist'
        info.write_bytes(plistlib.dumps({'CFBundleShortVersionString': '3.0'}))
        with self.assertRaises(ValueError):
            gptk.inspect(self.source)
        info.write_bytes(plistlib.dumps({'CFBundleShortVersionString': '4.0b2'}))
        (self.lib / 'wine/x86_64-windows/surprise.dll').write_text('unexpected')
        with self.assertRaises(ValueError):
            gptk.inspect(self.source)

    def test_rejects_escaping_source_and_destination_links(self):
        link = self.lib / 'wine/x86_64-unix/d3d10.so'
        link.unlink()
        link.symlink_to('/etc/hosts')
        with self.assertRaises(ValueError):
            gptk.inspect(self.source)
        link.unlink()
        link.symlink_to('../../external/libd3dshared.dylib')
        resources = self.app / 'Contents/Resources'
        resources.rmdir()
        resources.symlink_to(self.root)
        with self.assertRaises(ValueError):
            gptk.import_payload(self.source, self.app)


if __name__ == '__main__':
    unittest.main()
