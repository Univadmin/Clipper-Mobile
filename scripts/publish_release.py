"""Publish a verified APK, then rebuild downloads from published Releases."""
import base64
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
REPO = os.environ.get('GITHUB_REPOSITORY', 'Univadmin/Clipper-Mobile')


def gh(*args, data=None):
    result = subprocess.run(['gh', *args], input=json.dumps(data) if data is not None else None,
                            text=True, capture_output=True, check=True)
    return result.stdout


def version():
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$', (ROOT / 'pubspec.yaml').read_text(), re.M)
    if not match:
        raise ValueError('pubspec must contain a numeric version and build number')
    return match.group(1)


def all_releases():
    pages = json.loads(gh('api', '--paginate', '--slurp', f'repos/{REPO}/releases?per_page=100'))
    return [release for page in pages for release in page]


def render_downloads(releases):
    rows = []
    for release in sorted(releases, key=lambda item: item.get('published_at') or '', reverse=True):
        if release['draft'] or release['prerelease']:
            continue
        asset = next((a for a in release['assets'] if a['name'] == 'Clipper.apk' and a['size'] > 0), None)
        if not asset:
            continue
        tag = release['tag_name']
        if not re.fullmatch(r'v\d+\.\d+\.\d+\+\d+', tag):
            continue
        date = datetime.fromisoformat(release['published_at'].replace('Z', '+00:00')).astimezone(ZoneInfo('Europe/Istanbul'))
        rows.append(f"| {tag[1:]} | {date:%d.%m.%Y} | [APK indir]({asset['browser_download_url']}) |")
    return ('# Clipper APK indirmeleri\n\n'
            f'[Son sürümü indir](https://github.com/{REPO}/releases/latest/download/Clipper.apk)\n\n'
            '| Sürüm | Tarih | İndirme bağlantısı |\n|---|---|---|\n' + '\n'.join(rows) + '\n\n'
            'APK’yı kurup giriş yapın. Önceki sürümlerin bağlantıları korunur. '
            'Sürüm ve SHA-256 bilgileri ilgili GitHub Release sayfasındadır.\n')


def refresh_downloads():
    text = render_downloads(all_releases())
    repo = json.loads(gh('api', f'repos/{REPO}'))
    branch = repo['default_branch']
    current = json.loads(gh('api', f'repos/{REPO}/contents/downloads/README.md?ref={branch}'))
    if base64.b64decode(current['content']).decode() == text:
        return
    gh('api', '--method', 'PUT', f'repos/{REPO}/contents/downloads/README.md', '--input', '-', data={
        'message': 'Update APK download history [skip ci]', 'branch': branch,
        'sha': current['sha'], 'content': base64.b64encode(text.encode()).decode(),
    })


def publish():
    release_version = version()
    tag = 'v' + release_version
    if os.environ.get('GITHUB_REF_TYPE') == 'tag' and os.environ.get('GITHUB_REF_NAME') != tag:
        raise ValueError('Release tag does not match pubspec version')
    latest_build = max((int(r['tag_name'].split('+')[-1]) for r in all_releases()
                       if not r['draft'] and re.fullmatch(r'v\d+\.\d+\.\d+\+\d+', r['tag_name'])
                       and r['tag_name'] != tag), default=0)
    if int(release_version.split('+')[1]) <= latest_build:
        raise ValueError('Build number must increase for every APK update')
    apk = ROOT / 'build/app/outputs/flutter-apk/app-release.apk'
    if not apk.is_file() or apk.stat().st_size < 1000000:
        raise ValueError('Release APK missing')
    artifacts = ROOT / '.release/artifacts'
    artifacts.mkdir(parents=True, exist_ok=True)
    target = artifacts / 'Clipper.apk'
    shutil.copy2(apk, target)
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    checksums = artifacts / 'SHA256SUMS'
    checksums.write_text(f'{digest}  Clipper.apk\n')
    notes = artifacts / 'notes.md'
    notes.write_text(f'iClip {release_version}\n\nAndroid release APK. Kurulumdan sonra uygulama giriş bilgilerini kullanın.\n\n'
                     'Veri bütünlüğü, kamera ve liste performansı iyileştirmelerini içerir. '
                     'Uygulama kilidi yereldir; Firebase sunucu kuralları bu yayın tarafından değiştirilmez.\n\n'
                     f'SHA-256: `{digest}`\n')
    existing = next((r for r in all_releases() if r['tag_name'] == tag), None)
    if existing and not existing['draft']:
        assets = {a['name']: a for a in existing['assets']}
        if not {'Clipper.apk', 'SHA256SUMS'} <= assets.keys():
            raise ValueError('Published release is incomplete; refusing to overwrite it')
        refresh_downloads()
        return
    # Create a lightweight version tag only after the APK has been built.
    # A changed version on main is enough to trigger the complete release flow.
    ref_result = subprocess.run(['gh', 'api', f'repos/{REPO}/git/ref/tags/{tag}'],
                                capture_output=True, text=True)
    source_sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if ref_result.returncode == 0:
        if json.loads(ref_result.stdout)['object']['sha'] != source_sha:
            raise ValueError('Version tag already points to different source; use a new version')
    elif 'HTTP 404' in ref_result.stderr:
        gh('api', '--method', 'POST', f'repos/{REPO}/git/refs', '--input', '-',
           data={'ref': 'refs/tags/' + tag, 'sha': source_sha})
    else:
        raise ValueError('Could not verify version tag')
    if not existing:
        gh('release', 'create' , tag, '--repo', REPO, '--verify-tag', '--draft',
           '--title', f'iClip {release_version}', '--notes-file', str(notes))
    gh('release', 'upload', tag, str(target), str(checksums), '--repo', REPO, '--clobber')
    release = json.loads(gh('api', f'repos/{REPO}/releases/tags/{tag}'))
    assets = {a['name']: a for a in release['assets']}
    if assets.get('Clipper.apk', {}).get('size') != target.stat().st_size:
        raise ValueError('Uploaded APK size mismatch')
    gh('release', 'edit', tag, '--repo', REPO, '--draft=false', '--latest')
    refresh_downloads()
    print(f'Published {tag}; downloads history updated.')


if __name__ == '__main__':
    publish()
