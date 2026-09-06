#!/usr/bin/env python3
"""Create an isolated, allowlisted app copy without the integration-test plugin."""
import pathlib
import re
import shutil
import sys

source = pathlib.Path(sys.argv[1]).resolve()
destination = pathlib.Path(sys.argv[2]).resolve()
destination.mkdir(parents=True, exist_ok=False)
for name in ('lib', 'assets', 'ios', 'pubspec.yaml', 'pubspec.lock',
             'analysis_options.yaml', '.metadata'):
    path = source / name
    if path.is_dir():
        shutil.copytree(path, destination / name, ignore=shutil.ignore_patterns(
            'Pods', '.symlinks', 'ephemeral', 'Flutter.framework',
            'App.framework', 'Generated.xcconfig', 'flutter_export_environment.sh',
            'GeneratedPluginRegistrant.*', 'xcuserdata', '*.xcuserstate',
            '.env', '.env.*', '*.p8', '*.p12', '*.pfx', '*.pem', '*.key',
            '*.mobileprovision', 'credentials', 'secrets'))
    elif path.exists():
        shutil.copy2(path, destination / name)
manifest = destination / 'pubspec.yaml'
text, count = re.subn(r'^  integration_test:\n    sdk: flutter\n', '',
                      manifest.read_text(), flags=re.MULTILINE)
if count != 1:
    raise SystemExit('Expected exactly one SDK integration_test dev dependency')
manifest.write_text(text)
# CocoaPods must resolve from the regenerated plugin inventory, not old pods.
(destination / 'ios/Podfile.lock').unlink(missing_ok=True)
