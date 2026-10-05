#!/usr/bin/env python3
"""Loopback Sparkle integration tests; disposable bundles, defaults and synthetic files only."""
import base64, http.server, pathlib, plistlib, shutil, subprocess, tempfile, threading, uuid, sys, argparse
from xml.sax.saxutils import escape
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--app',type=pathlib.Path,default=pathlib.Path('/tmp/clipnest-bundle/ClipNest.app'))
parser.add_argument('--feed',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parent.parent/'appcast.xml')
parser.add_argument('--include-install-test',action='store_true')
options=parser.parse_args()
root=pathlib.Path(tempfile.mkdtemp(prefix='clipnest-update-qa-'))
archive=b'Untrusted synthetic update content'
production_info=plistlib.loads((options.app/'Contents/Info.plist').read_bytes())
current_build=int(production_info['CFBundleVersion'])
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def do_GET(self):
        case=self.path.split('?')[0].strip('/')
        if case in ['signedsame','signedtampered']:
            body=options.feed.read_bytes()
            if case=='signedtampered': body=body.replace(b'ClipNest Updates',b'Altered Updates',1)
            self.send_response(200);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body);return
        if case=='offline': self.connection.close(); return
        if case=='archive.zip': body=archive
        elif case=='malformed': body=b'<rss><broken'
        else:
            version=str(current_build if case=='same' else current_build+1)
            minimum='99.0' if case=='incompatible' else '13.0'
            signature=base64.b64encode(bytes(64)).decode()
            body=('<?xml version="1.0"?><rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><title>QA</title><item><title>Synthetic</title><sparkle:minimumSystemVersion>'+minimum+'</sparkle:minimumSystemVersion><enclosure url="http://127.0.0.1:'+str(self.server.server_port)+'/archive.zip" sparkle:version="'+version+'" sparkle:shortVersionString="0.1.1" sparkle:edSignature="'+signature+'" length="'+str(len(archive))+'" type="application/octet-stream"/></item></channel></rss>').encode()
        self.send_response(200); self.send_header('Content-Type','application/xml' if case!='archive.zip' else 'application/octet-stream');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
failed=[]
try:
    cases=['same','newer','offline','malformed','incompatible','signedsame','signedtampered']
    if options.include_install_test: cases.append('signature')
    for case in cases:
        app=root/(case+'.app')
        subprocess.run(['ditto','--norsrc','--noextattr',str(options.app),str(app)],check=True)
        info=app/'Contents/Info.plist'
        data=plistlib.loads(info.read_bytes())
        data.update(CFBundleIdentifier='app.clipnest.update-qa.'+uuid.uuid4().hex,SUDefaultsDomain='app.clipnest.update-qa.'+uuid.uuid4().hex,SUEnableAutomaticChecks=False,SURequireSignedFeed=False,SUFeedURL='http://127.0.0.1:'+str(server.server_port)+'/'+case,SUPublicEDKey=base64.b64encode(bytes.fromhex('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a')).decode(),NSAppTransportSecurity={'NSAllowsLocalNetworking':True})
        if case in ['signedsame','signedtampered']:
            production=plistlib.loads((options.app/'Contents/Info.plist').read_bytes())
            data['SUPublicEDKey']=production['SUPublicEDKey'];data['SURequireSignedFeed']=True
        info.write_bytes(plistlib.dumps(data))
        subprocess.run(['xattr','-cr',str(app)],check=True)
        subprocess.run(['codesign','--force','--sign','-',str(app)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        import os
        env=os.environ.copy();env['CLIPNEST_UPDATE_QA_SCENARIO']=case
        result=subprocess.run([str(app/'Contents/MacOS/ClipNest'),'--update-qa'],env=env,capture_output=True,text=True,timeout=35)
        print(result.stdout.strip(),flush=True)
        if result.returncode: failed.append(case);print(result.stderr[-1800:])
finally:
    server.shutdown()
print('QA bundle directory:',root)
if failed: raise SystemExit('Failed cases: '+', '.join(failed))
