from pathlib import Path
import re

violations = []
for path in Path("src").rglob("*.rs"):
    source = path.read_text()
    production = source.split("#[cfg(test)]", 1)[0]
    if "domain" in path.parts and re.search(r"\b(?:serde|serde_json|Serialize|Deserialize)\b", source):
        violations.append(f"{path}: serialization belongs at the boundary")
    if "application" in path.parts:
        if re.search(r"\b(?:serde|serde_json|Serialize|Deserialize|c_char|CStr)\b", production):
            violations.append(f"{path}: application must not depend on transport or serialization")
        if re.search(r"\b(?:infra|presentation)\s*::", production):
            violations.append(f"{path}: application must not depend on outer adapters")
    if path == Path("src/desktop/wiring.rs") and re.search(r"\b(?:thread|mpsc|serde|Serialize|Deserialize)\b", production):
        violations.append(f"{path}: wiring only composes dependencies")
for path in Path("native/Sources").rglob("*.swift"):
    if "Infra" not in path.parts and re.search(r"\beasy_tunnel_(?:create|request|free_string|destroy)\s*\(", path.read_text()):
        violations.append(f"{path}: the C bridge belongs in native infrastructure")
if violations:
    raise SystemExit("Layer boundary violations: " + ", ".join(violations))
print("Layer boundaries checked.")
