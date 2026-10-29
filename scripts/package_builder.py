"""Build a Windows x64 offline ETL tool with its own pinned Python runtime.

The App does not use or include this Python. Runtime and wheels are downloaded
only at package-build time; launchers and GUI never download anything.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import zipfile

ROOT=Path(__file__).resolve().parents[1]
VERSION='0.2.0'
RUNTIME_URL='https://github.com/astral-sh/python-build-standalone/releases/download/20261026/cpython-3.13.18%2B20261026-x86_64-pc-windows-msvc-install_only_stripped.tar.gz'
RUNTIME_SHA='7369f7a35f261222a6ac8b3a87c1c88eeebee8af945d85346202591a64038dd3'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def package(output,cache,unpacked=None):
    output=output.resolve();cache.mkdir(parents=True,exist_ok=True)
    if output.exists():raise FileExistsError('Existing artifact preserved: '+str(output))
    runtime=cache/'python-windows-x64.tar.gz'
    if not runtime.exists():
        with urllib.request.urlopen(RUNTIME_URL,timeout=120) as src,runtime.open('xb') as dst:shutil.copyfileobj(src,dst)
    if sha(runtime)!=RUNTIME_SHA:raise ValueError('Runtime SHA256 mismatch')
    lock=ROOT/'tools/data_builder/requirements-windows.lock'
    wheels=cache/'wheels';wheels.mkdir(exist_ok=True)
    subprocess.run([sys.executable,'-m','pip','download','--disable-pip-version-check','--platform','win_amd64','--python-version','3.13','--implementation','cp','--abi','cp313','--only-binary=:all:','--require-hashes','-r',str(lock),'--dest',str(wheels)],check=True)
    allowed=set(re.findall(r'--hash=sha256:([0-9a-f]{64})',lock.read_text()))
    with tempfile.TemporaryDirectory(prefix='icd-builder-') as td:
        stage=Path(td);bundle=stage/f'ICD-Data-Builder-{VERSION}'
        bundle.mkdir()
        with tarfile.open(runtime) as tar:
            for item in tar.getmembers():
                path=Path(item.name)
                if path.parts[0]!='python' or path.is_absolute() or '..' in path.parts or not (item.isdir() or item.isfile()):raise ValueError('Unsafe runtime tar')
            tar.extractall(stage,filter='data')
        (stage/'python').rename(bundle/'runtime')
        site=bundle/'runtime/Lib/site-packages';site.mkdir(parents=True,exist_ok=True)
        wheel_receipts=[]
        for wheel in sorted(wheels.glob('*.whl')):
            checksum=sha(wheel)
            if checksum not in allowed:raise ValueError('Wheel not in requirements lock: '+wheel.name)
            with zipfile.ZipFile(wheel) as archive:
                for item in archive.infolist():
                    path=Path(item.filename)
                    if path.is_absolute() or '..' in path.parts or '\\' in item.filename:raise ValueError('Unsafe wheel path')
                    if item.is_dir():continue
                    parts=path.parts
                    if parts[0].endswith('.data'):
                        if len(parts)<3 or parts[1] not in ('purelib','platlib'):continue
                        path=Path(*parts[2:])
                    target=site/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.read(item))
            wheel_receipts.append({'filename':wheel.name,'sha256':checksum})
        for folder in ['tools/data_builder','schemas','samples']:
            shutil.copytree(ROOT/folder,bundle/folder,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
        (bundle/'app/assets').mkdir(parents=True)
        shutil.copyfile(ROOT/'app/assets/schema_contract.json',bundle/'app/assets/schema_contract.json')
        (bundle/'branding').mkdir()
        shutil.copyfile(ROOT/'app/windows/runner/resources/app_icon.ico',bundle/'branding/app_icon.ico')
        shutil.copyfile(ROOT/'icon.png',bundle/'branding/icon.png')
        (bundle/'docs').mkdir()
        shutil.copytree(ROOT/'docs/source_profiles',bundle/'docs/source_profiles')
        (bundle/'scripts').mkdir()
        shutil.copyfile(ROOT/'scripts/build_official_local.py',bundle/'scripts/build_official_local.py')
        shutil.copyfile(ROOT/'docs/OFFICIAL_IMPORT_0.1.2.md',bundle/'docs/OFFICIAL_IMPORT_0.1.2.md')
        shutil.copyfile(ROOT/'docs/RELEASE_0.2.0.md',bundle/'docs/RELEASE_0.2.0.md')
        for name in ['cdc-profile.example.json','nhi-profile.example.json']:
            shutil.copyfile(ROOT/'docs'/name,bundle/'docs'/name)
        for name in ['LICENSE','LICENSES.md','SOURCE_PROVENANCE.md']:
            shutil.copyfile(ROOT/name,bundle/name)
        (bundle/'ICD-Data-Builder.cmd').write_text('@echo off\nsetlocal\nchcp 65001 >nul\ncd /d "%~dp0"\nif "%~1"=="" goto gui\n"runtime\\python.exe" -E -s -X utf8 -m tools.data_builder %*\ngoto done\n:gui\n"runtime\\python.exe" -E -s -X utf8 -m tools.data_builder gui\n:done\nif errorlevel 1 pause\n',encoding='utf-8')
        (bundle/'SELF-TEST.cmd').write_text('@echo off\nsetlocal\nchcp 65001 >nul\ncd /d "%~dp0"\n"runtime\\python.exe" -E -s -X utf8 -m pytest tools/data_builder/tests -q\npause\n',encoding='utf-8')
        shutil.copyfile(ROOT/'scripts/smoke_builder_gui.py',bundle/'smoke_gui.py')
        (bundle/'README-先讀.txt').write_text('''ICD 離線資料庫製作工具 0.2.0（Windows x64）

解壓後雙擊 ICD-Data-Builder.cmd，開啟繁體中文視窗。
附私有 Python 3.13.18、Tk、SQLite 與所有鎖定套件，不需另外安裝 Python／pip。
不要移動 runtime 子目錄；不修改系統 PATH、登錄或其他 Python 環境。

功能：選官方原檔總資料夾，從下拉選單選 CM／ODS／PCS 設定，再建立新資料。
CM／PCS App profile → .icdpack（PCS需App0.2.0）；來源表profile → 獨立 .sqlite。
附 10 種已核對且 SHA256 鎖定的來源設定，不需手改 JSON。
新版PCS與手機修正見 docs/RELEASE_0.2.0.md；原始表格式見 docs/OFFICIAL_IMPORT_0.1.2.md。
請先用「合成測試包」與 SELF-TEST.cmd 測試工具，再核對 docs/ 中的 profile。
正式原始資料不附送，也不會自動下載；不明確中譯 lineage 必須保持 unresolved。
不得把 SAMPLE / NOT FOR CLINICAL CODING 當成正式字典。

CLI 範例：
ICD-Data-Builder.cmd verify --package samples\\sample-demo-v1.icdpack
ICD-Data-Builder.cmd sample --output new-sample.icdpack
ICD-Data-Builder.cmd build --source-dir official-files --profile docs\\my-profile.json --output new-dictionary.icdpack

相同 .icdpack 原檔可手動匯入 Windows／Android App，不需平台轉換。
本工具與 App 分開；App 本身沒有 Python runtime 或網路更新功能。
授權與來源見 LICENSES.md、SOURCE_PROVENANCE.md、runtime/LICENSE.txt 與各套件 dist-info。
Windows 實際驗證狀態請看交付資料夾的報告，不因有 EXE 就假設全部通過。
''',encoding='utf-8-sig')
        receipt={'version':VERSION,'python':'3.13.18','target':'windows-x64','runtime_url':RUNTIME_URL,'runtime_sha256':RUNTIME_SHA,'requirements_sha256':sha(lock),'wheels':wheel_receipts,'official_full_data_included':False}
        (bundle/'bundle-provenance.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
        if unpacked:
            if unpacked.exists():raise FileExistsError('Unpacked target exists')
            shutil.copytree(bundle,unpacked)
        output.parent.mkdir(parents=True,exist_ok=True)
        with output.open('xb') as stream,zipfile.ZipFile(stream,'w',zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(bundle.rglob('*')):
                if path.is_file():archive.write(path,path.relative_to(stage).as_posix())
    with zipfile.ZipFile(output) as archive:
        if archive.testzip():raise ValueError('ZIP CRC failure')
    print(json.dumps({'output':str(output),'bytes':output.stat().st_size,'sha256':sha(output)},indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--cache',type=Path,default=ROOT/'.local-source/portable-builder')
    parser.add_argument('--unpacked',type=Path)
    args=parser.parse_args();package(args.output,args.cache,args.unpacked)
