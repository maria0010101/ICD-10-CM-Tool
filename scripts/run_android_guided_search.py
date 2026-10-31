"""Transfer a local official pack only to the isolated Android integration app."""
import argparse,json,os,re,shlex,subprocess,sys,tempfile
from pathlib import Path

PACKAGE='tw.offline.icd.icd_dictionary.debug'
def main():
    p=argparse.ArgumentParser();p.add_argument('--device',required=True);p.add_argument('--build-dir',type=Path,required=True);p.add_argument('--pack',type=Path,required=True);p.add_argument('--expected',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1];out=root/'evidence/search-review-20261031';adb=['adb','-s',a.device]
    sdk=Path(os.environ.get('ANDROID_HOME',Path.home()/'Android/Sdk'));aapt=sorted((sdk/'build-tools').glob('*/aapt2'))[-1]
    badging=subprocess.check_output([aapt,'dump','badging',a.build_dir/'build/app/outputs/flutter-apk/app-debug.apk'],text=True)
    assert "package: name='"+PACKAGE+"'" in badging
    (out/'android-debug-badging.txt').write_text(badging)
    expected=json.loads(a.expected.read_text());input_path=None
    def send(local,remote):
        cmd='run-as '+PACKAGE+' sh -c '+shlex.quote('cat > '+shlex.quote(remote+'.part'))
        with local.open('rb') as src:subprocess.run(adb+['shell','-T',cmd],stdin=src,check=True,timeout=90)
        subprocess.run(adb+['shell','run-as',PACKAGE,'mv',remote+'.part',remote],check=True,timeout=10)
    with tempfile.TemporaryDirectory() as td:
        ready=Path(td)/'ready.json';ready.write_text(json.dumps({'sha256':expected['sha256'],'snapshots':expected['snapshots']},ensure_ascii=False))
        command=['flutter','test','-d',a.device,'integration_test/guided_search_test.dart','--no-uninstall','--reporter','expanded']
        with (out/'android-guided-test.log').open('x') as log:
            proc=subprocess.Popen(command,cwd=a.build_dir,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
            try:
                for line in proc.stdout:
                    log.write(line);log.flush()
                    if 'ICD024_INPUT_READY:' in line:
                        input_path=line.split('ICD024_INPUT_READY:',1)[1].strip()
                        if not re.fullmatch(r'/data/user/\d+/tw\.offline\.icd\.icd_dictionary\.debug/files/guided024-\d+/inputs',input_path):raise RuntimeError('Unexpected isolated input path')
                        send(a.pack,input_path+'/official.icdpack')
                        sha=subprocess.check_output(adb+['shell','run-as',PACKAGE,'sha256sum',input_path+'/official.icdpack'],text=True).split()[0]
                        assert sha==expected['sha256'];send(ready,input_path+'/ready.json')
                        log.write('HOST_TRANSFER_SHA256='+sha+'\n');log.flush()
                    if 'ICD024_RESULTS_VISIBLE:' in line:
                        assert line.split('ICD024_RESULTS_VISIBLE:',1)[1].strip()==input_path
                        (out/'local-android-guided.png').write_bytes(subprocess.check_output(adb+['exec-out','screencap','-p'],timeout=15))
                        subprocess.run(adb+['shell','run-as',PACKAGE,'touch',input_path+'/captured'],check=True,timeout=10)
                    if any(x in line for x in ['ICD024','Built ','Installing ','passed','[E]']):print(line.rstrip(),flush=True)
                result=proc.wait()
            except BaseException:
                proc.terminate();proc.wait(timeout=20);raise
            log.write(f'EXIT={result}\n')
    if result==0:
        raw=subprocess.check_output(adb+['exec-out','run-as',PACKAGE,'cat','files/guided024-report.json'],timeout=30);r=json.loads(raw);assert r['snapshots']==expected['snapshots']
        (out/'local-android-guided-report.json').write_bytes(raw)
        (out/'android-guided-summary.json').write_text(json.dumps(dict(same_original_sha256=r['sha256'],queries=len(r['snapshots']),snapshots_match_linux=True,loaded_ui_rows=r['loaded_ui_rows'],ui_total=r['ui_total'],os=r['os']),indent=2)+'\n')
    return result
if __name__=='__main__':sys.exit(main())
