from pathlib import Path
import re

violations = []
for path in Path("src").rglob("*.rs"):
    source = path.read_text()
    if "desktop" not in path.parts and re.search(r"\btauri\s*::", source):
        violations.append(f"{path}: Tauri belongs in desktop")
    if "domain" in path.parts and re.search(r"\b(?:serde|serde_json|Serialize|Deserialize)\b", source):
        violations.append(f"{path}: serialization belongs at the boundary")
    production = source.split("#[cfg(test)]", 1)[0]
    if "application" in path.parts:
        if re.search(r"\b(?:tauri|serde|serde_json|Serialize|Deserialize)\b", production):
            violations.append(f"{path}: application must not depend on transport or serialization")
        if re.search(r"\b(?:infra|presentation)\s*::", production):
            violations.append(f"{path}: application must not depend on outer adapters")
    if path == Path("src/desktop/wiring.rs") and re.search(r"\b(?:thread|mpsc|serde|Serialize|Deserialize)\b", production):
        violations.append(f"{path}: wiring only composes dependencies")
if violations:
    raise SystemExit("Layer boundary violations: " + ", ".join(violations))
print("Layer boundary checked.")
