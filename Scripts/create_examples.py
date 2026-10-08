#!/usr/bin/env python3
"""Synthetic, date-stable fixtures; never seed production storage automatically."""
from pathlib import Path
import csv, json, uuid
ROOT = Path(__file__).resolve().parents[1]
examples = ROOT/'Examples'
records=[]
for day, quality, tags in [(5,3,['stress']), (6,4,['exercise']), (7,5,['exercise'])]:
    records.append(dict(id=str(uuid.uuid5(uuid.NAMESPACE_URL,f'sleepledger-example-{day}')).upper(),
        start=f'2026-10-{day-1:02d}T23:00:00Z',end=f'2026-10-{day:02d}T07:00:00Z',origin='manual',
        isNap=False,quality=quality,tags=tags,source='SleepLedger',externalID=None,edited=False,stages=[],timeZoneID='UTC'))
envelope={'version':1,'sessions':records,'steps':[{'day':'2026-10-06T00:00:00Z','count':8200,'source':'Synthetic iPhone'}],
          'settings':{'goalHours':8,'reminderEnabled':False,'reminderHour':22,'reminderMinute':30,'appearance':'system'}}
(examples/'backup.json').write_text(json.dumps(envelope,indent=2)+'\n')
header=['id','start','end','origin','isNap','quality','tags_json','source','externalID','edited','timeZoneID','stages_json']
with (examples/'sessions.csv').open('w',newline='') as f:
    w=csv.writer(f);w.writerow(header)
    for r in records:
        w.writerow([r['id'],r['start'],r['end'],r['origin'],'false',r['quality'],json.dumps(r['tags']),r['source'],'','false',r['timeZoneID'],'[]'])
health_header=['kind','start','end','source','value']
with (examples/'health-samples.csv').open('w',newline='') as f:
    w=csv.writer(f);w.writerow(health_header)
    w.writerows([
        ['sleep','2026-10-07T23:00:00Z','2026-10-08T07:00:00Z','Synthetic Watch','inBed'],
        ['sleep','2026-10-07T23:00:00Z','2026-10-08T07:00:00Z','Synthetic Watch','asleep'],
        ['sleep','2026-10-07T23:00:00Z','2026-10-08T02:00:00Z','Synthetic Watch','core'],
        ['sleep','2026-10-08T02:00:00Z','2026-10-08T03:30:00Z','Synthetic Watch','deep'],
        ['sleep','2026-10-08T03:30:00Z','2026-10-08T04:00:00Z','Synthetic Watch','awake'],
        ['sleep','2026-10-08T04:00:00Z','2026-10-08T05:30:00Z','Synthetic Watch','rem'],
        ['sleep','2026-10-08T05:30:00Z','2026-10-08T07:00:00Z','Synthetic Watch','core'],
    ])
with (examples/'overlap-health.csv').open('w',newline='') as f:
    w=csv.writer(f);w.writerow(health_header);w.writerow(['sleep','2026-10-06T22:30:00Z','2026-10-07T07:30:00Z','Synthetic Watch','asleep'])
with (examples/'invalid-mixed-sources.csv').open('w',newline='') as f:
    w=csv.writer(f);w.writerow(health_header)
    for source in ['Watch A','Watch B']: w.writerow(['sleep','2026-10-07T23:00:00Z','2026-10-08T07:00:00Z',source,'core'])
print('Created 5 synthetic example files')
