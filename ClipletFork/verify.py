"""Verify generated source, not merely the branding script's presence."""
from pathlib import Path
import plistlib
import json
root = Path(__file__).resolve().parents[1]
app = root / 'Maccy'
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert not plistlib.loads((app / 'Maccy.entitlements').read_bytes()).get('com.apple.security.app-sandbox', False)
assert info['CFBundleName'] == info['CFBundleDisplayName'] == 'Cliplet'
assert not any(key.startswith('SU') for key in info)
assert 'Alexey Rodionov' in info['NSHumanReadableCopyright']
for path in app.rglob('*.swift'):
    text = path.read_text()
    assert 'import Sparkle' not in text and 'SPUUpdater' not in text and 'SPUStandard' not in text, path
updater = (app / 'SoftwareUpdater.swift').read_text()
assert 'p0deje/Maccy' not in updater and 'maccy.app' not in updater
assert 'TC023456-sys/Cliplet' in updater
assert '86400' in updater and 'URLSessionConfiguration.ephemeral' in updater
project = plistlib.loads((root / 'Maccy.xcodeproj/project.pbxproj').read_bytes())
assert 'Sparkle' not in repr(project)
assert any(o.get('buildSettings', {}).get('PRODUCT_BUNDLE_IDENTIFIER') == 'com.tc023456.Cliplet'
           for o in project['objects'].values())
assert (root / 'LICENSE').read_text().startswith('The MIT License')
assert 'Alexey Rodionov' in (app / 'About.swift').read_text()
assert 'https://github.com/p0deje/Maccy' in (app / 'About.swift').read_text()
assert 'Text("Cliplet")' in (app / 'Views/ListHeaderView.swift').read_text()
assert not (root / 'appcast.xml').exists()
composer = json.loads((app / 'AppIcon.icon/icon.json').read_text())
assert composer == json.loads((root / 'ClipletFork/AppIcon.json').read_text())
assert (app / 'AppIcon.icon/Assets/Cliplet.png').exists()
assert any(o.get('path') == 'AppIcon.icon' for o in project['objects'].values())
print('PASS: fork identity, attribution, independent updates and removed Sparkle verified.')
