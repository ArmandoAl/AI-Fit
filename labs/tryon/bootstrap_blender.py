"""Install a checksum-verified portable Blender on Linux without sudo."""
import hashlib
import shutil
import tarfile
import urllib.request
from pathlib import Path

VERSION = '4.5.9'
ROOT = Path(__file__).resolve().parent
NAME = f'blender-{VERSION}-linux-x64'
BASE = 'https://download.blender.org/release/Blender4.5/'


def install():
    cache = ROOT / '.cache'
    binary = cache / NAME / 'blender'
    if binary.exists():
        print(binary)
        return
    if shutil.disk_usage(ROOT).free < 2 * 2**30:
        raise SystemExit('Need at least 2 GiB free for download and extraction.')
    cache.mkdir(exist_ok=True)
    filename = NAME + '.tar.xz'
    with urllib.request.urlopen(BASE + f'blender-{VERSION}.sha256', timeout=30) as response:
        lines = response.read(100_000).decode().splitlines()
    expected = next((line.split()[0] for line in lines if line.split()[-1].lstrip('*') == filename), None)
    if not expected or len(expected) != 64:
        raise SystemExit('Archive missing from official checksum manifest.')
    archive = cache / (filename + '.part')
    existing_digest = None
    if archive.exists():
        with archive.open('rb') as existing:
            existing_digest = hashlib.file_digest(existing, 'sha256').hexdigest()
    digest = hashlib.sha256()
    if existing_digest != expected:
        total = 0
        with urllib.request.urlopen(BASE + filename, timeout=60) as response, archive.open('wb') as output:
            while block := response.read(4 * 2**20):
                total += len(block)
                if total > 600 * 2**20:
                    raise SystemExit('Download exceeded 600 MiB limit.')
                digest.update(block)
                output.write(block)
    if existing_digest != expected and digest.hexdigest() != expected:
        archive.unlink()
        raise SystemExit('Official SHA-256 did not match; archive removed.')
    with tarfile.open(archive, 'r:xz') as bundle:
        # Python data filter rejects paths escaping the destination.
        for member in bundle.getmembers():
            if member.name != NAME and not member.name.startswith(NAME + '/'):
                raise SystemExit('Unexpected archive root.')
        bundle.extractall(cache, filter='data')
    archive.unlink()
    print(f'Official SHA-256 verified: {expected}')
    print(binary)


if __name__ == '__main__':
    install()
