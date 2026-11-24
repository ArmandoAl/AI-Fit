"""Audit public model metadata and deployment files without downloading weights."""
import json
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

MODELS = [
    ('mobile-vton', 'FlashStight/Mobile-VTON', 'tmllab/2026_CVPR_Mobile-VTON', 'inference.py'),
    ('fashn-vton-1.5', 'fashn-ai/fashn-vton-1.5', 'fashn-AI/fashn-vton-1.5', 'src/fashn_vton/pipeline.py'),
]


def get(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'AI-Fit-local-lab/1.0'})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = response.read(4 * 2**20 + 1)
    if len(data) > 4 * 2**20:
        raise ValueError('Metadata exceeded 4 MiB limit.')
    return data


def audit():
    report = {'checked_at_utc': datetime.now(timezone.utc).isoformat(),
              'weights_downloaded': False, 'inference_executed': False, 'models': []}
    for name, model, repo, entry in MODELS:
        row = {'name': name, 'weights_url': f'https://huggingface.co/{model}',
               'code_url': f'https://github.com/{repo}'}
        try:
            metadata = json.loads(get(f'https://huggingface.co/api/models/{model}?blobs=true'))
            row.update(weights_revision=metadata.get('sha'),
                       weights_license=metadata.get('cardData', {}).get('license'))
            files = metadata.get('siblings', [])
            weights = [f for f in files if f['rfilename'].endswith(('.safetensors', '.bin', '.pth', '.pt', '.onnx', '.mlmodel'))]
            row['weight_files'] = [{'name': f['rfilename'], 'bytes': f.get('size', f.get('lfs', {}).get('size'))} for f in weights]
            known = [f['bytes'] for f in row['weight_files'] if f['bytes'] is not None]
            row['known_weight_bytes'] = sum(known)
            row['all_weight_sizes_known'] = len(known) == len(weights)
            commit = json.loads(get(f'https://api.github.com/repos/{repo}/commits/HEAD'))
            revision = commit['sha']
            row['code_revision'] = revision
            tree = json.loads(get(f'https://api.github.com/repos/{repo}/git/trees/{revision}?recursive=1'))
            paths = [item['path'] for item in tree.get('tree', [])]
            row['tree_truncated'] = tree.get('truncated', False)
            row['apple_deployment_files'] = [p for p in paths if any(s in p.lower() for s in ('.swift', '.mlpackage', '.mlmodel', '.xcodeproj', 'coreml'))]
            row['environment_yaml_present'] = 'environment.yaml' in paths
            source = get(f'https://raw.githubusercontent.com/{repo}/{revision}/{entry}').decode()
            row['device_evidence'] = [line.strip()[:240] for line in source.splitlines() if any(s in line for s in ('.cuda(', 'torch.device(', 'inference_dtype', 'accelerator.device', '.to("cuda"', ".to('cuda'"))][:14]
            row['note'] = 'Metadata only. Listed weights exclude external dependencies and runtime activations. Absence of Apple files does not prove conversion impossible.'
        except (urllib.error.URLError, ValueError, KeyError, TimeoutError) as error:
            row['audit_error'] = str(error)[:300]
        report['models'].append(row)
    return report


if __name__ == '__main__':
    result = audit()
    target = Path(__file__).resolve().parent / 'output' / 'model_audit.json'
    target.parent.mkdir(exist_ok=True)
    target.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps(result, indent=2, ensure_ascii=False))
