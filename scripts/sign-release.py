#!/usr/bin/env python3
"""Sign one immutable release and its feed with the dedicated login Keychain key."""
import argparse, hashlib, pathlib, plistlib, subprocess, tempfile, zipfile
from xml.sax.saxutils import escape
project=pathlib.Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--app',type=pathlib.Path,default=pathlib.Path('/tmp/clipnest-bundle/ClipNest.app'))
parser.add_argument('--archive',type=pathlib.Path)
parser.add_argument('--feed',type=pathlib.Path,default=project/'appcast.xml')
parser.add_argument('--notarized',action='store_true',help='Require an existing valid stapled App ticket before describing this release as notarized')
options=parser.parse_args()
info=plistlib.loads((options.app/'Contents/Info.plist').read_bytes())
if options.notarized:
    subprocess.run(['xcrun','stapler','validate',str(options.app)],check=True,capture_output=True)
    subprocess.run(['codesign','--verify','--deep','--strict',str(options.app)],check=True,capture_output=True)
version=info['CFBundleShortVersionString'];build=info['CFBundleVersion']
assert subprocess.check_output(['lipo','-archs',str(options.app/'Contents/MacOS/ClipNest')],text=True).strip()=='arm64', 'This release-feed script targets Apple silicon only'
archive=options.archive or project/'dist'/('ClipNest-'+version+'-macos-arm64.zip')
assert archive.is_file() and 'SUPublicEDKey' in info, 'Build with the approved public key first'
with zipfile.ZipFile(archive) as contents:
    archive_info=plistlib.loads(contents.read('ClipNest.app/Contents/Info.plist'))
    for field in ['CFBundleIdentifier','CFBundleVersion','CFBundleShortVersionString','SUPublicEDKey']:
        assert archive_info[field]==info[field], 'Archive does not match the selected App'
    assert contents.read('ClipNest.app/Contents/MacOS/ClipNest')==(options.app/'Contents/MacOS/ClipNest').read_bytes(), 'Archive main executable differs from selected App'
    if options.notarized:
        assert contents.read('ClipNest.app/Contents/CodeResources')==(options.app/'Contents/CodeResources').read_bytes(), 'Archive must preserve the App notarization ticket'

tool='/tmp/clipnest-build/artifacts/sparkle/Sparkle/bin/sign_update'
args=[tool,'--account','app.clipnest.mac.updates']
signature=subprocess.check_output(args+['-p',str(archive)],text=True).strip()
subprocess.run(args+['--verify',str(archive),signature],check=True,capture_output=True)
feed=options.feed
description=('Developer ID signed and Apple notarized, with stapled tickets. Menu bar clipboard MVP. Interactive updater replacement end-to-end verification remains outstanding.' if options.notarized else 'Development MVP. Ad-hoc signed, not notarized. Installer replacement end-to-end verification remains outstanding.')
feed.write_text('''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
<channel><title>ClipNest Updates</title><link>https://github.com/myerwang/clipnest</link><description>Signed ClipNest development releases</description><language>en</language>
<item><title>ClipNest '''+escape(version)+'''</title><link>https://github.com/myerwang/clipnest/releases/tag/v'''+escape(version)+'''</link>
<sparkle:version>'''+escape(build)+'''</sparkle:version><sparkle:shortVersionString>'''+escape(version)+'''</sparkle:shortVersionString>
<sparkle:minimumSystemVersion>13.0.0</sparkle:minimumSystemVersion><sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>
<description sparkle:format="plain-text">'''+escape(description)+'''</description>
<enclosure url="https://github.com/myerwang/clipnest/releases/download/v'''+escape(version)+'''/'''+archive.name+'''" sparkle:edSignature="'''+signature+'''" length="'''+str(archive.stat().st_size)+'''" type="application/octet-stream"/>
</item></channel></rss>
''')
subprocess.run(args+[str(feed)],check=True,capture_output=True)
subprocess.run(args+['--verify',str(feed)],check=True,capture_output=True)
# Tampering must fail cryptographic verification, independently of the installer sandbox.
with tempfile.TemporaryDirectory(prefix='clipnest-signature-qa-') as d:
    bad=pathlib.Path(d)/archive.name;bad.write_bytes(archive.read_bytes()+b'QA tamper')
    assert subprocess.run(args+['--verify',str(bad),signature],capture_output=True).returncode!=0
    badfeed=pathlib.Path(d)/'appcast.xml';badfeed.write_bytes(feed.read_bytes().replace(b'ClipNest Updates',b'Altered Updates',1))
    assert subprocess.run(args+['--verify',str(badfeed)],capture_output=True).returncode!=0
checksum=hashlib.sha256(archive.read_bytes()).hexdigest()
(archive.parent/'SHA256SUMS.txt').write_text(checksum+'  '+archive.name+'\n')
print('PASS: archive and feed signatures; modified archive and feed rejected; SHA256SUMS written')
