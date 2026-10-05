#!/usr/bin/env python3
"""Read-only mount, app-content/signature comparison, and exact own-mount detach."""
import hashlib, os, pathlib, plistlib, subprocess, sys, tempfile
image=pathlib.Path(sys.argv[1]).resolve()
archive=pathlib.Path(sys.argv[2]).resolve()
root=pathlib.Path(tempfile.mkdtemp(prefix='clipnest-dmg-verify-',dir='/tmp'))
mount=root/'mounted';mount.mkdir()
subprocess.run(['ditto','-x','-k',str(archive),str(root/'zip')],check=True)
mounted=False
try:
    subprocess.run(['hdiutil','attach','-readonly','-nobrowse','-mountpoint',str(mount),'-plist',str(image)],check=True,capture_output=True)
    mounted=True
    info=plistlib.loads(subprocess.check_output(['diskutil','info','-plist',str(mount)]))
    assert info.get('ReadOnlyVolume') is True or info.get('Writable') is False, 'Volume must be read-only'
    assert os.readlink(mount/'Applications')=='/Applications'
    assert (mount/'INSTALL.txt').is_file()
    def inventory(base):
        result={}
        for p in base.rglob('*'):
            name=str(p.relative_to(base))
            if p.is_symlink(): result[name]=('symlink',os.readlink(p))
            elif p.is_file(): result[name]=('file',hashlib.sha256(p.read_bytes()).hexdigest())
        return result
    assert inventory(mount/'ClipNest.app')==inventory(root/'zip/ClipNest.app'), 'Mounted app must match released ZIP byte-for-byte, including symlinks'
    subprocess.run(['codesign','--verify','--deep','--strict',str(mount/'ClipNest.app')],check=True)
    print('PASS: read-only volume, Applications link, installation instructions, complete ZIP app content and nested code signatures')
finally:
    if mounted: subprocess.run(['hdiutil','detach',str(mount)],check=True,capture_output=True)
assert not os.path.ismount(mount) and not (mount/'ClipNest.app').exists()
print('PASS: exact test volume detached; no installed app touched')
print('DMG bytes:',image.stat().st_size)
print('DMG SHA256:',hashlib.sha256(image.read_bytes()).hexdigest())
