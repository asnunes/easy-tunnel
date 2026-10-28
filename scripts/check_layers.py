from pathlib import Path
import re

violations = []
for path in Path("src").rglob("*.rs"):
    if "desktop" in path.parts:
        continue
    if re.search(r"\btauri\s*::", path.read_text()):
        violations.append(str(path))
if violations:
    raise SystemExit("Tauri must stay in src/desktop/: " + ", ".join(violations))
print("Layer boundary checked.")
