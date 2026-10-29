from pathlib import Path
import re

violations = []
for path in Path("src").rglob("*.rs"):
    source = path.read_text()
    if "desktop" not in path.parts and re.search(r"\btauri\s*::", source):
        violations.append(f"{path}: Tauri belongs in desktop")
    if "domain" in path.parts and re.search(r"\b(?:serde|serde_json|Serialize|Deserialize)\b", source):
        violations.append(f"{path}: serialization belongs at the boundary")
if violations:
    raise SystemExit("Layer boundary violations: " + ", ".join(violations))
print("Layer boundary checked.")
