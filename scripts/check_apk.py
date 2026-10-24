"""Verify the package, version and permanent signing identity before publishing."""
import os
from pathlib import Path
import re
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[1]

def verify(apk):
    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or Path.home() / 'Library/Android/sdk')
    versions = sorted((sdk / 'build-tools').iterdir(), key=lambda p: tuple(int(n) for n in p.name.split('.') if n.isdigit()), reverse=True)
    tools = next(p for p in versions if (p / 'apksigner').exists() and (p / 'aapt').exists())
    certificate = subprocess.run([str(tools / 'apksigner'), 'verify', '--print-certs', str(apk)], capture_output=True, text=True, check=True).stdout
    digests = re.findall(r'Signer #\d+ certificate SHA-256 digest: ([0-9a-f]+)', certificate)
    expected = (ROOT / 'android/release-certificate.sha256').read_text().strip()
    if digests != [expected]:
        raise ValueError('Signing certificate mismatch: upgrade compatibility would break')
    metadata = subprocess.run([str(tools / 'aapt'), 'dump', 'badging', str(apk)], capture_output=True, text=True, check=True).stdout
    version, build = re.search(r'^version:\s*(\S+)', (ROOT / 'pubspec.yaml').read_text(), re.M).group(1).split('+')
    if not re.search(r"package: name='com.iclip' versionCode='" + re.escape(build) + r"' versionName='" + re.escape(version) + "'", metadata):
        raise ValueError('APK package/version mismatch')
    if int(build) <= 2:
        raise ValueError('Build number must be greater than the 1.0.1+2 baseline')
    print('APK package, version and 1.0.1+2 signing compatibility verified.')

if __name__ == '__main__':
    verify(Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'build/app/outputs/flutter-apk/app-release.apk')
