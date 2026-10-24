"""Materialize private build inputs from environment; never print their values."""
import base64
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def private_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with path.open('wb') as stream:
        os.chmod(path, 0o600)
        stream.write(data)


def prepare(env):
    names = ('FIREBASE_ANDROID_CONFIG', 'CLIPPER_LOGIN_CONFIG',
             'ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD',
             'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD')
    if any(not env.get(name) for name in names):
        raise ValueError('Required release Secrets are missing')
    firebase = json.loads(env['FIREBASE_ANDROID_CONFIG'])
    if any(key in env['FIREBASE_ANDROID_CONFIG'] for key in ('private_key', 'client_secret', 'BEGIN PRIVATE')):
        raise ValueError('Only Firebase Android client configuration is permitted')
    clients = firebase.get('client', [])
    if not any(c['client_info']['android_client_info']['package_name'] == 'com.iclip' for c in clients):
        raise ValueError('Firebase Android package mismatch')
    login = json.loads(env['CLIPPER_LOGIN_CONFIG'])
    required = ('CLIPPER_USERNAME', 'CLIPPER_PASSWORD_SALT', 'CLIPPER_PASSWORD_HASH', 'CLIPPER_PASSWORD_ITERATIONS')
    if set(login) != set(required) or not login['CLIPPER_USERNAME']:
        raise ValueError('Invalid login build configuration')
    if len(base64.b64decode(login['CLIPPER_PASSWORD_SALT'], validate=True)) < 16:
        raise ValueError('Invalid login salt')
    if len(base64.b64decode(login['CLIPPER_PASSWORD_HASH'], validate=True)) != 32:
        raise ValueError('Invalid login verifier')
    if not isinstance(login['CLIPPER_PASSWORD_ITERATIONS'], int) or login['CLIPPER_PASSWORD_ITERATIONS'] < 100000:
        raise ValueError('Invalid login work factor')
    release = ROOT / '.release'
    private_write(ROOT / 'android/app/google-services.json', json.dumps(firebase).encode())
    version = re.search(r'^version:\s*(\S+)', (ROOT / 'pubspec.yaml').read_text(), re.M).group(1)
    login['APP_VERSION'] = version
    private_write(release / 'login.json', json.dumps(login).encode())
    private_write(release / 'iclip-release.p12', base64.b64decode(env['ANDROID_KEYSTORE_BASE64'], validate=True))
    values = {
        'storeFile': str((release / 'iclip-release.p12').resolve()),
        'storePassword': env['ANDROID_KEYSTORE_PASSWORD'],
        'keyAlias': env['ANDROID_KEY_ALIAS'],
        'keyPassword': env['ANDROID_KEY_PASSWORD'],
    }
    if any('\n' in value or '\r' in value for value in values.values()):
        raise ValueError('Invalid signing property')
    properties = '\n'.join(f'{key}={value.replace(chr(92), chr(92)*2)}' for key, value in values.items()) + '\n'
    private_write(ROOT / 'android/key.properties', properties.encode())


if __name__ == '__main__':
    try:
        prepare(os.environ)
    except Exception:
        raise SystemExit('Release input validation failed. Check repository Secrets; values were not logged.')
    print('Private build inputs prepared.')
