"""One .debug install, private streaming transfers, no uninstall or user-data clear."""
import argparse,hashlib,json,os,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];PACKAGE='tw.offline.icd.icd_dictionary.debug'
p=argparse.ArgumentParser();p.add_argument('--device',required=True);p.add_argument('--build-dir',type=Path,required=True);a=p.parse_args()
inputs={'cm':ROOT/'manual-test-0.1.2/data/cm-fy2027-oct.icdpack','nhi':ROOT/'manual-test-0.1.2/data/nhi2023-cm-ods-unresolved.icdpack','pcs':ROOT/'manual-test-0.2.0/data/pcs-fy2027-oct-app.icdpack','twpcs':ROOT/'manual-test-0.2.0/data/nhi2023-pcs-app.icdpack'}
expected={name:hashlib.sha256(path.read_bytes()).hexdigest() for name,path in inputs.items()}
adb=['/home/hpd/Android/Sdk/platform-tools/adb','-s',a.device]
cmd=['/home/hpd/development/flutter/bin/flutter','test','-d',a.device,'integration_test/large_pack_test.dart','--no-uninstall','--reporter','expanded']
env=os.environ.copy();env['JAVA_HOME']='/home/hpd/development/jdk-17';env['ANDROID_HOME']='/home/hpd/Android/Sdk'
with (ROOT/'evidence/release-0.2.0/android-large-import.log').open('x') as log:
 process=subprocess.Popen(cmd,cwd=a.build_dir,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
 sent=False
 try:
  for line in process.stdout:
   log.write(line);log.flush()
   if 'ICD020_INPUT_READY:' in line and not sent:
    path=line.split('ICD020_INPUT_READY:',1)[1].strip()
    prefix='/data/user/0/'+PACKAGE+'/files/'
    if not path.startswith(prefix) or not re.fullmatch(r'[A-Za-z0-9_./-]+',path):raise RuntimeError('Unexpected private test input path')
    relative=path[len(prefix):]
    for name,source in inputs.items():
     dest='files/'+relative+'/'+name+'.icdpack'
     with source.open('rb') as f:subprocess.run(adb+['shell','-T',"run-as "+PACKAGE+" sh -c 'cat > "+dest+"'"],stdin=f,check=True,timeout=120)
     actual=subprocess.check_output(adb+['shell','run-as',PACKAGE,'sha256sum',dest],text=True).split()[0]
     if actual!=expected[name]:raise RuntimeError('Original source SHA mismatch on device')
    ready=json.dumps(expected).encode()
    subprocess.run(adb+['shell','-T',"run-as "+PACKAGE+" sh -c 'cat > files/"+relative+"/ready'"],input=ready,check=True,timeout=10)
    sent=True
   if 'ICD020_' in line or '[E]' in line or 'Built ' in line:print(line.rstrip(),flush=True)
  result=process.wait();log.write('EXIT='+str(result)+'\n')
 except BaseException:
  process.terminate();process.wait(timeout=20);raise
if result==0:
 report=subprocess.check_output(adb+['exec-out','run-as',PACKAGE,'cat','files/release020-report.json'])
 (ROOT/'evidence/release-0.2.0/android-large-import.json').write_bytes(report)
sys.exit(result)
