import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('apk', Path(__file__).resolve().parents[1] / 'scripts/check_apk.py')
apk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apk)

class CertificateTests(unittest.TestCase):
    def test_supported_build_tools_signer_formats(self):
        digest = 'a' * 64
        formats = ['Signer #1', 'Signer (minSdkVersion=24, maxSdkVersion=2147483647)',
                   'V3.0 Signer:', 'V3.1 Signer: (minSdkVersion=33, maxSdkVersion=2147483647)']
        for prefix in formats:
            with self.subTest(prefix=prefix):
                self.assertEqual(apk.certificate_digests(prefix + ' certificate SHA-256 digest: ' + digest.upper()), {digest})

    def test_all_active_certificates_are_retained_for_comparison(self):
        a, b = 'a' * 64, 'b' * 64
        output = '\n'.join(['V2 Signer: certificate SHA-256 digest: ' + a,
                            'V3.0 Signer: certificate SHA-256 digest: ' + a,
                            'V3.1 Signer: certificate SHA-256 digest: ' + b])
        self.assertEqual(apk.certificate_digests(output), {a, b})

    def test_stamp_lineage_public_key_and_unknown_output_do_not_validate_a_signer(self):
        digest = 'a' * 64
        for prefix in ['Source Stamp Signer', 'Signer #1 in lineage', 'Unknown']:
            self.assertEqual(apk.certificate_digests(prefix + ' certificate SHA-256 digest: ' + digest), set())
        self.assertEqual(apk.certificate_digests('Signer #1 public key SHA-256 digest: ' + digest), set())
        self.assertEqual(apk.certificate_digests('Signer #1 certificate SHA-256 digest: abc'), set())
