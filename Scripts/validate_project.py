#!/usr/bin/env python3
"""Structural validation only. This is NOT a Swift compiler or a substitute for swift test."""
import csv, json, plistlib, re, xml.etree.ElementTree as ET
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
pbx=(ROOT/'SleepLedger.xcodeproj/project.pbxproj').read_text()
definitions=re.findall(r'^([A-F0-9]{24}) = ',pbx,re.M)
assert len(definitions)==len(set(definitions)), 'Duplicate PBX object ID'
references=set(re.findall(r'\b[A-F0-9]{24}\b',pbx))
assert references==set(definitions), 'Dangling PBX object reference'
paths=re.findall(r'path = "([^"]+\.swift)"',pbx)
expected=sorted(str(p.relative_to(ROOT)) for parent in ['App','Core/Sources/SleepCore'] for p in (ROOT/parent).glob('*.swift'))
assert sorted(paths)==expected, 'Missing or duplicated app/core source reference'
assert all((ROOT/p).exists() for p in paths)
assert 'OptionalWidget/SleepLedgerWidget.swift' not in paths, 'Widget @main must be in a separate extension'
assert 'CODE_SIGN_ENTITLEMENTS' not in pbx and 'HealthKit.framework' not in pbx
info=plistlib.loads((ROOT/'App/Info.plist').read_bytes())
assert info['CFBundleURLTypes'][0]['CFBundleURLSchemes']==['sleepledger']
assert not any('Health' in k for k in info), 'Baseline must not request Health access'
assert not list((ROOT/'App').glob('*.entitlements'))
scheme=ET.parse(ROOT/'SleepLedger.xcodeproj/xcshareddata/xcschemes/SleepLedger.xcscheme')
assert all(x.attrib['BlueprintIdentifier'] in definitions for x in scheme.findall('.//BuildableReference'))
backup=json.loads((ROOT/'Examples/backup.json').read_text())
assert backup['version']==1 and len(backup['sessions'])==3 and len(backup['steps'])==1
with (ROOT/'Examples/sessions.csv').open(newline='') as f:
    sessions=list(csv.DictReader(f))
assert len(sessions)==len(backup['sessions'])
for row,r in zip(sessions,backup['sessions']):
    assert row['id']==r['id'] and json.loads(row['tags_json'])==r['tags']
    assert json.loads(row['stages_json'])==r['stages']
for filename in ['health-samples.csv','overlap-health.csv','invalid-mixed-sources.csv']:
    with (ROOT/'Examples'/filename).open(newline='') as f:
        rows=list(csv.reader(f))
    assert rows[0]==['kind','start','end','source','value']
    assert all(len(row)==5 for row in rows)
for p in ROOT.rglob('*.md'):
    for relative in re.findall(r'\]\(([^)]+)\)',p.read_text()):
        if not re.match(r'(https?://|#)',relative): assert (p.parent/relative.split('#')[0]).exists(), (p,relative)
print(f'PASS: {len(paths)} app/core Swift source references; {len(definitions)} PBX objects; plist/scheme; no baseline entitlements; 5 fixtures; local documentation links.')
print('Not checked here: Swift type checking, XCTest execution, iOS build/signing, rendered UI, actual Shortcuts/Health behavior.')
