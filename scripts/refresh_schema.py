"""Refresh the app's code-only schema asset; not a data dictionary asset."""
import json
from pathlib import Path
from tools.data_builder.package import contract
Path('app/assets/schema_contract.json').write_text(json.dumps(contract(),sort_keys=True,indent=2)+'\n')
