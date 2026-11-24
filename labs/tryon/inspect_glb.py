"""Check an exported GLB's actual geometry and file budget before device testing."""
import argparse
import json
import struct
from pathlib import Path


def inspect(path):
    raw = path.read_bytes()
    if len(raw) < 20:
        raise ValueError('Truncated GLB header.')
    magic, version, length = struct.unpack_from('<4sII', raw)
    if magic != b'glTF' or version != 2 or length != len(raw):
        raise ValueError('Invalid GLB v2 header or file size.')
    chunk_length, chunk_type = struct.unpack_from('<II', raw, 12)
    if chunk_type != 0x4E4F534A or 20 + chunk_length > length:
        raise ValueError('Invalid GLB JSON chunk.')
    spec = json.loads(raw[20:20 + chunk_length])
    triangles = 0
    for mesh in spec.get('meshes', []):
        for primitive in mesh['primitives']:
            if primitive.get('mode', 4) != 4:
                raise ValueError('Only triangle primitives are supported by this check.')
            accessor = primitive.get('indices', primitive['attributes']['POSITION'])
            triangles += spec['accessors'][accessor]['count'] // 3
    external = [item['uri'] for group in ('buffers', 'images') for item in spec.get(group, []) if 'uri' in item and not item['uri'].startswith('data:')]
    return {'bytes': length, 'triangles': triangles, 'meshes': len(spec.get('meshes', [])),
            'materials': len(spec.get('materials', [])), 'skins': len(spec.get('skins', [])),
            'animations': len(spec.get('animations', [])), 'external_resources': external,
            'nodes': [node.get('name', '') for node in spec.get('nodes', [])],
            'within_initial_budget': triangles <= 30000 and length <= 20 * 2**20 and not external,
            'note': 'Geometry and container check only; not an iPhone performance, visual fit or full glTF conformance test.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb', type=Path)
    args = parser.parse_args()
    print(json.dumps(inspect(args.glb), indent=2))
