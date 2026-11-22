# Prosthesis scan and animation

The original glTF has four mesh chunks beneath a rotated Sketchfab root. The starter GLB adds a two-joint skin and alert torus in the original mesh-local coordinate system. Its local Y axis is oblique to the upright scan, and its preset knee pivot does not follow the center of the upright knee section.

The Blender build applies the original root transform, merges coincident vertices and reduces the surface to approximately 48,000 triangles. Geometry is scaled by 0.001 to give the viewer consistent scene units. Physical size is unverified. Original surface proportions and material are retained.

The knee pivot uses the middle of the horizontal scan section at 63.5% of scan height, chosen by inspecting the front and side silhouettes. The hinge axis is perpendicular to the vertical and the projected toe direction. Upper and lower vertex weights form a smooth transition over 0.13 scene metres. The 2-second flexion cycle peaks at 32 degrees. This is an illustrative product animation. The clip, joint weights and pivots are editable in artwork/kinetiq_rig.blend.

KneeAlertRing follows the lower joint and encloses the scan at the pivot with a small clearance. The GLB starts with zero ring opacity. Both viewers use the same material to reveal the red ring during an alert and reset the clip at rest. Rotation and zoom operate independently of the motion state.

From the project directory, with Blender 5.1 on PATH:

```sh
blender -b --factory-startup --python-exit-code 1 -P artwork/build_rig.py
blender -b --factory-startup --python-exit-code 1 -P artwork/validate_rig.py
```

The validator reimports the exported GLB, checks its container, skin and animation, evaluates its neutral/flexed/return poses, checks the upper-leg displacement, estimates deformation by edge-length ratios, and verifies ring centering. Anatomical accuracy and real-device correspondence require independent validation.

