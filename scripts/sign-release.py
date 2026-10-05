#!/usr/bin/env python3
"""Sign one immutable release and its feed with the dedicated login Keychain key."""
import hashlib, pathlib, plistlib, subprocess, tempfile
from xml.sax.saxutils import escape
project=pathlib.Path(__file__).resolve().parent.parent
info=plistlib.loads(pathlib.Path('/tmp/clipnest-bundle/ClipNest.app/Contents/Info.plist').read_bytes())
version=info['CFBundleShortVersionString'];build=info['CFBundleVersion']
assert subprocess.check_output(['lipo','-archs','/tmp/clipnest-bundle/ClipNest.app/Contents/MacOS/ClipNest'],text=True).strip()=='arm64', 'This release-feed script targets Apple silicon only'
archive=project/'dist'/('ClipNest-'+version+'-macos-arm64.zip')
assert archive.is_file() and 'SUPublicEDKey' in info, 'Build with the approved public key first'
tool='/tmp/clipnest-build/artifacts/sparkle/Sparkle/bin/sign_update'
args=[tool,'--account','app.clipnest.mac.updates']
signature=subprocess.check_output(args+['-p',str(archive)],text=True).strip()
subprocess.run(args+['--verify',str(archive),signature],check=True,capture_output=True)
feed=project/'appcast.xml'
feed.write_text('''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
<channel><title>ClipNest Updates</title><link>https://github.com/myerwang/clipnest</link><description>Signed ClipNest development releases</description><language>en</language>
<item><title>ClipNest '''+escape(version)+'''</title><link>https://github.com/myerwang/clipnest/releases/tag/v'''+escape(version)+'''</link>
<sparkle:version>'''+escape(build)+'''</sparkle:version><sparkle:shortVersionString>'''+escape(version)+'''</sparkle:shortVersionString>
<sparkle:minimumSystemVersion>13.0.0</sparkle:minimumSystemVersion><sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>
<description sparkle:format="plain-text">Development MVP. Ad-hoc signed, not notarized. Installer replacement end-to-end verification remains outstanding.</description>
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
(project/'dist/SHA256SUMS.txt').write_text(checksum+'  '+archive.name+'\n')
print('PASS: archive and feed signatures; modified archive and feed rejected; SHA256SUMS written')
