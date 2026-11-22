"""Generate the Arduino IDE sketch from the same source used by PlatformIO."""
from pathlib import Path
import os
import shutil

root = Path(__file__).resolve().parents[1]
export = root / 'firmware' / 'arduino' / 'KINETIQ_ESP32'
export.mkdir(parents=True, exist_ok=True)
(export / 'KINETIQ_ESP32.ino').write_text(
    '// Arduino IDE compiles src recursively. setup() and loop() live in src/main.cpp.\n'
)
shutil.copytree(root / 'firmware/src', export / 'src', dirs_exist_ok=True)
shutil.copyfile(root / 'firmware/README.md', export / 'README.md')
for file in (root / 'firmware/src').rglob('*'):
    if file.is_file():
        assert file.read_bytes() == (export / 'src' / file.relative_to(root / 'firmware/src')).read_bytes()
print(export)

