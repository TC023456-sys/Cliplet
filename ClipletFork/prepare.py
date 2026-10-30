"""Prepare Cliplet branding/resources from the preserved Maccy 2.7.1 source.

Only developer-owned source/resources; never touches user history or preferences.
"""
import json
from pathlib import Path
import plistlib
import subprocess

root = Path(__file__).resolve().parents[1]
app = root / 'Maccy'
identity = 'com.tc023456.Cliplet'

info_path = app / 'Info.plist'
info = plistlib.loads(info_path.read_bytes())
info['CFBundleName'] = 'Cliplet'
info['CFBundleDisplayName'] = 'Cliplet'
info['NSHumanReadableCopyright'] = 'Maccy © Alexey Rodionov; Cliplet modifications © TC023456-sys'
for key in list(info):
    if key.startswith('SU'):
        del info[key]
info_path.write_bytes(plistlib.dumps(info))

entitlement_path = app / 'Maccy.entitlements'
entitlements = plistlib.loads(entitlement_path.read_bytes())
entitlements.pop('com.apple.security.temporary-exception.mach-lookup.global-name', None)
entitlements.pop('com.apple.security.app-sandbox', None)
entitlements['com.apple.security.network.client'] = True
entitlement_path.write_bytes(plistlib.dumps(entitlements))

project_path = root / 'Maccy.xcodeproj/project.pbxproj'
project = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(project_path)]))
objects = project['objects']
removed = {key for key, obj in objects.items()
           if obj.get('productName') == 'Sparkle' or 'sparkle-project/Sparkle' in obj.get('repositoryURL', '')
           or obj.get('path') == 'appcast.xml'}
removed |= {key for key, obj in objects.items()
            if obj.get('isa') == 'PBXBuildFile'
            and (obj.get('productRef') in removed or obj.get('fileRef') in removed)}
for key in removed:
    del objects[key]
def clean(value):
    if isinstance(value, list):
        return [clean(item) for item in value if not isinstance(item, str) or item not in removed]
    if isinstance(value, dict):
        return {key: clean(item) for key, item in value.items()}
    if isinstance(value, str):
        return value.replace('org.p0deje.Maccy', identity)
    return value
project = clean(project)
for obj in project['objects'].values():
    settings = obj.get('buildSettings', {})
    if settings.get('PRODUCT_BUNDLE_IDENTIFIER') == identity:
        settings['MARKETING_VERSION'] = '1.0.7'
        settings['CURRENT_PROJECT_VERSION'] = '10007'
        settings['DEVELOPMENT_TEAM'] = ''
project_path.write_bytes(plistlib.dumps(project))
resolved = root / 'Maccy.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
pins = json.loads(resolved.read_text())
pins['pins'] = [pin for pin in pins['pins'] if pin['identity'].lower() != 'sparkle']
resolved.write_text(json.dumps(pins, indent=2) + '\n')

for path in app.rglob('*.strings'):
    text = path.read_text()
    path.write_text(text.replace('org.p0deje.Maccy', identity).replace('Maccy', 'Cliplet'))
for path in (app / 'Intents').glob('*.swift'):
    path.write_text(path.read_text().replace('Maccy clipboard history', 'Cliplet clipboard history')
                    .replace('Depending on Maccy settings', 'Depending on Cliplet settings'))
for relative in ['AppDelegate.swift', 'Extensions/Defaults.Keys+Names.swift',
                 'Extensions/NSPasteboard.PasteboardType+Types.swift',
                 'Observables/History.swift', 'Observables/SlideoutController.swift']:
    path = app / relative
    path.write_text(path.read_text().replace('org.p0deje.Maccy', identity))
# Internal model/module names intentionally stay compatible with the original DB.
# The on-disk folder is retained to allow an explicit, offline history migration.

icon = root / 'ClipletFork/Cliplet.png'
catalog = app / 'Assets.xcassets/AppIcon.appiconset'
images = json.loads((catalog / 'Contents.json').read_text())['images']
for item in images:
    size = round(float(item['size'].split('x')[0]) * float(item['scale'].replace('x', '')))
    subprocess.run(['sips', '-z', str(size), str(size), str(icon), '--out', str(catalog / item['filename'])],
                   check=True, stdout=subprocess.DEVNULL)
composer = app / 'AppIcon.icon'
(composer / 'icon.json').write_text((root / 'ClipletFork/AppIcon.json').read_text())
subprocess.run(['swift', str(root / 'ClipletFork/compile-icon.swift'), str(icon),
                str(composer / 'Assets/Cliplet.png')], check=True)
# Only the approved layer is referenced. Remove obsolete upstream artwork from the generated bundle.
for filename in ['0 - Layer.svg', '1 - Layer.svg', '2 - Layer.svg', '3 - Layer.svg']:
    (composer / 'Assets' / filename).unlink(missing_ok=True)
print('PASS: Cliplet identity, MIT attribution, update dependency isolation and icon sizes prepared.')
