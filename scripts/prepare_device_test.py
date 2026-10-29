"""Create local integration defines from exact packages + completed native probe.

The samples are compiled only into the integration test target, never lib/main.dart.
"""
import base64
import json
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
probe=json.loads((repo/'evidence/linux-probe.json').read_text())
config={'PACK1':base64.b64encode((repo/'samples/sample-demo-v1.icdpack').read_bytes()).decode(),'PACK2':base64.b64encode((repo/'samples/sample-demo-v2.icdpack').read_bytes()).decode(),'PACK1_SHA256':probe['package_sha256'],'SNAPSHOT_SHA256':probe['snapshot_sha256']}
target=repo/'.local-source/integration-defines.json';target.parent.mkdir(exist_ok=True);target.write_text(json.dumps(config))
print(f'flutter test -d <device-id> integration_test/device_test.dart --no-uninstall --dart-define-from-file="{target}"')
print('Use an ASCII build copy if required. Verify APK applicationId ends in .debug before installation.')
