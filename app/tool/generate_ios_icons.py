"""Resize the approved opaque artwork into the existing iOS icon catalog."""

import json
from decimal import Decimal
from pathlib import Path
import subprocess


project_root = Path(__file__).resolve().parents[2]
source = project_root / "design/futuremint-ai/assets/app-icon.png"
catalog = project_root / "app/ios/Runner/Assets.xcassets/AppIcon.appiconset"
metadata = json.loads((catalog / "Contents.json").read_text())
png = source.read_bytes()
if png[:8] != b"\x89PNG\r\n\x1a\n" or png[25] != 2:
    raise SystemExit("Icon source must be an opaque RGB PNG.")
if png[16:20] != png[20:24]:
    raise SystemExit("Icon source must be square.")

outputs = {}
for entry in metadata["images"]:
    width, height = entry["size"].split("x")
    scale = Decimal(entry["scale"].removesuffix("x"))
    outputs[entry["filename"]] = (int(Decimal(width) * scale), int(Decimal(height) * scale))

for filename, (width, height) in outputs.items():
    subprocess.run(
        ["sips", "--resampleHeightWidth", str(height), str(width), str(source), "--out", str(catalog / filename)],
        check=True,
        capture_output=True,
    )
print(f"Generated {len(outputs)} iOS icons from {source.relative_to(project_root)}")
