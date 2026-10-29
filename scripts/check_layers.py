from pathlib import Path
import re

violations = []
for path in Path("native/Sources").rglob("*.swift"):
    source = path.read_text()
    if "Domain" in path.parts:
        if re.search(r"\b(Codable|Encodable|Decodable|JSONEncoder|JSONDecoder|SwiftUI|AppKit|Combine|Process|DispatchQueue)\b", source):
            violations.append(f"{path}: domain must not depend on UI, serialization, or process infrastructure")
    if "Application" in path.parts:
        if re.search(r"\b(JSONEncoder|JSONDecoder|SwiftUI|AppKit|Combine|DispatchQueue|Process)\b", source):
            violations.append(f"{path}: application must stay independent of outer adapters")
    if "Presentation" in path.parts:
        if re.search(r"\b(Process|JSONEncoder|JSONDecoder|FileManager)\b", source):
            violations.append(f"{path}: presentation uses typed backend operations")
    if path.name == "Wiring.swift" and re.search(r"\b(DispatchQueue|DispatchSource|JSONEncoder|JSONDecoder)\b", source):
        violations.append(f"{path}: wiring only composes dependencies")
if violations:
    raise SystemExit("Layer boundary violations: " + ", ".join(violations))
print("Layer boundaries checked.")
