"""Construct the actual Tk GUI, including custom icon, then close it immediately."""
import json
import sqlite3
import sys
import tkinter as tk
from pathlib import Path
here=Path(__file__).resolve().parent
sys.path.insert(0,str(here if (here/'tools').is_dir() else here.parent))
from tools.data_builder import gui

def smoke(self, *args, **kwargs):
    self.withdraw()
    self.update_idletasks()
    assert 'ICD' in self.title()
    assert len(self.winfo_children()) >= 5
    print(json.dumps({'gui_constructed':True,'python':sys.version,'sqlite':sqlite3.sqlite_version,'tk':tk.TkVersion},ensure_ascii=False))
    self.destroy()

tk.Tk.mainloop=smoke
gui.main()
