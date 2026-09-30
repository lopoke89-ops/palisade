"""Prepare the opt-in individual-background restore check without modifying source.

Run from the repo root: python dev/test/presentation_restore_fixture.py
The browser check also needs out/presentation-baseline.html, built from v0.9.3.3.
"""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / 'dev'))
from assemble import assemble

source = assemble(str(root / 'dev/src'))
property_text = "campfire:['terrain','#55331f','#211a16','#100e0c'],"
assert source.count(property_text) == 1, 'Campfire configuration changed; review rollback fixture'
out = root / 'dev/test/out'
out.mkdir(exist_ok=True)
(out / 'presentation-rollback.html').write_text(source.replace(property_text, ''), encoding='utf-8')
print('Prepared out/presentation-rollback.html; run presentation_restore with the targeted runner.')
