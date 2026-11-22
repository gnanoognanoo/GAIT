"""Package tested KINETIQ sources and app builds from the repository root."""
from pathlib import Path
import hashlib
import shutil
import zipfile

root = Path(__file__).resolve().parents[1]
out = root.parent / 'deliverables'
out.mkdir(exist_ok=True)
skip_dirs = {'.dart_tool','.gradle','.idea','.kotlin','.cxx','.pio','build',
             'ephemeral','Pods','.symlinks','__pycache__','xcuserdata'}
skip_files = {'local.properties','Generated.xcconfig','flutter_export_environment.sh',
              '.flutter-plugins-dependencies','.flutter-plugins','GeneratedPluginRegistrant.java',
              'GeneratedPluginRegistrant.h','GeneratedPluginRegistrant.m','inspection.png'}

def allowed(path):
    return (path.name not in skip_files and path.suffix not in {'.iml','.blend1'}
            and not set(path.parts) & skip_dirs)

def include(z, base, prefix=''):
    if base.is_file():
        z.write(base, prefix + base.name)
        return
    for p in sorted(base.rglob('*')):
        rel = p.relative_to(base)
        if p.is_file() and allowed(rel):
            z.write(p, prefix + rel.as_posix())

def bundle(name, entries):
    with zipfile.ZipFile(out/name,'w',zipfile.ZIP_DEFLATED,compresslevel=5) as z:
        for path, prefix in entries:
            include(z, root/path, prefix)
    with zipfile.ZipFile(out/name) as z:
        assert z.testzip() is None, name

files = ['lib','firmware','android','ios','web','test','assets','artwork','docs','tools',
         'LICENSES','pubspec.yaml','pubspec.lock','README.md','THIRD_PARTY_ASSETS.md',
         'THIRD_PARTY_NOTICES.md','OPEN_SOURCE_AUDIT.md','analysis_options.yaml','setup_windows.ps1',
         '.gitignore','.metadata']
bundle('KINETIQ-source.zip', [(f, f+'/' if (root/f).is_dir() else '') for f in files])
bundle('KINETIQ-firmware.zip', [('firmware','firmware/'),('tools','tools/'),
       ('docs','docs/'),('LICENSES','LICENSES/'),('THIRD_PARTY_NOTICES.md',''),('OPEN_SOURCE_AUDIT.md','')])
bundle('KINETIQ-Arduino-IDE.zip', [('firmware/arduino/KINETIQ_ESP32','KINETIQ_ESP32/'),
       ('docs/ble_protocol.md',''),('docs/VERIFICATION.md',''),('LICENSES','LICENSES/')])
bundle('KINETIQ-web.zip', [('build/web',''),('LICENSES','LICENSES/'),
       ('THIRD_PARTY_NOTICES.md',''),('THIRD_PARTY_ASSETS.md','')])
shutil.copyfile(root/'build/app/outputs/flutter-apk/app-release.apk',out/'KINETIQ-android.apk')
names = ['KINETIQ-source.zip','KINETIQ-firmware.zip','KINETIQ-Arduino-IDE.zip',
         'KINETIQ-web.zip','KINETIQ-android.apk']
lines = []
for name in names:
    file = out/name
    digest=hashlib.sha256(file.read_bytes()).hexdigest()
    lines.append(f'{digest}  {name}')
    print(name, file.stat().st_size)
(out/'SHA256SUMS.txt').write_text('\n'.join(lines)+'\n')

