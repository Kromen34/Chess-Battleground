"""Assemble les pièces STL d'une figurine d'impression en un seul .glb pour Godot.

Les kits de figurines sont découpés pour l'impression, mais leurs pièces partagent
le même repère : on les fusionne telles quelles. Chaque pièce est allégée
(clustering de sommets avec quadriques d'erreur, qui garde les arêtes et les reliefs
mieux qu'une simple moyenne), puis convertie :
  - millimètres -> unités du jeu : le socle fait FOOTPRINT cases de diamètre ;
  - axes : STL Z vers le haut -> Godot Y vers le haut, figurine tournée vers -Z ;
  - origine : centre du socle, au ras du sol.

Usage (dépendances : numpy uniquement) :
  python tools/assembler_figurine.py tools/kits/<kit>.json [dossier_des_stl]
où le .json décrit les pièces. "output" est relatif à la racine du dépôt ; le dossier
des STL vient de "source", ou du 2e argument s'il est donné (autre PC, autre lecteur).
"""

import json
import os
import struct
import sys

import numpy as np

# Diamètre du socle en cases du plateau (une case = 1.0).
FOOTPRINT = 0.85

# Matériaux de base, façon figurine peinte. Le jeu teinte "base" aux couleurs du joueur.
MATERIALS = {
    "base": {"color": [0.16, 0.15, 0.14], "metallic": 0.0, "roughness": 0.85},
    "scales": {"color": [0.24, 0.06, 0.04], "metallic": 0.1, "roughness": 0.5},
    "wings": {"color": [0.2, 0.05, 0.04], "metallic": 0.05, "roughness": 0.6},
    "armor": {"color": [0.42, 0.4, 0.38], "metallic": 0.85, "roughness": 0.35},
    "rider": {"color": [0.3, 0.28, 0.26], "metallic": 0.7, "roughness": 0.4},
    "weapon": {"color": [0.62, 0.6, 0.58], "metallic": 0.9, "roughness": 0.3},
}


def load_stl(path):
    """Retourne les triangles (N, 3, 3) d'un STL binaire, en float64."""
    with open(path, "rb") as f:
        head = f.read(84)
    count = int.from_bytes(head[80:84], "little")
    if os.path.getsize(path) != 84 + 50 * count:
        raise ValueError(f"STL ASCII non géré : {path}")
    dt = np.dtype([("n", "<f4", 3), ("v", "<f4", (3, 3)), ("a", "<u2")])
    return np.fromfile(path, dtype=dt, offset=84)["v"].astype(np.float64)


def _cluster(tris, cell):
    """Fusionne les sommets par cellule de taille [cell]. Retourne (positions, faces)."""
    v = tris.reshape(-1, 3)
    origin = v.min(0)
    keys = np.floor((v - origin) / cell).astype(np.int64)
    dims = keys.max(0) + 1
    flat = (keys[:, 0] * dims[1] + keys[:, 1]) * dims[2] + keys[:, 2]
    uniq, inv = np.unique(flat, return_inverse=True)
    n = len(uniq)

    # Quadrique d'erreur par cellule : somme des plans des triangles qui la touchent,
    # pondérés par leur aire. Le sommet fusionné minimise la distance à ces plans.
    e1 = tris[:, 1] - tris[:, 0]
    e2 = tris[:, 2] - tris[:, 0]
    cross = np.cross(e1, e2)
    area = np.linalg.norm(cross, axis=1)
    normal = cross / np.maximum(area, 1e-12)[:, None]
    d = -np.einsum("ij,ij->i", normal, tris[:, 0])
    w = np.repeat(area, 3)
    nn = np.repeat(normal, 3, axis=0)
    dd = np.repeat(d, 3)
    a_mat = np.zeros((n, 3, 3))
    b_vec = np.zeros((n, 3))
    np.add.at(a_mat, inv, w[:, None, None] * nn[:, :, None] * nn[:, None, :])
    np.add.at(b_vec, inv, -(w * dd)[:, None] * nn)
    mean = np.zeros((n, 3))
    np.add.at(mean, inv, v)
    mean /= np.bincount(inv, minlength=n)[:, None]
    # Régularisation vers la moyenne : stable sur les zones planes.
    reg = 1e-3 * np.maximum(np.trace(a_mat, axis1=1, axis2=2), 1e-12)
    a_mat += reg[:, None, None] * np.eye(3)
    b_vec += reg[:, None] * mean
    pos = np.linalg.solve(a_mat, b_vec[:, :, None])[:, :, 0]
    # Le sommet doit rester dans (ou près de) sa cellule, sinon on garde la moyenne.
    cell_lo = origin + np.floor((mean - origin) / cell) * cell
    outside = np.any((pos < cell_lo - 0.5 * cell) | (pos > cell_lo + 1.5 * cell), axis=1)
    pos[outside] = mean[outside]

    faces = inv.reshape(-1, 3)
    keep = (faces[:, 0] != faces[:, 1]) & (faces[:, 1] != faces[:, 2]) & (faces[:, 0] != faces[:, 2])
    faces = faces[keep]
    _, first = np.unique(np.sort(faces, axis=1), axis=0, return_index=True)
    faces = faces[np.sort(first)]
    # Retire les sommets devenus inutilisés.
    used, remap = np.unique(faces, return_inverse=True)
    return pos[used], remap.reshape(-1, 3)


def simplify(tris, target):
    """Allège jusqu'à environ [target] triangles (recherche de la taille de cellule)."""
    if len(tris) <= target:
        return _cluster(tris, 1e-4)
    size = np.ptp(tris.reshape(-1, 3), axis=0).max()
    lo, hi = size / 2000.0, size / 10.0
    best = None
    for _ in range(14):
        cell = np.sqrt(lo * hi)
        pos, faces = _cluster(tris, cell)
        if best is None or abs(len(faces) - target) < abs(len(best[1]) - target):
            best = (pos, faces)
        if abs(len(faces) - target) < target * 0.05:
            break
        if len(faces) > target:
            lo = cell
        else:
            hi = cell
    return best


def vertex_normals(pos, faces):
    fn = np.cross(pos[faces[:, 1]] - pos[faces[:, 0]], pos[faces[:, 2]] - pos[faces[:, 0]])
    vn = np.zeros_like(pos)
    for i in range(3):
        np.add.at(vn, faces[:, i], fn)
    return vn / np.maximum(np.linalg.norm(vn, axis=1), 1e-12)[:, None]


def write_glb(path, parts):
    """parts : liste de (nom, matériau, positions, normales, faces)."""
    blob = bytearray()
    views, accessors, meshes, nodes = [], [], [], []
    mat_names = sorted({p[1] for p in parts})
    materials = []
    for m in mat_names:
        spec = MATERIALS[m]
        materials.append({
            "name": m,
            # Les surfaces fines (membranes des ailes) perdent parfois une face à
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

    for name, mat, pos, nrm, faces in parts:
        pos32 = pos.astype("<f4")
        attrs = {}
        for key, arr in (("POSITION", pos32), ("NORMAL", nrm.astype("<f4"))):
            view = add_view(arr.tobytes(), 34962)
            acc = {"bufferView": view, "componentType": 5126, "count": len(arr), "type": "VEC3"}
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


REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main(kit_path, source=None):
    with open(kit_path, encoding="utf-8") as f:
        kit = json.load(f)
    src = source or kit["source"]
    if not os.path.isdir(src):
        sys.exit(f"Dossier des STL introuvable : {src}. "
                 "Passe le bon dossier en 2e argument.")
    loaded = []
    for part in kit["parts"]:
        tris = load_stl(os.path.join(src, part["file"]))
        loaded.append((part, tris))
        print(f"  {part['name']:<10} {len(tris):>8} triangles", flush=True)

    # Repère : socle centré, posé au sol, diamètre FOOTPRINT cases.
    base = next(t for p, t in loaded if p["material"] == "base").reshape(-1, 3)
    lo, hi = base.min(0), base.max(0)
    center = np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])
    scale = FOOTPRINT / max(hi[0] - lo[0], hi[1] - lo[1])
    # STL (x, y, z), Z en haut -> Godot (-x, z, y) : rotation, pas de miroir. La tête
    # (vers -y dans le STL) regarde vers -Z, l'avant d'un nœud Godot.
    axes = np.array([[-1.0, 0, 0], [0, 0, 1.0], [0, 1.0, 0]])

    out_parts = []
    total = 0
    for part, tris in loaded:
        pos, faces = simplify(tris, part["triangles"])
        pos = ((pos - center) * scale) @ axes.T
        out_parts.append((part["name"], part["material"], pos, vertex_normals(pos, faces), faces))
        total += len(faces)
    out = os.path.join(REPO_ROOT, kit["output"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    write_glb(out, out_parts)
    allpos = np.concatenate([p[2] for p in out_parts])
    print(f"-> {out} : {total} triangles, hauteur {np.ptp(allpos[:, 1]):.2f} case(s), "
          f"{os.path.getsize(out) / 1e6:.1f} Mo")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
