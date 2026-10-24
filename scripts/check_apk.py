"""Verify the package, version and permanent signing identity before publishing."""
import os
from pathlib import Path
import re
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[1]

def certificate_digests(output):
    # Android build-tools versions label active signers differently.
    pattern = (r'^(?:Signer (?:#\d+|\([^\n)]+\))|'
               r'V\d+(?:\.\d+)? Signer:(?: \([^\n)]+\))?) '
               r'certificate SHA-256 digest:\s*([0-9a-fA-F]{64})\s*$')
    return {digest.lower() for digest in re.findall(pattern, output, re.M)}


def verify(apk):
    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or Path.home() / 'Library/Android/sdk')
    versions = sorted((sdk / 'build-tools').iterdir(), key=lambda p: tuple(int(n) for n in p.name.split('.') if n.isdigit()), reverse=True)
    tools = next(p for p in versions if (p / 'apksigner').exists() and (p / 'aapt').exists())
    certificate = subprocess.run([str(tools / 'apksigner'), 'verify', '--print-certs', str(apk)], capture_output=True, text=True, check=True).stdout
    digests = certificate_digests(certificate)
    expected = (ROOT / 'android/release-certificate.sha256').read_text().strip()
    if not digests:
        public_lines = [line for line in certificate.splitlines() if 'certificate SHA-256 digest:' in line]
        raise ValueError('Unrecognized apksigner certificate output: ' + repr(public_lines[:8]))
    if digests != {expected}:
        raise ValueError('Signing certificate mismatch: ' + ', '.join(sorted(digests)))
    metadata = subprocess.run([str(tools / 'aapt'), 'dump', 'badging', str(apk)], capture_output=True, text=True, check=True).stdout
    version, build = re.search(r'^version:\s*(\S+)', (ROOT / 'pubspec.yaml').read_text(), re.M).group(1).split('+')
    if not re.search(r"package: name='com.iclip' versionCode='" + re.escape(build) + r"' versionName='" + re.escape(version) + "'", metadata):
        raise ValueError('APK package/version mismatch')
    if int(build) <= 2:
        raise ValueError('Build number must be greater than the 1.0.1+2 baseline')
    print('APK package, version and 1.0.1+2 signing compatibility verified.')

if __name__ == '__main__':
    verify(Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'build/app/outputs/flutter-apk/app-release.apk')
