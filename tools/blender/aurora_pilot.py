"""Piloto Aurora modelado em Blender e exportado para art/pilots/aurora.glb.

Correr a partir da raiz do projeto (precisa do módulo `bpy`, `pip install bpy`):

    python3 tools/blender/aurora_pilot.py [--preview caminho.png]

Coordenadas: tudo aqui é escrito em unidades e eixos do Godot (Y para cima, frente em -Z)
e convertido para o Blender por `g()`. O exportador glTF devolve-os ao Godot tal e qual.

Contrato com `indie_arena_view.gd`:
- nós vazios LegL, LegR e Gun com a mesma origem do modelo por código, para a animação
  partilhada (o Flash do disparo continua a ser criado no Godot, dentro de Gun);
- um material por objeto, com o nome do papel: team, cream, dark, gold, chest_light,
  eyes e muzzle. O Godot troca-os pelos materiais da cena, por isso a cor de equipa,
  o modo de qualidade Leve e o verniz da cerâmica funcionam como antes.
"""
import math
import sys
from pathlib import Path

import bpy
import bmesh  # depois do bpy: o módulo bpy é que o regista
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "art" / "pilots" / "aurora.glb"

# Cores só para a pré-visualização no Blender; no jogo o Godot substitui-as.
PREVIEW = {
    "team": ((0.447, 0.867, 0.776), False),
    "cream": ((0.871, 0.859, 0.792), False),
    "dark": ((0.133, 0.235, 0.275), False),
    "gold": ((0.824, 0.678, 0.451), False),
    "chest_light": ((0.36, 0.69, 0.62), True),
    "eyes": ((0.6, 0.93, 0.86), True),
    "muzzle": ((0.56, 0.9, 0.82), True),
}


def g(x, y, z):
    """Godot (x, y, z) -> Blender (x, -z, y)."""
    return Vector((x, -z, y))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name, (rgb, glow) in PREVIEW.items():
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        bsdf.inputs["Roughness"].default_value = 0.45
        if glow:
            bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
            bsdf.inputs["Emission Strength"].default_value = 2.0


def link(obj, parent=None, role="team", smooth=True):
    if obj.name not in bpy.context.collection.objects:
        bpy.context.collection.objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(bpy.data.materials[role])
    if parent is not None:
        obj.parent = parent
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj


def empty(name, pos, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = g(*pos)
    if parent is not None:
        obj.parent = parent
        obj.location = g(*pos) - parent.matrix_world.translation
    bpy.context.view_layer.update()
    return obj


def local(parent, pos):
    return g(*pos) - (parent.matrix_world.translation if parent else Vector())


def from_bmesh(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return bpy.data.objects.new(name, me)


def rounded_box(name, pos, size, radius, role, parent=None, segments=3, subdiv=0):
    """Caixa com arestas boleadas (modificador Bevel), em dimensões Godot."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = size
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, -v.co.z * sz, v.co.y * sy))
    obj = link(from_bmesh(name, bm), parent, role)
    obj.location = local(parent, pos)
    bev = obj.modifiers.new("bevel", "BEVEL")
    bev.width = min(radius, min(size) * 0.49)
    bev.segments = segments
    bev.limit_method = "NONE"
    bev.harden_normals = False
    if subdiv:
        sub = obj.modifiers.new("subdiv", "SUBSURF")
        sub.levels = subdiv
        sub.render_levels = subdiv
    return obj


def ellipsoid(name, pos, size, role, parent=None, segments=24, rings=12):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=0.5)
    sx, sy, sz = size
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sz, v.co.z * sy))
    obj = link(from_bmesh(name, bm), parent, role)
    obj.location = local(parent, pos)
    return obj


def cylinder(name, pos, radius, depth, role, parent=None, axis="y", segments=16, bevel=0.0, cap_scale=1.0):
    """Cilindro ao longo de um eixo Godot ('x', 'y' ou 'z')."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius * cap_scale, depth=depth)
    obj = link(from_bmesh(name, bm), parent, role)
    obj.location = local(parent, pos)
    # O cone do bmesh nasce ao longo de Z do Blender, que é Y no Godot.
    if axis == "z":
        obj.rotation_euler = (math.radians(90), 0, 0)
    elif axis == "x":
        obj.rotation_euler = (0, math.radians(90), 0)
    if bevel:
        bev = obj.modifiers.new("bevel", "BEVEL")
        bev.width = bevel
        bev.segments = 2
        bev.limit_method = "ANGLE"
    return obj


def torus(name, pos, major, minor, role, parent=None, axis="y", segments=24):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=segments, minor_segments=6)
    obj = bpy.context.active_object
    obj.name = name
    link(obj, parent, role)
    obj.location = local(parent, pos)
    if axis == "z":
        obj.rotation_euler = (math.radians(90), 0, 0)
    elif axis == "x":
        obj.rotation_euler = (0, math.radians(90), 0)
    return obj


def boolean_cut(target, cutter):
    mod = target.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    mod.solver = "EXACT"
    cutter.hide_set(True)
    return cutter


def helmet(body):
    # Casco de cerâmica: esfera achatada, subdividida para uma curva limpa, com a abertura
    # do visor recortada em vez de um disco colado por cima.
    shell = ellipsoid("Helmet", (0, 1.26, -0.03), (0.93, 0.82, 0.82), "cream", body, 40, 20)
    cutter = rounded_box("HelmetCut", (0, 1.28, -0.42), (0.7, 0.4, 0.3), 0.14, "dark", body, 4)
    boolean_cut(shell, cutter)
    # Visor escuro ligeiramente recuado, com o aro de cerâmica a fazer de moldura.
    ellipsoid("Visor", (0, 1.285, -0.27), (0.76, 0.45, 0.36), "dark", body, 32, 14)
    rim = torus("VisorRim", (0, 1.28, -0.395), 0.3, 0.02, "cream", body, axis="z", segments=32)
    rim.scale = (1.18, 0.66, 1)
    for x in (-0.16, 0.16):
        rounded_box("Eye" + ("L" if x < 0 else "R"), (x, 1.31, -0.44), (0.07, 0.12, 0.03), 0.03, "eyes", body, 3)
    # Crista de equipa em quilha, a correr do visor para a nuca.
    crest = rounded_box("Crest", (0, 1.64, -0.02), (0.1, 0.07, 0.52), 0.035, "team", body, 3)
    crest.rotation_euler = (math.radians(-6), 0, 0)
    cylinder("CrestLight", (0, 1.665, -0.25), 0.028, 0.03, "eyes", body, axis="y", segments=12)
    # Auscultadores de latão com um anel embutido e uma antena curta de um dos lados.
    for side in (-1, 1):
        cylinder("EarPod" + ("L" if side < 0 else "R"), (side * 0.455, 1.26, 0), 0.16, 0.1, "gold", body, axis="x", segments=28, bevel=0.03)
        torus("EarRing" + ("L" if side < 0 else "R"), (side * 0.51, 1.26, 0), 0.1, 0.014, "dark", body, axis="x", segments=20)
        cylinder("EarCap" + ("L" if side < 0 else "R"), (side * 0.515, 1.26, 0), 0.07, 0.02, "team", body, axis="x", segments=20)
    cylinder("Antenna", (0.46, 1.48, 0.05), 0.012, 0.3, "dark", body, segments=8)
    ellipsoid("AntennaTip", (0.46, 1.64, 0.05), (0.05, 0.05, 0.05), "eyes", body, 12, 6)


def torso(body):
    # Tronco de equipa com arestas grandes e uma segunda camada no peito, em cerâmica.
    rounded_box("Torso", (0, 0.73, 0), (0.66, 0.65, 0.5), 0.14, "team", body, 4)
    rounded_box("Collar", (0, 1.03, -0.01), (0.46, 0.08, 0.38), 0.04, "dark", body, 3)
    plate = rounded_box("ChestPlate", (0, 0.69, -0.255), (0.42, 0.3, 0.06), 0.03, "cream", body, 3)
    plate.rotation_euler = (math.radians(4), 0, 0)
    rounded_box("ChestCore", (0, 0.7, -0.29), (0.1, 0.14, 0.02), 0.01, "chest_light", body, 2)
    for x in (-0.13, 0.13):
        rounded_box("ChestVent" + ("L" if x < 0 else "R"), (x, 0.63, -0.288), (0.08, 0.025, 0.012), 0.005, "dark", body, 1)
    rounded_box("Belt", (0, 0.46, 0), (0.62, 0.07, 0.47), 0.03, "dark", body, 3)
    cylinder("Buckle", (0, 0.46, -0.24), 0.045, 0.02, "gold", body, axis="z", segments=16)


def backpack(body):
    rounded_box("Pack", (0, 0.7, 0.34), (0.46, 0.49, 0.26), 0.08, "dark", body, 3)
    rounded_box("PackLid", (0, 0.88, 0.47), (0.3, 0.05, 0.02), 0.01, "team", body, 2)
    for x in (-0.15, 0.15):
        cylinder("Tank" + ("L" if x < 0 else "R"), (x, 0.68, 0.48), 0.07, 0.32, "gold", body, segments=20, bevel=0.02)
        cylinder("Nozzle" + ("L" if x < 0 else "R"), (x, 0.49, 0.48), 0.055, 0.07, "dark", body, segments=20, cap_scale=1.35)


def arms(body):
    for side in (-1, 1):
        tag = "L" if side < 0 else "R"
        rounded_box("Shoulder" + tag, (side * 0.43, 0.88, -0.02), (0.3, 0.3, 0.37), 0.13, "team", body, 4)
        torus("ShoulderTrim" + tag, (side * 0.43, 0.8, -0.02), 0.155, 0.014, "gold", body, segments=20)
        ellipsoid("Forearm" + tag, (side * 0.46, 0.65, -0.14), (0.22, 0.34, 0.23), "dark", body, 16, 8)
        torus("Cuff" + tag, (side * 0.46, 0.55, -0.14), 0.1, 0.02, "cream", body, segments=24)
    # Mão esquerda em punho; a direita segura a manopla (Gun).
    ellipsoid("HandL", (-0.46, 0.47, -0.17), (0.16, 0.14, 0.16), "cream", body, 16, 8)


def legs(body):
    for side in (-1, 1):
        leg = empty("LegL" if side < 0 else "LegR", (side * 0.22, 0.31, 0), body)
        ellipsoid("Thigh", (side * 0.22, 0.28, 0), (0.24, 0.32, 0.26), "dark", leg, 16, 8)
        torus("KneeRing", (side * 0.22, 0.2, 0), 0.115, 0.016, "gold", leg, segments=24)
        rounded_box("Boot", (side * 0.22, 0.12, -0.08), (0.34, 0.2, 0.48), 0.09, "cream", leg, 4)
        rounded_box("BootToe", (side * 0.22, 0.1, -0.27), (0.26, 0.1, 0.1), 0.04, "team", leg, 3)
        rounded_box("Sole", (side * 0.22, 0.035, -0.08), (0.32, 0.06, 0.45), 0.028, "dark", leg, 2)


def gun(body):
    root = empty("Gun", (0, 0, 0), body)
    rounded_box("Gauntlet", (0.29, 0.7, -0.44), (0.33, 0.32, 0.5), 0.1, "cream", root, 4)
    rounded_box("GauntletStripe", (0.29, 0.865, -0.46), (0.1, 0.02, 0.36), 0.01, "team", root, 2)
    for x in (0.12, 0.46):
        rounded_box("GauntletRail" + ("L" if x < 0.29 else "R"), (x, 0.7, -0.46), (0.014, 0.08, 0.26), 0.006, "dark", root, 1)
    cylinder("Barrel", (0.29, 0.7, -0.73), 0.12, 0.14, "dark", root, axis="z", segments=24, bevel=0.02)
    torus("MuzzleRing", (0.29, 0.7, -0.8), 0.1, 0.018, "gold", root, axis="z", segments=24)
    cylinder("Muzzle", (0.29, 0.7, -0.815), 0.07, 0.02, "muzzle", root, axis="z", segments=20)


def build():
    reset()
    body = empty("Body", (0, 0, 0))
    legs(body)
    torso(body)
    backpack(body)
    arms(body)
    helmet(body)
    gun(body)
    bake()
    return body


def bake():
    """Aplica os modificadores, apaga os cortadores e marca como vivas as arestas acima de 35°."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    baked = {obj: bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph)) for obj in meshes if not obj.name.endswith("Cut")}
    for obj in meshes:
        if obj.name.endswith("Cut"):
            bpy.data.objects.remove(obj)
    for obj, data in baked.items():
        obj.modifiers.clear()
        obj.data = data
        for poly in data.polygons:
            poly.use_smooth = True
        data.set_sharp_from_angle(angle=math.radians(35))
    # Uma malha por material em cada parte que se mexe (corpo, pernas, manopla): o Godot
    # desenha o piloto em poucas chamadas em vez de uma por peça.
    groups = {}
    for obj in baked:
        groups.setdefault((obj.parent.name, obj.data.materials[0].name), []).append(obj)
    for (parent, role), parts in groups.items():
        with bpy.context.temp_override(active_object=parts[0], selected_editable_objects=parts):
            bpy.ops.object.join()
        parts[0].name = parent + "_" + role


def export():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT),
        export_apply=True,
        export_yup=True,
        export_texcoords=False,
        export_materials="EXPORT",
        export_extras=False,
    )
    triangles = sum(len(obj.data.loop_triangles) for obj in bpy.data.objects if obj.type == "MESH" and obj.data.calc_loop_triangles() is None)
    print("AURORA_GLB", OUTPUT.relative_to(ROOT), OUTPUT.stat().st_size, "bytes", triangles, "triangles")


def preview(path):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.05, 0.06, 1)
    scene.world = world
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.collection.objects.link(cam)
    cam.data.lens = 70
    cam.location = g(1.9, 1.8, -3.9)
    target = g(0, 0.9, 0)
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    for loc, power in ((g(-2, 3, -3), 400), (g(3, 2, 2), 250)):
        light = bpy.data.objects.new("Light", bpy.data.lights.new("Light", "AREA"))
        light.data.energy = power
        light.data.size = 2
        light.location = loc
        light.rotation_euler = (g(0, 1, 0) - loc).to_track_quat("-Z", "Y").to_euler()
        bpy.context.collection.objects.link(light)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build()
    export()
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
