"""Refresh the standalone restore extensions from checked-in migrations."""
from pathlib import Path
root = Path(__file__).resolve().parent
target = root / 'schema.sql'
marker = '-- Restore extensions, replayed in chronological order.'
base = target.read_text().split(marker)[0].rstrip()
files = [root / f'v0.9.{v}-migration.sql' for v in (1, 2, 3)] + sorted((root / 'migrations').glob('*.sql'))
target.write_text(base + '\n\n' + marker + ' Generated from checked-in migration sources.\n' + ''.join('\n-- SOURCE: ' + f.name + '\n' + f.read_text().rstrip() + '\n' for f in files))
