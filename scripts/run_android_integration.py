"""Run one Flutter integration install; transfer only a declared test package.

No uninstall, pm clear, setting changes, or install retry. Report pulls use the
isolated .debug UID. The original package bytes are never transformed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

PACKAGE = 'tw.offline.icd.icd_dictionary.debug'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', required=True)
    parser.add_argument('--build-dir', type=Path, required=True)
    parser.add_argument('--official', type=Path, required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    official = args.official.resolve()
    expected = json.loads((repo/'evidence/linux-official-probe.json').read_text())
    config_path = repo/'.local-source/integration-defines.json'
    config = json.loads(config_path.read_text())
    config.update(EXPECT_OFFICIAL=True,
                  OFFICIAL_SHA256=expected['package_sha256'],
                  OFFICIAL_SNAPSHOT_SHA256=expected['snapshot_sha256'])
    config_path.write_text(json.dumps(config))
    if hashlib.sha256(official.read_bytes()).hexdigest() != expected['package_sha256']:
        raise SystemExit('Official input does not match the existing native probe')
    command = ['flutter','test','-d',args.device,'integration_test/device_test.dart',
               '--no-uninstall','--reporter','expanded',
               '--dart-define-from-file='+str(config_path)]
    log = repo/'evidence/android-integration-retry.log'
    adb = ['adb','-s',args.device]
    sent = False
    with log.open('x') as output:
        process = subprocess.Popen(command,cwd=args.build_dir,stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT,text=True,bufsize=1)
        try:
            for line in process.stdout:
                output.write(line);output.flush()
                if 'ICD_DEVICE_INPUT_READY:' in line and not sent:
                    remote = "run-as "+PACKAGE+" sh -c 'cat > files/official-input.icdpack.part'"
                    with official.open('rb') as source:
                        subprocess.run(adb+['shell','-T',remote],stdin=source,check=True,timeout=60)
                    digest = subprocess.check_output(adb+['shell','run-as',PACKAGE,'sha256sum',
                                                         'files/official-input.icdpack.part'],text=True).split()[0]
                    if digest != expected['package_sha256']:
                        raise RuntimeError('Android copy SHA256 differs from original')
                    subprocess.run(adb+['shell','run-as',PACKAGE,'mv',
                                         'files/official-input.icdpack.part','files/official-input.icdpack'],
                                   check=True,timeout=10)
                    sent = True
                    output.write('HOST_TRANSFER_SHA256='+digest+'\n');output.flush()
                if 'Built ' in line or 'Installing ' in line or 'ICD_DEVICE_' in line or '[E]' in line:
                    print(line.rstrip(),flush=True)
            result = process.wait()
        except BaseException:
            process.terminate();process.wait(timeout=20)
            raise
        output.write(f'EXIT={result}\n')
    if result == 0:
        report = subprocess.check_output(adb+['exec-out','run-as',PACKAGE,'cat','files/device-report.json'])
        (repo/'evidence/android-device-report.json').write_bytes(report)
    return result

if __name__ == '__main__':
    sys.exit(main())
