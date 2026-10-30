"""Run the isolated review UI suite and capture its real-device notes dialog.

First build the debug integration target, then verify its actual APK id here.
Never install, clear, or uninstall the production application.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', required=True)
    parser.add_argument('--build-dir', type=Path, required=True)
    parser.add_argument('--defines', type=Path, required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    evidence = repo / 'evidence/release-0.2.2'
    evidence.mkdir(exist_ok=True)
    package = 'tw.offline.icd.icd_dictionary.debug'
    apk = args.build_dir / 'build/app/outputs/flutter-apk/app-debug.apk'
    sdk = Path(os.environ.get('ANDROID_HOME', Path.home() / 'Android/Sdk'))
    aapt = sorted((sdk / 'build-tools').glob('*/aapt2'))[-1]
    badging = subprocess.check_output([aapt, 'dump', 'badging', apk], text=True)
    if not re.search(r"package: name='" + re.escape(package) + "'", badging):
        raise SystemExit('Test APK must use the isolated .debug application ID')
    (evidence / 'android-test-badging.txt').write_text(badging)
    adb = ['adb', '-s', args.device]
    command = ['flutter', 'test', '-d', args.device,
               'integration_test/review_ui_test.dart', '--no-uninstall',
               '--reporter', 'expanded', '--dart-define-from-file=' + str(args.defines.resolve())]
    support = None
    with (evidence / 'android-review-ui.log').open('w') as log:
        process = subprocess.Popen(command, cwd=args.build_dir, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, bufsize=1)
        try:
            for line in process.stdout:
                log.write(line)
                log.flush()
                if 'ICD022_NOTES_VISIBLE:' in line:
                    support = line.split('ICD022_NOTES_VISIBLE:', 1)[1].strip()
                    if not support.startswith('/data/user/') or '..' in support:
                        raise RuntimeError('Unexpected test support directory')
                    screenshot = subprocess.check_output(adb + ['exec-out', 'screencap', '-p'], timeout=15)
                    (evidence / 'android-notes-dialog.png').write_bytes(screenshot)
                    subprocess.run(adb + ['shell', 'run-as', package, 'touch',
                                          shlex.quote(support + '/review022-captured')],
                                   check=True, timeout=10)
                if 'Built ' in line or 'ICD022' in line or '[E]' in line or 'passed' in line:
                    print(line.rstrip(), flush=True)
            result = process.wait()
        except BaseException:
            process.terminate()
            process.wait(timeout=20)
            raise
        log.write(f'EXIT={result}\n')
    if result == 0 and support:
        report = subprocess.check_output(adb + ['exec-out', 'run-as', package, 'cat',
                                               support + '/review022-report.json'], timeout=15)
        json.loads(report)
        (evidence / 'android-review-report.json').write_bytes(report)
    return result


if __name__ == '__main__':
    raise SystemExit(main())
