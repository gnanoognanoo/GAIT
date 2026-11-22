"""Build the dependency inventory, license bundle and CycloneDX SBOM."""
import hashlib
import json
import re
import shutil
import subprocess
import urllib.parse
from pathlib import Path
import yaml

root = Path(__file__).resolve().parents[1]
license_dir = root / 'LICENSES'
license_dir.mkdir(exist_ok=True)
inventory = []

def add(name, version, repo, license_id, scope, sources=(), revision=None, note='Unmodified'):
    names = []
    for i, source in enumerate(sources):
        if source.is_file():
            filename = re.sub(r'[^A-Za-z0-9_.-]', '_', name) + f'-{i}-' + source.name
            shutil.copyfile(source, license_dir / filename)
            names.append('LICENSES/' + filename)
    inventory.append(dict(name=name, version=version, repository=repo, license=license_id,
                          scope=scope, notices=names, revision=revision or version, modifications=note))

def identify(paths):
    contents = '\n'.join(p.read_text(encoding='utf8', errors='replace') for p in paths if p.is_file())
    if 'Mozilla Public License Version 2.0' in contents:
        return 'MPL-2.0'
    if 'LGPL' in contents or 'GNU LESSER GENERAL PUBLIC LICENSE' in contents:
        return 'LGPL-2.1-or-later'
    if ('Apache License' in contents or 'Apache License, Version 2.0' in contents) and 'Version 2.0' in contents:
        return 'Apache-2.0'
    if 'Neither the name' in contents or 'neither the name' in contents:
        return 'BSD-3-Clause'
    if 'Redistribution and use in source and binary forms' in contents:
        return 'BSD-2-Clause'
    if 'Permission is hereby granted, free of charge' in contents:
        return 'MIT'
    return 'NOASSERTION'

firmware = [
    ('MPU','Adafruit MPU6050','2.2.6','adafruit/Adafruit_MPU6050','BSD-3-Clause','license.txt'),
    ('BusIO','Adafruit BusIO','1.17.4','adafruit/Adafruit_BusIO','MIT','LICENSE'),
    ('Sensor','Adafruit Unified Sensor','1.1.15','adafruit/Adafruit_Sensor','Apache-2.0','LICENSE.txt'),
    ('NimBLE','NimBLE-Arduino','2.3.7','h2zero/NimBLE-Arduino','Apache-2.0','LICENSE'),
    ('Fusion','Fusion','snapshot','xioTechnologies/Fusion','MIT','LICENSE.md'),
]
for folder,name,version,repo,license_id,filename in firmware:
    path = root / 'build/product-deps' / folder
    rev = subprocess.check_output(['git','-C',str(path),'rev-parse','HEAD'],text=True).strip()
    license_file = path / filename
    identified = identify([license_file])
    assert identified != 'NOASSERTION', name
    notices = [license_file]
    if folder == 'NimBLE':
        notices.extend([path/'NOTICE', path/'src/nimble/LICENSE', path/'src/nimble/NOTICE'])
    add(name,version,'https://github.com/'+repo,identified,'firmware',notices,rev)
upstream = root / 'build/upstream-licenses'
for name, version, repo in [('Adafruit GFX Library','1.13.0','Adafruit-GFX-Library'),
    ('Adafruit SSD1306','2.5.17','Adafruit_SSD1306')]:
    notice=root / 'firmware/.pio/libdeps/esp32-wroom' / name / 'license.txt'
    add(name,version,'https://github.com/adafruit/'+repo,identify([notice]),'resolved example-only', [notice])

add('Arduino-ESP32','2.0.17','https://github.com/espressif/arduino-esp32','LGPL-2.1-or-later',
    'firmware framework',[upstream/'Arduino-ESP32.txt'],'dcc1105b')
add('ESP-IDF','4.4.7','https://github.com/espressif/esp-idf','Apache-2.0','firmware framework', [upstream/'ESP-IDF.txt'], 'Arduino 2.0.17 precompiled SDK',note='Vendor SDK includes mixed licenses')
add('PlatformIO Core','6.1.19','https://github.com/platformio/platformio-core','Apache-2.0','build tool',[upstream/'PlatformIO-Core.txt'])
add('PlatformIO espressif32','6.10.0','https://github.com/platformio/platform-espressif32','Apache-2.0','build tool',[root/'build/pio-core/platforms/espressif32/LICENSE'])
add('ESP32 GCC','8.4.0+2021r2-patch5','https://github.com/espressif/crosstool-NG','GPL-3.0-or-later WITH GCC-exception-3.1','build tool')
add('esptool','4.5.1','https://github.com/espressif/esptool','GPL-2.0-or-later','build tool')
add('Prosthesis Leg','source scan','https://sketchfab.com/3d-models/prosthesis-leg-6339595921fe491fb58772ec1502c87b',
    'CC-BY-4.0','asset',[root/'artwork/original/license.txt'],note='Welded, decimated, rigged and animated in Blender')
add('Roboto','Flutter SDK 3.38.9 distribution','https://github.com/googlefonts/roboto','Apache-2.0',
    'asset',[root/'assets/fonts/roboto_license.txt'])

packages = json.loads((root/'.dart_tool/package_config.json').read_text(encoding='utf8'))['packages']
locations = {p['name']: (Path(urllib.parse.unquote(urllib.parse.urlparse(p['rootUri']).path).lstrip('/'))
                       if p['rootUri'].startswith('file:') else root/'.dart_tool'/p['rootUri']) for p in packages}
lock = yaml.safe_load((root/'pubspec.lock').read_text(encoding='utf8'))
for name, spec in lock['packages'].items():
    location = locations[name]
    meta = yaml.safe_load((location/'pubspec.yaml').read_text(encoding='utf8'))
    notices = sorted({*location.glob('LICENSE*'),*location.glob('COPYING*'),*location.glob('NOTICE*')})
    if spec['source']=='sdk' and not notices:
        notices=[locations['flutter'].parents[1]/'LICENSE']
    repo = meta.get('repository') or meta.get('homepage') or 'https://pub.dev/packages/'+name
    add(name, spec['version'], repo, identify(notices),
        'Flutter tooling' if spec['dependency']=='direct dev' or spec['source']=='sdk' and name=='flutter_test' else 'Flutter resolved',
        notices, 'Flutter 3.38.9' if spec['source']=='sdk' else spec['version'])
model = locations['model_viewer_plus']
script = model/'assets/model-viewer.min.js'
source = script.read_text(encoding='utf8')
notices = upstream/'model-viewer-bundle.txt'
notices.write_text('\n\n'.join(x for x in re.findall(r'/\*.*?\*/', source, re.S) if '@license' in x or 'SPDX-License-Identifier' in x), encoding='utf8')
add('Google model-viewer', 'bundled with model_viewer_plus 1.10.0','https://github.com/google/model-viewer','Apache-2.0',
    'renderer', [upstream/'model-viewer.txt', notices],
    'sha256:'+hashlib.sha256(script.read_bytes()).hexdigest(),
    'Unmodified bundle shipped by the locked Flutter package. See embedded third-party notices.')
sdk = root/'build/app/outputs/sdk-dependencies/release/sdkDependencies.txt'
if sdk.is_file():
    import xml.etree.ElementTree as E
    maven_cache = Path.home()/'.gradle/caches/modules-2/files-2.1'
    coords = sorted(set(re.findall(r'groupId: "([^"]+)"\s+artifactId: "([^"]+)"\s+version: "([^"]+)"',
                                    sdk.read_text(encoding='utf8'))))
    for group, name, version in coords:
        poms = list((maven_cache/group/name/version).glob('*/*.pom'))
        download = root/'build/maven-notices'/f'{group}-{name}-{version}.pom'
        if not poms and download.is_file():
            poms = [download]
        pom = None
        if poms:
            pom = E.fromstring(re.sub(r' xmlns="[^"]+"', '', poms[0].read_text(encoding='utf8'), count=1))
        declared = ''
        if pom is not None:
            declared = ' '.join(item.text or '' for item in pom.findall('licenses/license/name'))
        if group.startswith('androidx.'):
            repo, license_id = 'https://android.googlesource.com/platform/frameworks/support', 'Apache-2.0'
        elif group=='io.flutter':
            repo, license_id = 'https://github.com/flutter/engine', 'BSD-3-Clause'
        else:
            repo = (pom.findtext('scm/url') or pom.findtext('url') or '') if pom is not None else ''
            repo = repo or f'https://central.sonatype.com/artifact/{group}/{name}/{version}'
            license_id = 'Apache-2.0' if 'Apache' in declared else 'BSD-3-Clause' if 'BSD' in declared else 'NOASSERTION'
        if group == 'com.google.guava' and name == 'listenablefuture':
            inherited = root/'build/maven-notices/guava-parent-26.0-android.pom'
            if inherited.is_file() and 'The Apache Software License, Version 2.0' in inherited.read_text():
                license_id = 'Apache-2.0'
                declared = 'Apache 2.0 inherited from guava-parent 26.0-android'
                poms = poms[:1] + [inherited]
        add(f'{group}:{name}',version,repo,license_id,'Android release runtime',poms,note='Unmodified Maven release. '+declared)
for row in inventory:
    if row['license']=='NOASSERTION':
        print('Review license:',row['name'],row['notices'])
(root/'docs/dependency_inventory.json').write_text(json.dumps(inventory,indent=2)+'\n',encoding='utf8')
components = []
for row in inventory:
    component = {
        'type':'data' if row['scope']=='asset' else 'library',
        'bom-ref':row['name']+'@'+row['version'],
        'name':row['name'],'version':row['version'],
        'externalReferences':[{'type':'vcs','url':row['repository']}],
        'properties':[{'name':'kinetiq:scope','value':row['scope']},
                      {'name':'kinetiq:revision','value':row['revision']}],
    }
    if row['license'] != 'NOASSERTION':
        component['licenses']=[{'expression':row['license']}]
    components.append(component)
(root/'docs/kinetiq.cdx.json').write_text(json.dumps({
    'bomFormat':'CycloneDX','specVersion':'1.5','version':1,
    'metadata':{'component':{'type':'application','name':'KINETIQ'}},
    'components':components,
},indent=2)+'\n',encoding='utf8')
print(len(inventory),'components')

