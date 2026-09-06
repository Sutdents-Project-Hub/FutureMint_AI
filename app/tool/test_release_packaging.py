"""Release staging regression checks; uses synthetic files only."""
import pathlib
import subprocess
import sys
import tempfile
import unittest

PREPARE = pathlib.Path(__file__).with_name('prepare_ios_release.py')


class ReleaseStagingTests(unittest.TestCase):
    def test_keeps_runtime_source_but_excludes_secrets_and_test_plugins(self):
        with tempfile.TemporaryDirectory() as temp:
            source = pathlib.Path(temp) / 'source'
            destination = pathlib.Path(temp) / 'release'
            source.mkdir()
            fixtures = {
                'pubspec.yaml': 'dev_dependencies:\n  integration_test:\n    sdk: flutter\n',
                'pubspec.lock': 'packages: {}\n',
                'lib/main.dart': 'void main() {}',
                '.env.appstore.local': 'SYNTHETIC_SECRET=do-not-copy',
                'test/example_test.dart': 'test',
                'ios/Podfile': 'pod configuration',
                'ios/Podfile.lock': 'integration_test',
                'ios/Pods/old-plugin/file': 'stale',
                'ios/Flutter/Generated.xcconfig': 'stale-path',
                'ios/Runner/GeneratedPluginRegistrant.m': 'integration_test',
                'ios/Runner/Info.plist': 'runtime metadata',
            }
            for name, value in fixtures.items():
                path = source / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(value)
            subprocess.run([sys.executable, str(PREPARE), str(source), str(destination)], check=True)
            self.assertEqual((destination / 'lib/main.dart').read_text(), 'void main() {}')
            self.assertTrue((destination / 'ios/Runner/Info.plist').exists())
            self.assertNotIn('integration_test', (destination / 'pubspec.yaml').read_text())
            for name in ['.env.appstore.local', 'test', 'ios/Pods', 'ios/Podfile.lock',
                         'ios/Flutter/Generated.xcconfig',
                         'ios/Runner/GeneratedPluginRegistrant.m']:
                self.assertFalse((destination / name).exists(), name)
            self.assertIn('integration_test', (source / 'pubspec.yaml').read_text())


if __name__ == '__main__':
    unittest.main()
