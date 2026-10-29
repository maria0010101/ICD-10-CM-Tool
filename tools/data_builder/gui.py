"""Local desktop front-end for the existing offline builder CLI."""
from __future__ import annotations
from datetime import datetime
import os
from pathlib import Path
import queue
import sqlite3
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[2]


def builder_command(arguments: list[str]) -> list[str]:
    """Use only this tool's interpreter; never run input files as commands."""
    return [sys.executable, '-E', '-s', '-X', 'utf8', '-m', 'tools.data_builder', *arguments]


def main():
    import tkinter as tk
    from tkinter import filedialog, messagebox, ttk
    if os.name == 'nt':
        import ctypes
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID('tw.offline.icd.builder')
    root = tk.Tk()
    root.title('ICD 離線資料包製作工具 · 0.1.1')
    root.geometry('900x720')
    root.minsize(650, 540)
    icon = ROOT / 'branding' / 'app_icon.ico'
    if os.name == 'nt' and icon.exists():
        root.iconbitmap(str(icon))
    else:
        png = ROOT / 'app/assets/branding/icon.png'
        if png.exists():
            root._icon = tk.PhotoImage(file=str(png))
            root.iconphoto(True, root._icon)
    db = sqlite3.connect(':memory:')
    try:
        db.execute('CREATE VIRTUAL TABLE probe USING fts5(text)')
    finally:
        db.close()
    events = queue.Queue()
    state = {'process': None}
    source = tk.StringVar()
    profile = tk.StringVar()
    output = tk.StringVar()
    package = tk.StringVar()
    status = tk.StringVar(value=f'Python {sys.version.split()[0]} · SQLite {sqlite3.sqlite_version} · FTS5 可用 · 完全離線')
    ttk.Label(root, text='ICD-10-CM 離線資料包製作工具', font=('', 18, 'bold')).pack(anchor='w', padx=18, pady=(16, 4))
    ttk.Label(root, text='正式字典僅使用管理者取得的官方原檔；未知中譯對應不得改成相容。').pack(anchor='w', padx=18)
    tabs = ttk.Notebook(root)
    tabs.pack(fill='x', padx=16, pady=12)
    build = ttk.Frame(tabs, padding=12)
    verify = ttk.Frame(tabs, padding=12)
    sample = ttk.Frame(tabs, padding=12)
    tabs.add(build, text='官方資料製作')
    tabs.add(verify, text='驗證 .icdpack')
    tabs.add(sample, text='合成測試包')
    buttons = []

    def choose(variable, kind):
        if kind == 'dir':
            value = filedialog.askdirectory(title='選擇官方原檔資料夾')
        elif kind == 'output':
            value = filedialog.asksaveasfilename(title='選擇新資料包檔名（不覆寫既有檔）', defaultextension='.icdpack',
                                              initialfile='icd-'+datetime.now().strftime('%Y%m%d-%H%M%S')+'.icdpack',
                                              filetypes=[('ICD data package', '*.icdpack')])
        else:
            value = filedialog.askopenfilename(filetypes=[('JSON profile', '*.json')] if kind == 'profile' else [('ICD data package', '*.icdpack')])
        if value:
            variable.set(value)

    def field(frame, row, label, variable, kind):
        ttk.Label(frame, text=label).grid(row=row, column=0, sticky='w', padx=(0, 8), pady=5)
        ttk.Entry(frame, textvariable=variable).grid(row=row, column=1, sticky='ew', pady=5)
        ttk.Button(frame, text='選擇…', command=lambda: choose(variable, kind)).grid(row=row, column=2, padx=(8, 0))
        frame.columnconfigure(1, weight=1)

    def worker(arguments):
        try:
            process = subprocess.Popen(builder_command(arguments), cwd=ROOT, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace',
                                       creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            state['process'] = process
            for line in process.stdout:
                events.put(('text', line))
            result = process.wait()
            events.put(('done', result))
        except Exception as exc:
            events.put(('text', f'ERROR: {exc}\n'))
            events.put(('done', 1))

    def run(kind):
        if state['process'] is not None:
            return
        if kind == 'verify':
            if not Path(package.get()).is_file():
                messagebox.showerror('缺少檔案', '請選取要驗證的 .icdpack。')
                return
            arguments = ['verify', '--package', package.get()]
        else:
            if not output.get() or Path(output.get()).exists():
                messagebox.showerror('輸出檔案', '請選擇尚不存在的新 .icdpack 檔名；工具不覆寫既有資料。')
                return
            arguments = ['sample', '--output', output.get()]
            if kind == 'build':
                if not Path(source.get()).is_dir() or not Path(profile.get()).is_file():
                    messagebox.showerror('缺少輸入', '請選取官方原檔資料夾與已核對的 JSON profile。')
                    return
                arguments = ['build', '--source-dir', source.get(), '--profile', profile.get(), '--output', output.get()]
        state['process'] = 'starting'
        for button in buttons:
            button.configure(state='disabled')
        log.delete('1.0', 'end')
        status.set('處理中…所有檔案僅在本機使用，視窗保持可操作。')
        threading.Thread(target=worker, args=(arguments,), daemon=True).start()

    field(build, 0, '官方原檔資料夾', source, 'dir')
    field(build, 1, '來源／版別 profile', profile, 'profile')
    field(build, 2, '新 .icdpack', output, 'output')
    ttk.Label(build, text='profile 範本位於 docs/；需核對原檔、版本、修訂日期與中譯 lineage。').grid(row=3, column=0, columnspan=3, sticky='w', pady=6)
    buttons.append(ttk.Button(build, text='離線建立資料包', command=lambda: run('build')))
    buttons[-1].grid(row=4, column=1, sticky='w')
    field(verify, 0, '既有 .icdpack', package, 'package')
    buttons.append(ttk.Button(verify, text='檢查 SHA256／schema／SQLite／索引', command=lambda: run('verify')))
    buttons[-1].grid(row=1, column=1, sticky='w', pady=8)
    ttk.Label(sample, text='SAMPLE / NOT FOR CLINICAL CODING\n合成測試資料，不是官方字典，禁止作為臨床編碼依據。', foreground='#a02620').grid(row=0, column=0, columnspan=3, sticky='w', pady=6)
    field(sample, 1, '新合成測試包', output, 'output')
    buttons.append(ttk.Button(sample, text='建立合成測試包', command=lambda: run('sample')))
    buttons[-1].grid(row=2, column=1, sticky='w')
    ttk.Label(root, textvariable=status, wraplength=850).pack(anchor='w', padx=18, pady=(0, 8))
    log = tk.Text(root, wrap='word', font=('TkFixedFont', 10))
    log.pack(fill='both', expand=True, padx=16, pady=(0, 16))
    log.insert('end', '選擇上方功能。正式內容不附送、不自動下載。\n同一個 .icdpack 原檔可交給 Windows／Android App 手動匯入。\n')

    def poll():
        try:
            while True:
                kind, value = events.get_nowait()
                if kind == 'text':
                    log.insert('end', value)
                    log.see('end')
                else:
                    state['process'] = None
                    for button in buttons:
                        button.configure(state='normal')
                    status.set('完成（EXIT=0）' if value == 0 else '失敗；請查看錯誤，既有資料包不會被覆寫。')
        except queue.Empty:
            pass
        root.after(100, poll)

    def close():
        if state['process'] is not None:
            messagebox.showinfo('正在製作／驗證', '工作完成後再關閉；目前不會中止或刪除任何輸出。')
            return
        root.destroy()
    root.protocol('WM_DELETE_WINDOW', close)
    root.after(100, poll)
    root.mainloop()

if __name__ == '__main__':
    main()
