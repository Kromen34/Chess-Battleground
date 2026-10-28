"""Assemble les pièces STL d'une figurine d'impression en .glb pour Godot.

Les kits de figurines sont découpés pour l'impression, mais leurs pièces partagent
le même repère : on les fusionne telles quelles. Pour chaque variante du kit :
  - allègement par fusion d'arêtes à quadriques (pymeshlab), qui garde écailles, dents
    et griffes bien mieux qu'un clustering de sommets ;
  - « lavis » de figurine peinte en couleurs de sommets : occlusion ambiante calculée sur
    la figurine entière (les pièces s'ombrent entre elles) + creux fins assombris et
    arêtes légèrement éclaircies (brossage à sec) ;
  - millimètres -> unités du jeu : le socle fait "footprint" cases de diamètre ;
  - axes : STL Z vers le haut -> Godot Y vers le haut, figurine tournée vers -Z ;
  - origine : centre du socle, au ras du sol.
Godot génère les niveaux de détail (LOD) à l'import : on peut garder beaucoup de triangles.

Usage (dépendances : numpy, pymeshlab) :
  python tools/assembler_figurine.py tools/kits/<kit>.json [dossier_des_stl] [variante ...]
Le .json décrit les pièces et les variantes (voir tools/kits/). "output_dir" est relatif à
la racine du dépôt ; le dossier des STL vient de "source", ou du 2e argument s'il est
donné (« - » pour garder "source"). Sans nom de variante, elles sont toutes produites.
"""

import json
import os
import struct
import sys
import time

import numpy as np
import pymeshlab

# Matériaux de base, façon figurine peinte. Le jeu teinte "base" aux couleurs du joueur.
MATERIALS = {
    "base": {"color": [0.16, 0.15, 0.14], "metallic": 0.0, "roughness": 0.85},
    "scales": {"color": [0.24, 0.06, 0.04], "metallic": 0.1, "roughness": 0.5},
    "wings": {"color": [0.2, 0.05, 0.04], "metallic": 0.05, "roughness": 0.6},
    "horn": {"color": [0.55, 0.5, 0.42], "metallic": 0.0, "roughness": 0.55},
    "armor": {"color": [0.42, 0.4, 0.38], "metallic": 0.85, "roughness": 0.35},
    "rider": {"color": [0.3, 0.28, 0.26], "metallic": 0.7, "roughness": 0.4},
    "weapon": {"color": [0.62, 0.6, 0.58], "metallic": 0.9, "roughness": 0.3},
    "leather": {"color": [0.22, 0.14, 0.09], "metallic": 0.0, "roughness": 0.7},
}

# Lavis : force de l'occlusion ambiante, des creux fins et de l'éclaircissement des arêtes.
AO_STRENGTH = 0.65
CAVITY_STRENGTH = 0.55
EDGE_LIGHTEN = 0.18

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_part(path):
    """Charge un STL et retourne (positions, faces) en numpy, sommets fusionnés."""
    ms = pymeshlab.MeshSet()
    ms.load_new_mesh(path)
    ms.meshing_remove_duplicate_vertices()
    ms.meshing_remove_unreferenced_vertices()
    m = ms.current_mesh()
    return m.vertex_matrix().copy(), m.face_matrix().copy()


def simplify(pos, faces, target):
    """Fusion d'arêtes à quadriques jusqu'à [target] triangles."""
    if len(faces) <= target:
        return pos, faces
    ms = pymeshlab.MeshSet()
    ms.add_mesh(pymeshlab.Mesh(vertex_matrix=pos, face_matrix=faces))
    ms.meshing_decimation_quadric_edge_collapse(
        targetfacenum=int(target), qualitythr=0.4, preserveboundary=True, boundaryweight=2.0,
        preservenormal=True, optimalplacement=True, planarquadric=True, autoclean=True)
    m = ms.current_mesh()
    return m.vertex_matrix().copy(), m.face_matrix().copy()


def vertex_normals(pos, faces):
    fn = np.cross(pos[faces[:, 1]] - pos[faces[:, 0]], pos[faces[:, 2]] - pos[faces[:, 0]])
    vn = np.zeros_like(pos)
    for i in range(3):
        np.add.at(vn, faces[:, i], fn)
    return vn / np.maximum(np.linalg.norm(vn, axis=1), 1e-12)[:, None]


def _neighbour_mean(pos, faces, values):
    """Moyenne de [values] sur les voisins de chaque sommet (par les arêtes)."""
    acc = np.zeros_like(values)
    cnt = np.zeros(len(pos))
    for a, b in ((0, 1), (1, 2), (2, 0)):
        np.add.at(acc, faces[:, a], values[faces[:, b]])
        np.add.at(acc, faces[:, b], values[faces[:, a]])
        np.add.at(cnt, faces[:, a], 1)
        np.add.at(cnt, faces[:, b], 1)
    shape = (-1,) + (1,) * (values.ndim - 1)
    return acc / np.maximum(cnt, 1).reshape(shape)


def cavity(pos, faces, normals):
    """Creux (> 0) et arêtes saillantes (< 0) à petite échelle, dans [-1, 1]."""
    lap = _neighbour_mean(pos, faces, pos) - pos
    edge = np.linalg.norm(pos[faces[:, 0]] - pos[faces[:, 1]], axis=1).mean()
    c = np.einsum("ij,ij->i", lap, normals) / max(edge, 1e-9)
    for _ in range(2):
        c = 0.5 * c + 0.5 * _neighbour_mean(pos, faces, c)
    scale = np.percentile(np.abs(c), 95)
    return np.clip(c / max(scale, 1e-9), -1.0, 1.0)


def ambient_occlusion(pos, faces):
    """Part du ciel visible par sommet (0 = enfoui, 1 = à découvert), figurine entière."""
    ms = pymeshlab.MeshSet()
    ms.add_mesh(pymeshlab.Mesh(vertex_matrix=pos, face_matrix=faces))
    try:
        ms.compute_scalar_ambient_occlusion_gpu(occmode="per-Vertex", reqviews=256, usegpu=True,
                                                depthtexsize=2048)
    except pymeshlab.PyMeshLabException as e:
        print(f"  (occlusion sur GPU impossible : {e} ; calcul sur CPU, plus lent)", flush=True)
        ms.compute_scalar_ambient_occlusion(rays=128)
    ao = ms.current_mesh().vertex_scalar_array().copy()
    lo, hi = np.percentile(ao, 2), np.percentile(ao, 98)
    return np.clip((ao - lo) / max(hi - lo, 1e-9), 0.0, 1.0)


def wash(pos, faces, normals):
    """Facteur de couleur par sommet (multiplie la couleur du matériau)."""
    ao = ambient_occlusion(pos, faces)
    cav = cavity(pos, faces, normals)
    shade = 1.0 - AO_STRENGTH * (1.0 - ao) ** 1.5
    shade *= 1.0 - CAVITY_STRENGTH * np.clip(cav, 0.0, 1.0)
    shade *= 1.0 + EDGE_LIGHTEN * np.clip(-cav, 0.0, 1.0)
    return np.clip(shade, 0.05, 1.2)


def write_glb(path, parts):
    """parts : liste de (nom, matériau, positions, normales, couleurs, faces)."""
    blob = bytearray()
    views, accessors, meshes, nodes = [], [], [], []
    mat_names = sorted({p[1] for p in parts})
    materials = []
    for m in mat_names:
        spec = MATERIALS[m]
        materials.append({
            "name": m,
            # Les surfaces fines (membranes des ailes) peuvent perdre une face à
            # l'allègement : on affiche les deux côtés pour ne pas voir de trous.
            "doubleSided": True,
            "pbrMetallicRoughness": {
                "baseColorFactor": spec["color"] + [1.0],
                "metallicFactor": spec["metallic"],
                "roughnessFactor": spec["roughness"],
            },
        })

    def add_view(data, target):
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": target})
        blob.extend(data)
        return len(views) - 1

    for name, mat, pos, nrm, col, faces in parts:
        pos32 = pos.astype("<f4")
        rgba = np.concatenate([np.repeat(col[:, None], 3, axis=1), np.ones((len(col), 1))], axis=1)
        attrs = {}
        for key, arr, kind in (("POSITION", pos32, "VEC3"), ("NORMAL", nrm.astype("<f4"), "VEC3"),
                               ("COLOR_0", rgba.astype("<f4"), "VEC4")):
            view = add_view(arr.tobytes(), 34962)
            acc = {"bufferView": view, "componentType": 5126, "count": len(arr), "type": kind}
            if key == "POSITION":
                acc["min"] = pos32.min(0).tolist()
                acc["max"] = pos32.max(0).tolist()
            accessors.append(acc)
            attrs[key] = len(accessors) - 1
        idx = faces.astype("<u4").ravel()
        accessors.append({"bufferView": add_view(idx.tobytes(), 34963), "componentType": 5125,
                          "count": len(idx), "type": "SCALAR"})
        meshes.append({"name": name, "primitives": [{
            "attributes": attrs, "indices": len(accessors) - 1, "material": mat_names.index(mat)}]})
        nodes.append({"name": name, "mesh": len(meshes) - 1})

    root = {"name": os.path.splitext(os.path.basename(path))[0], "children": list(range(len(nodes)))}
    nodes.append(root)
    while len(blob) % 4:
        blob.append(0)
    gltf = {
        "asset": {"version": "2.0", "generator": "Chess Battleground assembler_figurine.py"},
        "scene": 0,
        "scenes": [{"nodes": [len(nodes) - 1]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))


def budgets(parts, originals, total):
    """Répartit [total] triangles entre les pièces, au prorata de leur détail d'origine
    (pondéré par "weight" : les membranes fines en demandent plus)."""
    w = np.array([len(originals[p["id"]][1]) * p.get("weight", 1.0) for p in parts], dtype=float)
    share = total * w / w.sum()
    return [int(min(s, len(originals[p["id"]][1]))) for p, s in zip(parts, share)]


def snap_base(base_pos, others):
    """Recale un socle modélisé ailleurs que la figurine : son dessus vient sous les
    pattes (points les plus bas), centré sur elles."""
    pts = np.concatenate(others)
    low = pts[pts[:, 2] < pts[:, 2].min() + 3.0]
    lo, hi = base_pos.min(0), base_pos.max(0)
    shift = np.array([low[:, 0].mean() - (lo[0] + hi[0]) / 2,
                      low[:, 1].mean() - (lo[1] + hi[1]) / 2,
                      pts[:, 2].min() - hi[2] + 0.5])
    return base_pos + shift


def build_variant(kit, name, originals):
    parts_by_id = {p["id"]: p for p in kit["parts"]}
    parts = [parts_by_id[i] for i in kit["variants"][name]]
    footprint = kit.get("footprint", 0.85)
    originals = dict(originals)
    for p in parts:
        if p.get("snap_under"):
            others = [originals[q["id"]][0] for q in parts if q is not p]
            originals[p["id"]] = (snap_base(originals[p["id"]][0], others), originals[p["id"]][1])

    # Repère : socle centré, posé au sol, diamètre [footprint] cases.
    base = next(originals[p["id"]][0] for p in parts if p["material"] == "base")
    lo, hi = base.min(0), base.max(0)
    center = np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])
    scale = footprint / max(hi[0] - lo[0], hi[1] - lo[1])
    # STL (x, y, z), Z en haut -> Godot (-x, z, y) : rotation, pas de miroir. La tête
    # (vers -y dans le STL) regarde vers -Z, l'avant d'un nœud Godot.
    axes = np.array([[-1.0, 0, 0], [0, 0, 1.0], [0, 1.0, 0]])

    simplified = []
    for part, target in zip(parts, budgets(parts, originals, kit["triangles"])):
        pos, faces = simplify(*originals[part["id"]], target)
        pos = ((pos - center) * scale) @ axes.T
        simplified.append((part, pos, faces))

    # Lavis calculé sur la figurine entière, puis redécoupé par pièce.
    offsets = np.cumsum([0] + [len(s[1]) for s in simplified])
    all_pos = np.concatenate([s[1] for s in simplified])
    all_faces = np.concatenate([s[2] + o for s, o in zip(simplified, offsets[:-1])])
    all_nrm = vertex_normals(all_pos, all_faces)
    shade = wash(all_pos, all_faces, all_nrm)

    out_parts = []
    for (part, pos, faces), o0, o1 in zip(simplified, offsets[:-1], offsets[1:]):
        out_parts.append((part["name"], part["material"], pos, all_nrm[o0:o1], shade[o0:o1], faces))
    out = os.path.join(REPO_ROOT, kit["output_dir"], name + ".glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    write_glb(out, out_parts)
    print(f"-> {out} : {len(all_faces)} triangles, hauteur {np.ptp(all_pos[:, 1]):.2f} case(s), "
          f"{os.path.getsize(out) / 1e6:.1f} Mo", flush=True)


def main(kit_path, source=None, only=None):
    with open(kit_path, encoding="utf-8") as f:
        kit = json.load(f)
    src = source if source and source != "-" else kit["source"]
    if not os.path.isdir(src):
        sys.exit(f"Dossier des STL introuvable : {src}. Passe le bon dossier en 2e argument.")
    names = only or list(kit["variants"])
    needed = {i for n in names for i in kit["variants"][n]}
    originals = {}
    for part in kit["parts"]:
        if part["id"] in needed:
            t = time.time()
            originals[part["id"]] = load_part(os.path.join(src, part["file"]))
            print(f"  {part['id']:<14} {len(originals[part['id']][1]):>8} triangles "
                  f"({time.time() - t:.0f} s)", flush=True)
    for name in names:
        build_variant(kit, name, originals)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None, sys.argv[3:] or None)
