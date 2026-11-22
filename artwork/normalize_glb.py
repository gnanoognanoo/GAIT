"""Lift the skinned mesh out of its identity armature container for glTF clients."""
import json
import struct
from pathlib import Path

def normalize(path):
    raw = path.read_bytes()
    json_length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+json_length])
    nodes = doc['nodes']
    scene = doc['scenes'][doc.get('scene',0)]
    for root_id in scene['nodes'][:]:
        parent = nodes[root_id]
        if parent.get('name') != 'Motion rig':
            continue
        assert not any(key in parent for key in ('matrix','translation','rotation','scale'))
        for child in parent.get('children',[])[:]:
            if 'skin' in nodes[child]:
                parent['children'].remove(child)
                scene['nodes'].append(child)
    data = json.dumps(doc,separators=(',',':')).encode()
    data += b' ' * (-len(data)%4)
    binary = raw[20+json_length:]
    path.write_bytes(struct.pack('<4sIIII',b'glTF',2,20+len(data)+len(binary),len(data),0x4e4f534a)+data+binary)

if __name__=='__main__':
    normalize(Path(__file__).resolve().parents[1]/'assets/models/prosthesis_leg_rigged.glb')

