"""Run Blender in background from the project root with --python artwork/build_rig.py."""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Quaternion

root = Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root / 'artwork/original/scene.gltf'))
parts = [o for o in bpy.context.scene.objects if o.type == 'MESH']
# Bake the scan's rotated Sketchfab root into metric, upright geometry.
for o in parts:
    transform = o.matrix_world.copy()
    o.parent = None
    o.matrix_world.identity()
    o.data.transform(transform)
    for v in o.data.vertices:
        v.co *= .001
    o.location = (0, 0, 0)
    o.rotation_euler = (0, 0, 0)
    o.scale = (1, 1, 1)
bpy.ops.object.select_all(action='DESELECT')
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
leg = bpy.context.object
leg.name = 'Prosthesis scan'
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=.000005)
bpy.ops.object.mode_set(mode='OBJECT')
mod = leg.modifiers.new('Mobile surface budget', 'DECIMATE')
mod.ratio = min(1, 48000 / len(leg.data.polygons))
bpy.ops.object.modifier_apply(modifier=mod.name)
points = [v.co.copy() for v in leg.data.vertices]
bottom, top = min(p.z for p in points), max(p.z for p in points)
height = top - bottom
knee_z = bottom + height * .635
band = [p for p in points if abs(p.z-knee_z) < .009]
knee = Vector(tuple((min(p[i] for p in band)+max(p[i] for p in band))/2 for i in range(3)))
foot = [p for p in points if p.z < bottom+.055]
toe = max(foot, key=lambda p: (p.xy-knee.xy).length)
forward = Vector((toe.x-knee.x, toe.y-knee.y, 0)).normalized()
axis = Vector((0,0,1)).cross(forward).normalized()
arm = bpy.data.armatures.new('Knee hinge')
rig = bpy.data.objects.new('Motion rig', arm)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
upper = arm.edit_bones.new('UpperLeg_Root')
upper.head = Vector((knee.x,knee.y,top))
upper.tail = knee
lower = arm.edit_bones.new('Knee_Joint')
lower.head, lower.tail = knee, Vector((knee.x,knee.y,bottom))
lower.parent = upper
lower.use_connect = True
bpy.ops.object.mode_set(mode='OBJECT')
leg.parent = rig
upper_group = leg.vertex_groups.new(name='UpperLeg_Root')
lower_group = leg.vertex_groups.new(name='Knee_Joint')
for v in leg.data.vertices:
    t = min(1, max(0, (v.co.z-knee.z+.065)/.13))
    w = t*t*(3-2*t)
    upper_group.add([v.index],w,'REPLACE')
    lower_group.add([v.index],1-w,'REPLACE')
skin = leg.modifiers.new('Continuous knee weights','ARMATURE')
skin.object = rig
radius = max((p.xy-knee.xy).length for p in band)+.004
bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=12,location=knee,major_radius=radius,minor_radius=.004)
ring = bpy.context.object
ring.name = 'KneeAlertRing'
bpy.context.view_layer.update()
mat = bpy.data.materials.new('KneeAlertRed')
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (1,.025,.04,1)
bsdf.inputs['Alpha'].default_value = 0
mat.surface_render_method = 'BLENDED'
ring.data.materials.append(mat)
# Centered on the pivot; make the ring follow the lower joint.
world = ring.matrix_world.copy()
ring.parent, ring.parent_type, ring.parent_bone = rig, 'BONE', 'Knee_Joint'
bpy.context.view_layer.update()
ring.matrix_world = world
joint = rig.pose.bones['Knee_Joint']
local_axis = joint.bone.matrix_local.to_quaternion().inverted() @ axis
for frame, angle in [(1,0),(13,12),(25,32),(37,12),(49,0)]:
    joint.rotation_quaternion = Quaternion(local_axis, math.radians(angle))
    joint.keyframe_insert(data_path='rotation_quaternion',frame=frame)
rig.animation_data.action.name = 'IllustrativeFlexion'
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1,49
bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for o in (leg,rig,ring):
    o.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(root/'artwork/kinetiq_rig.blend'))
bpy.ops.export_scene.gltf(filepath=str(root/'assets/models/prosthesis_leg_rigged.glb'),use_selection=True,export_format='GLB',export_animations=True,export_animation_mode='ACTIONS')
print('Rig height, knee, ring radius, triangles:',height,list(knee),radius,len(leg.data.polygons))


# Retain a scene-root skinned mesh as recommended by the glTF validator.
import runpy
runpy.run_path(str(root/'artwork/normalize_glb.py'),run_name='__main__')
