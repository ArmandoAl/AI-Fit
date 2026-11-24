"""Blender-only static mannequin fixture, not a reconstruction or cloth simulation.

blender --background --threads 2 --python blender_fixture.py -- --output output/3d
"""
import argparse
import json
import math
import sys
import time
from pathlib import Path

import bpy
from mathutils import Vector


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = 0.8
    return mat


def sphere(name, at, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def limb(name, start, end, radius, mat):
    start, end = Vector(start), Vector(end)
    delta = end - start
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=radius, radius2=radius * 0.85,
                                    depth=delta.length, location=(start + end) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()
    obj.data.materials.append(mat)
    return obj


def shell(name, rings, mat):
    n = 32
    vertices = [(width * math.cos(i * 2 * math.pi / n), depth * math.sin(i * 2 * math.pi / n), height)
                for height, width, depth in rings for i in range(n)]
    faces = [(j * n + i, j * n + (i + 1) % n, (j + 1) * n + (i + 1) % n, (j + 1) * n + i)
             for j in range(len(rings) - 1) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for face in mesh.polygons:
        face.use_smooth = True
    return obj


def build(output, body):
    started = time.perf_counter()
    output.mkdir(parents=True, exist_ok=True)
    height = float(body.get('height_m', 1.70))
    shoulder = float(body.get('shoulder_width_m', 0.40))
    waist = float(body.get('waist_width_m', 0.28))
    hip = float(body.get('hip_width_m', 0.36))
    if not (1.2 <= height <= 2.2 and 0.25 <= shoulder <= 0.65 and 0.18 <= waist <= 0.60 and 0.25 <= hip <= 0.70):
        raise ValueError('Body dimensions outside fixture limits; all dimensions are in meters.')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    skin = material('Synthetic mannequin', (0.48, 0.40, 0.32))
    pink = material('Synthetic top', (0.52, 0.10, 0.22))
    blue = material('Synthetic trousers', (0.07, 0.13, 0.24))
    dark = material('Synthetic shoes', (0.035, 0.035, 0.045))
    shell('avatar_torso', [(0.88, hip / 2, 0.105), (1.08, waist / 2, 0.10), (1.40, shoulder / 2, 0.11)], skin)
    limb('avatar_neck', (0, 0, 1.39), (0, 0, 1.51), 0.055, skin)
    sphere('avatar_head', (0, 0, 1.59), (0.085, 0.08, 0.11), skin)
    for sign in (-1, 1):
        x = sign * shoulder / 2
        limb(f'avatar_arm_{sign}', (x, 0, 1.37), (x + sign * 0.12, 0, 0.94), 0.041, skin)
        sphere(f'avatar_hand_{sign}', (x + sign * 0.12, 0, 0.91), (0.037, 0.027, 0.06), skin)
        limb(f'avatar_leg_{sign}', (sign * 0.085, 0, 0.87), (sign * 0.095, 0, 0.10), 0.067, skin)
        sphere(f'shoe_{sign}', (sign * 0.095, -0.04, 0.075), (0.065, 0.13, 0.055), dark)
        limb(f'trousers_leg_{sign}', (sign * 0.085, 0, 0.86), (sign * 0.095, 0, 0.12), 0.078, blue)
    shell('trousers_waist', [(0.81, hip / 2 + 0.015, 0.12), (1.03, waist / 2 + 0.025, 0.12)], blue)
    shell('top_body', [(0.99, waist / 2 + 0.045, 0.13), (1.17, waist / 2 + 0.035, 0.13),
                       (1.37, shoulder / 2 + 0.015, 0.13), (1.44, 0.065, 0.065)], pink)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    for obj in meshes:
        obj.location *= height / 1.70
        obj.scale *= height / 1.70
        obj['fixture_only'] = True
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    scene['description'] = 'Synthetic static pipeline fixture. No scan, rig, cloth simulation or fit prediction.'
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 8
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 2
    scene.render.resolution_x = 384
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.world.color = (0.35, 0.35, 0.35)
    bpy.ops.object.camera_add(location=(2.1, -4.4, 1.9))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, height * 0.52)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = height * 1.30
    scene.camera = camera
    bpy.ops.object.light_add(type='AREA', location=(1.5, -3, 4))
    bpy.context.object.data.energy = 400
    bpy.context.object.data.shape = 'DISK'
    bpy.context.object.data.size = 4
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(output / 'synthetic_outfit.glb'), export_format='GLB',
                              use_selection=True, export_cameras=False, export_lights=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / 'synthetic_outfit.blend'))
    scene.render.filepath = str(output / 'synthetic_outfit.png')
    bpy.ops.render.render(write_still=True)
    report = {'synthetic': True, 'personalized': False, 'rigged': False, 'cloth_simulated': False,
              'blender': bpy.app.version_string, 'render_device': 'CPU', 'threads': 2,
              'mesh_count': len(meshes), 'triangles': sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons),
              'glb_bytes': (output / 'synthetic_outfit.glb').stat().st_size,
              'elapsed_seconds': round(time.perf_counter() - started, 2), 'parameters': body}
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--body-json', type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    build(args.output.resolve(), json.loads(args.body_json.read_text()) if args.body_json else {})
