"""Validate exported GLB structure and evaluate skinned poses after a fresh import."""
from pathlib import Path
import json
import struct
import bpy

root = Path(__file__).resolve().parents[1]
model = root / 'assets/models/prosthesis_leg_rigged.glb'
raw = model.read_bytes()
magic, version, length, chunk, kind = struct.unpack_from('<4sIIII',raw)
assert (magic,version,length,kind)==(b'glTF',2,len(raw),0x4e4f534a)
doc=json.loads(raw[20:20+chunk])
assert len(doc['skins'])==1 and len(doc['skins'][0]['joints'])==2
for view in doc['bufferViews']:
    assert view.get('byteOffset',0)+view['byteLength']<=doc['buffers'][0]['byteLength']
red=next(m for m in doc['materials'] if m['name']=='KneeAlertRed')
assert red['pbrMetallicRoughness']['baseColorFactor'][3]==0
assert red.get('alphaMode') in ['MASK','BLEND']
assert any(a['name']=='IllustrativeFlexion' for a in doc['animations'])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(model))
leg=next(o for o in bpy.context.scene.objects if o.name.startswith('Prosthesis scan'))
ring=next(o for o in bpy.context.scene.objects if o.name.startswith('KneeAlertRing'))
def points(frame):
    bpy.context.scene.frame_set(frame)
    obj=leg.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [obj.matrix_world @ v.co for v in obj.data.vertices]
a,b,c=points(0),points(24),points(48)
height=max(p.z for p in a)-min(p.z for p in a)
assert .8<height<1
shift=[(p-q).length for p,q in zip(a,b)]
assert max(shift)>.10 and max((p-r).length for p,r in zip(a,c))<.002
top=max(v.z for v in a)
assert max(d for d,p in zip(shift,a) if p.z>top-.1)<.002
for v in leg.data.vertices:
    assert abs(sum(g.weight for g in v.groups)-1)<.001
def center(frame):
    bpy.context.scene.frame_set(frame)
    obj=ring.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return sum((obj.matrix_world @ v.co for v in obj.data.vertices),start=obj.location*0)/len(obj.data.vertices)
pivot=center(0)
assert (pivot-center(24)).length<.001
band=[p for p in a if abs(p.z-pivot.z)<.005]
assert band and min(p.x for p in band)<pivot.x<max(p.x for p in band)
assert min(p.y for p in band)<pivot.y<max(p.y for p in band)
# Check actual relative edge stretch in the most flexed pose.
ratios=[]
for edge in leg.data.edges:
    i,j=edge.vertices
    rest=(a[i]-a[j]).length
    if rest>.0001: ratios.append((b[i]-b[j]).length/rest)
ratios.sort()
print('GLB OK. Height %.3f m, maximum displacement %.3f m, 1st/99th percentile edge ratios %.3f / %.3f.'%(height,max(shift),ratios[len(ratios)//100],ratios[-len(ratios)//100]))

