"""Package source + evidence without SDKs, credentials or official datasets."""
import argparse
import hashlib
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FOLDERS = {'app','tools','schemas','samples','scripts','docs','evidence','.github'}
FILES = {'.gitignore','AGENTS.md','SRS.md','DATA_PACKAGE_SPEC.md','TEST_PLAN.md',
         'README.md','README.spec-original.md','START_HERE.md','LICENSE','LICENSES.md','SOURCE_PROVENANCE.md'}
EXCLUDE = {'build','.dart_tool','.gradle','ephemeral','__pycache__','.pytest_cache'}

def package(output):
    output = output.resolve()
    if not output.is_relative_to(ROOT):
        raise ValueError('Keep release artifacts inside this project')
    if output.exists():
        raise FileExistsError('Existing artifact preserved: '+str(output))
    selected = []
    for path in sorted(ROOT.rglob('*')):
        relative = path.relative_to(ROOT)
        if not path.is_file() or path.is_symlink():
            continue
        if relative.parts[0] not in FOLDERS and str(relative) not in FILES:
            continue
        if any(part in EXCLUDE for part in relative.parts):
            continue
        if path.name in {'local.properties','.flutter-plugins-dependencies','GeneratedPluginRegistrant.java'} or path.suffix=='.pyc':
            continue
        selected.append((path,relative))
    receipt=ROOT/'evidence/source-sha256.txt'
    receipt.write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {r.as_posix()}\n'
                               for p,r in selected if r.parts[0]!='evidence'))
    output.parent.mkdir(parents=True,exist_ok=True)
    with output.open('xb') as stream,zipfile.ZipFile(stream,'w',zipfile.ZIP_DEFLATED) as archive:
        for path,relative in selected:
            info=zipfile.ZipInfo('icd-offline-0.1.0/'+relative.as_posix(),(2026,10,29,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED
            info.external_attr=(0o100755 if path.stat().st_mode & 0o111 else 0o100644)<<16
            archive.writestr(info,path.read_bytes())
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        for item in archive.infolist():
            relative=Path(item.filename).relative_to('icd-offline-0.1.0')
            assert archive.read(item)==(ROOT/relative).read_bytes(),str(relative)
    return len(selected),hashlib.sha256(output.read_bytes()).hexdigest()

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    count,checksum=package(args.output)
    print(f'{count} files; {args.output.stat().st_size} bytes; SHA256 {checksum}')
