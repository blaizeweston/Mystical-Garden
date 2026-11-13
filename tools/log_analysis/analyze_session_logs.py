"""Read Mystical Garden diagnostic folders/ZIPs without modifying or extracting originals."""
from __future__ import annotations
import argparse, bisect, collections, csv, datetime as dt, hashlib, html, io, json, math, re, statistics, sys, zipfile
from pathlib import Path

MAX_FILE=32*1024*1024
MAX_TOTAL=512*1024*1024
UTC=dt.timezone.utc
def number(value,default=None):
 if isinstance(value,(int,float)) and not isinstance(value,bool) and math.isfinite(value):return value
 return default
def integer(value,default=None):
 n=number(value)
 return int(n) if n is not None and n==int(n) else default
def vitals_values(state):
 values={key:value for key in ('hp','damage_seq','max_hp','lost_health')
         if (value:=number(state.get(key))) is not None}
 if isinstance(state.get('fallen'),bool):values['fallen']=state['fallen']
 return values

def timestamp(value):
 try:
  result=dt.datetime.fromisoformat(str(value).replace('Z','+00:00'))
  return result.astimezone(UTC) if result.tzinfo else None
 except (ValueError,TypeError):return None
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False)
def percentile(values,q):
 values=sorted(values)
 if not values:return None
 at=(len(values)-1)*q;lo=math.floor(at);hi=math.ceil(at)
 return values[lo]+(values[hi]-values[lo])*(at-lo)
def stats(values):
 values=[n for v in values if (n:=number(v)) is not None]
 return {'samples':len(values),'min':min(values) if values else None,'mean':statistics.fmean(values) if values else None,'median':percentile(values,.5),'p95':percentile(values,.95),'max':max(values) if values else None}
def source_ref(row):return {'session':row['session'],'seq':row['seq'],'utc':row.get('utc'),'source':row['_source'],'line':row['_line']}
def link_key(row):
 c=row.get('context',{})
 return (c.get('host_session'),c.get('world_session')) if c.get('role') in ['Host','Guest'] and c.get('host_session') and c.get('world_session') else None

class Reader:
 def __init__(self):
  self.rows={};self.metadata=collections.defaultdict(list);self.sources=[];self.duplicates=0;self.conflicts=[];self.warnings=[];self.raw_rows=0;self.total_bytes=0
 def feed(self,name,data):
  if len(data)>MAX_FILE:self.warnings.append({'source':name,'issue':'file exceeds 32 MiB limit'});return
  self.total_bytes+=len(data)
  if self.total_bytes>MAX_TOTAL:raise ValueError('Input exceeds 512 MiB safety limit; split it into smaller runs.')
  self.sources.append({'source':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
  try:text=data.decode('utf-8-sig')
  except UnicodeDecodeError:self.warnings.append({'source':name,'issue':'invalid UTF-8; replacement characters used'});text=data.decode('utf-8-sig',errors='replace')
  if name.replace('\\','/').lower().endswith('/session.json') or name.lower()=='session.json':
   try:
    meta=json.loads(text)
    if not isinstance(meta,dict) or not isinstance(meta.get('session'),str):raise ValueError('missing session identity')
    self.metadata[meta['session']].append({'metadata':meta,'source':name})
   except (ValueError,TypeError) as e:self.warnings.append({'source':name,'issue':'invalid session metadata: '+str(e)})
   return
  for index,line in enumerate(text.splitlines(),1):
   if not line.strip():continue
   try:
    if len(line)>1024*1024:raise ValueError('oversized line')
    row=json.loads(line)
    if not isinstance(row,dict) or not isinstance(row.get('session'),str) or integer(row.get('seq'),0)<=0:raise ValueError('missing session/positive sequence')
    if not isinstance(row.get('category'),str) or not isinstance(row.get('event'),str):raise ValueError('invalid category/event')
    if not isinstance(row.get('data',{}),dict) or not isinstance(row.get('context',{}),dict):raise ValueError('invalid data/context')
    if any(not isinstance(row.get('context',{}).get(k,''),str) for k in ['role','host_session','world_session']):raise ValueError('invalid context identifiers')
    event=row.get('event');payload=row.get('data',{})
    for field in (['players','transport'] if event=='sample' else ['states'] if event=='vitals_received' else ['changes'] if event=='player_changed' else []):
     value=payload.get(field,{})
     if not isinstance(value,dict) or any(not isinstance(v,dict) for v in value.values()):raise ValueError('invalid nested '+str(event)+'.'+field)
    if event=='floor_generation' and any(integer(payload.get(k)) is None for k in ['seed','biome','depth']):raise ValueError('invalid floor generation fields')
    if event=='encounter_clear' and any(integer(payload.get(k)) is None for k in ['floor','biome','cycle','kills']):raise ValueError('invalid encounter clear fields')
    if row.get('schema')!=1:self.warnings.append({'source':name,'line':index,'issue':'unknown event schema; compatible fields only'})
   except (ValueError,TypeError) as e:self.warnings.append({'source':name,'line':index,'issue':'malformed/truncated event: '+str(e)});continue
   self.raw_rows+=1;row['seq']=int(row['seq']);key=(row['session'],row['seq'])
   if key in self.rows:
    old={k:v for k,v in self.rows[key].items() if k not in ['_source','_line']}
    if canonical(old)==canonical(row):self.duplicates+=1
    else:self.conflicts.append({'session':key[0],'seq':key[1],'kept_source':self.rows[key]['_source'],'other_source':name,'line':index})
    continue
   row['_source']=name;row['_line']=index;self.rows[key]=row
 def load(self,paths):
  files=set()
  for argument in paths:
   path=Path(argument).resolve()
   if not path.exists():raise ValueError('Input not found: '+str(path))
   files.update(p for p in path.rglob('*') if p.is_file() and (p.suffix.lower() in ['.jsonl','.zip'] or p.name=='session.json')) if path.is_dir() else files.add(path)
  if len(files)>10000:raise ValueError('Too many input files')
  for path in sorted(files):
   if path.suffix.lower()=='.zip':
    with zipfile.ZipFile(path) as archive:
     members=archive.infolist()
     if len(members)>10000:raise ValueError('Archive has too many members: '+str(path))
     for member in members:
      if member.is_dir() or not (member.filename.lower().endswith('.jsonl') or member.filename.lower().split('/')[-1]=='session.json'):continue
      if member.file_size>MAX_FILE:self.warnings.append({'source':str(path)+'!'+member.filename,'issue':'member exceeds size limit'});continue
      self.feed(str(path)+'!'+member.filename,archive.read(member))
   elif path.suffix.lower()=='.jsonl' or path.name=='session.json':
    if path.stat().st_size>MAX_FILE:self.warnings.append({'source':str(path),'issue':'file exceeds size limit'});continue
    self.feed(str(path),path.read_bytes())
  return self

def session_summary(sid,rows,reader):
 versions=reader.metadata.get(sid,[])
 chosen=max(versions,key=lambda m:(integer(m['metadata'].get('last_seq'),0),str(m['metadata'].get('last_utc','')))) if versions else {'metadata':{},'source':None}
 meta=chosen['metadata'];roles=collections.Counter(r.get('context',{}).get('role','unknown') for r in rows)
 segments=[]
 for row in rows:
  if not segments or row['seq']!=segments[-1]['last_seq']+1:
   segments.append({'first_seq':row['seq'],'last_seq':row['seq'],'first_utc':row.get('utc'),'last_utc':row.get('utc'),'first_elapsed_ms':row.get('elapsed_ms'),'last_elapsed_ms':row.get('elapsed_ms')})
  else:segments[-1].update(last_seq=row['seq'],last_utc=row.get('utc'),last_elapsed_ms=row.get('elapsed_ms'))
 gaps=[{'from_seq':a['last_seq']+1,'to_seq':b['first_seq']-1} for a,b in zip(segments,segments[1:])]
 head=max(0,rows[0]['seq']-1) if rows else 0;tail=max(0,integer(meta.get('last_seq'),rows[-1]['seq'])-rows[-1]['seq']) if rows else 0
 clean=meta.get('clean_exit');ended=any(r.get('event')=='ended' for r in rows)
 exit_status='normal shutdown recorded' if clean is True or ended else 'open/unclean at export; crash not established'
 samples=[r for r in rows if r.get('category')=='network' and r.get('event')=='sample']
 roles_active={k for k in roles if k in ['Host','Guest']}
 label='Metadata only / no retained events' if not rows else 'Host' if roles_active=={'Host'} else 'Guest' if roles_active=={'Guest'} else 'Host + Guest roles' if roles_active else 'Join attempts / solo only'
 return {'session':sid,'label':label,'roles':dict(roles),'peer_ids':sorted({str(r['context'].get('peer')) for r in rows if r.get('context',{}).get('role')=='Guest'}),'rows':len(rows),'first_seq':rows[0]['seq'] if rows else None,'last_seq':rows[-1]['seq'] if rows else None,'first_utc':rows[0].get('utc') if rows else None,'last_utc':rows[-1].get('utc') if rows else None,'metadata':meta,'metadata_source':chosen['source'],'metadata_versions':len(versions),'metadata_snapshot_sequences':sorted({integer(v['metadata'].get('last_seq'),0) for v in versions}),'segments':segments,'missing_head_events':head,'missing_tail_events':tail,'internal_gaps':gaps,'exit_status':exit_status,'events':dict(collections.Counter(r.get('category','')+'/'+r.get('event','') for r in rows)),'fps':stats(r['data'].get('fps') for r in samples),'errors':sum(r.get('level')=='error' for r in rows),'warnings':sum(r.get('level')=='warning' for r in rows)}

def analyze(reader):
 by_session=collections.defaultdict(list)
 for row in reader.rows.values():by_session[row['session']].append(row)
 for sid in reader.metadata:
  if sid not in by_session:by_session[sid]=[];reader.warnings.append({'source':reader.metadata[sid][0]['source'],'issue':'metadata has no retained events'})
 for rows in by_session.values():rows.sort(key=lambda r:r['seq'])
 summaries={sid:session_summary(sid,rows,reader) for sid,rows in sorted(by_session.items())}
 groups=collections.defaultdict(lambda:{'hosts':set(),'guests':set(),'host_observed_peers':set(),'guest_viewpoints':set()})
 network_series=[];generation=[];clears=[];damage=[];healing=[];connections=[];issues=[];grafts=[];upgrades=[];research=[];markers=[];pending=[];unmatched=[];transactions=[];life=[];party=collections.defaultdict(lambda:{'frames':collections.Counter(),'damage_events':0,'damage_recorded':0,'downs':0,'revivals':0,'garden_restorations':0});health_guest=[];host_health=collections.defaultdict(list)
 health_fields=['hp','damage_seq','max_hp','lost_health','fallen']
 for sid,rows in by_session.items():
  actions={};tx={};active_tx=None;state_by_actor={}
  for row in rows:
   category=row.get('category');event=row.get('event');data=row.get('data',{});c=row.get('context',{});group=link_key(row);ref=source_ref(row)
   if group:
    g=groups[group]
    if c.get('role')=='Host':g['hosts'].add(sid)
    elif c.get('role')=='Guest':g['guests'].add(sid);g['guest_viewpoints'].add(str(c.get('peer')))
   if row.get('level') in ['error','warning']:issues.append({'level':row['level'],'category':category,'event':event,'data':data,'context':c,'ref':ref})
   if category=='network' and event not in ['sample','vitals_received','stale_snapshot']:connections.append({'event':event,'data':data,'context':c,'ref':ref})
   if c.get('role')=='Host':
    actor=str(data.get('actor'));full_state=data.get('state',{})
    if isinstance(full_state,dict) and integer(full_state.get('frame')) is not None:party[actor]['frames'][int(full_state['frame'])]+=1
    if category=='state' and event=='player_changed':
     changes=data.get('changes',{});fallen=changes.get('fallen',{});lost=changes.get('lost_health',{});kind=None
     if fallen.get('before') is False and fallen.get('after') is True:kind='downs'
     elif fallen.get('before') is True and fallen.get('after') is False:
      before=number(lost.get('before'));after=number(lost.get('after'))
      if before is not None and after is not None and after-before==2*number(data.get('hp_per_point'),1):kind='revivals'
      elif changes.get('wild',{}).get('after') is False or after==0:kind='garden_restorations'
      else:kind='unclassified_fallen_clear'
     if kind:
      party[actor][kind]=party[actor].get(kind,0)+1;life.append({'actor':actor,'kind':kind,'floor':c.get('floor'),'changes':changes,'ref':ref})
    if category=='combat' and event=='damage_applied':
     party[actor]['damage_events']+=1
     party[actor]['damage_recorded']+=number(data.get('applied_hp'),number(data.get('amount'),0))
   if category=='interaction' and event=='action_begin':actions[row['seq']]=row
   elif category=='interaction' and event=='action_end':
    request=integer(data.get('request_seq'))
    if request not in actions:unmatched.append({'type':'action_end_without_retained_begin','ref':ref,'request_seq':request,'action':data.get('action')})
    else:actions.pop(request)
   if category=='save' and event=='transaction_begin':tx[row['seq']]=row;active_tx=row['seq']
   elif category=='save' and event in ['transaction_committed','transaction_rollback']:
    request=integer(data.get('transaction_seq'));begin=tx.pop(request,None)
    transactions.append({'result':event,'begin':source_ref(begin) if begin else None,'end':ref,'transaction_seq':request,'error':data.get('error')})
    if active_tx==request:active_tx=None
   if event=='user_issue':markers.append({'note':data.get('note',''),'ref':ref,'context':c})
   if category=='network' and event=='sample':
    if group and c.get('role')=='Host':
     groups[group]['host_observed_peers'].update(str(a) for a in data.get('players',{}))
     for actor,state in data.get('players',{}).items():
      revision=integer(state.get('vitals_revision'));hp=number(state.get('hp'))
      if revision is not None and hp is not None:host_health[(*group,str(actor),revision)].append({'values':vitals_values(state),'ref':ref})
    for remote,transport in data.get('transport',{}).items():
     network_series.append({'session':sid,'utc':row.get('utc'),'elapsed_ms':row.get('elapsed_ms'),'seq':row['seq'],'role':c.get('role'),'peer':c.get('peer'),'remote_peer':str(remote),'host_session':c.get('host_session'),'world_session':c.get('world_session'),'floor':c.get('floor'),'rtt_ms':number(transport.get('rtt_ms')),'reliable_loss_estimate_percent':number(transport.get('enet_reliable_loss_percent_estimate')),'loss_epoch_ms':transport.get('loss_epoch_ms'),'received_sequence':data.get('received_sequence'),'sent_sequence':data.get('sent_sequence'),'snapshot_gaps':data.get('snapshot_gaps'),'rejected_snapshots':data.get('rejected_snapshots'),'fps':data.get('fps')})
   if category=='network' and event=='vitals_received' and group:
    for actor,state in data.get('states',{}).items():
     revision=integer(state.get('revision'));hp=number(state.get('hp'))
     if revision is not None and hp is not None:health_guest.append({'key':(*group,str(actor),revision),'values':vitals_values(state),'ref':ref})
   if category=='gameplay' and event=='floor_generation':generation.append({'session':sid,'role':c.get('role'),'seed':data.get('seed'),'biome':data.get('biome'),'depth':data.get('depth'),'milliseconds':data.get('milliseconds'),'context':c,'ref':ref})
   if category=='gameplay' and event=='encounter_clear':clears.append({'session':sid,'role':c.get('role'),'floor':data.get('floor'),'biome':data.get('biome'),'cycle':data.get('cycle'),'kills':data.get('kills'),'context':c,'ref':ref})
   if category=='combat' and event=='damage_applied':damage.append({'session':sid,'actor':str(data.get('actor')),'amount':data.get('amount'),'applied_hp':data.get('applied_hp'),'hp_after':data.get('hp'),'damage_seq':data.get('damage_seq'),'vitals_revision':data.get('vitals_revision'),'hp_per_point':data.get('hp_per_point'),'floor':c.get('floor'),'transaction_seq':active_tx,'ref':ref})
   if category=='combat' and event=='healing_applied':
    healing.append({'session':sid,'role':c.get('role'),'floor':c.get('floor'),'party_slot':data.get('party_slot'),'source':data.get('source'),'rolled_hp':data.get('rolled_hp'),'applied_hp':data.get('applied_hp'),'hp_after':data.get('hp'),'max_hp':data.get('max_hp'),'ref':ref})
   if category=='grafting' and event=='roll':grafts.append({'data':data,'context':c,'ref':ref})
   if category=='gameplay' and event=='upgrade':
    begin=actions[max(actions)] if actions else None
    upgrades.append({'data':data,'actor':str(begin['data'].get('actor')) if begin else None,'interaction_ref':source_ref(begin) if begin else None,'context':c,'ref':ref})
   if category=='progression' and event=='garden_changed':research.append({'session':sid,'seq':row['seq'],'utc':row.get('utc'),'role':c.get('role'),'floor':c.get('floor'),'host_session':c.get('host_session'),'world_session':c.get('world_session'),**{k:data.get(k) for k in ['source','active','knowledge','work_seconds','unlocked_count']}})
  for begin in actions.values():pending.append({'type':'action_begin_without_retained_end','ref':source_ref(begin),'actor':begin['data'].get('actor'),'action':begin['data'].get('action')})
  for begin in tx.values():pending.append({'type':'transaction_begin_without_retained_outcome','ref':source_ref(begin)})
 # Compare exact host/world/actor/vitals-revision keys; never infer lag from unsynchronized clocks.
 health={'fields_compared':health_fields[:2],'compared':0,'matched':0,'mismatches':[],'unavailable_host_revision':0,'ambiguous_host_revision':0,'duplicate_guest_revision':0};seen=set()
 for guest in health_guest:
  key=(guest['ref']['session'],*guest['key'])
  if key in seen:health['duplicate_guest_revision']+=1;continue
  seen.add(key);authority=host_health.get(guest['key'],[])
  if not authority:health['unavailable_host_revision']+=1;continue
  signatures={tuple(r['values'].get(field) for field in health_fields) for r in authority}
  if len(signatures)!=1:health['ambiguous_host_revision']+=1;continue
  expected=authority[0]['values'];actual=guest['values'];health['compared']+=1
  shared=[field for field in health_fields if field in actual and field in expected]
  for field in shared:
   if field not in health['fields_compared']:health['fields_compared'].append(field)
  differences={field:{'guest':actual.get(field),'host':expected.get(field)}
               for field in dict.fromkeys(health_fields[:2]+shared) if actual.get(field)!=expected.get(field)}
  if not differences:health['matched']+=1
  else:health['mismatches'].append({'key':guest['key'],'guest_hp':actual.get('hp'),'host_hp':expected.get('hp'),'guest_damage_seq':actual.get('damage_seq'),'host_damage_seq':expected.get('damage_seq'),'differences':differences,'guest_ref':guest['ref'],'host_ref':authority[0]['ref']})
 # Assign a generated seed to a floor only when the logged contexts identify it uniquely.
 seed_floors=collections.defaultdict(set)
 for row in reader.rows.values():
  c=row.get('context',{})
  if c.get('map_seed') and c.get('floor') is not None:seed_floors[(row['session'],c['map_seed'])].add(c['floor'])
 for record in generation:
  candidates=seed_floors.get((record['session'],record['seed']),set());record['floor']=next(iter(candidates)) if len(candidates)==1 else None
 for record in clears:
  matching=[g for g in generation if g['session']==record['session'] and g['seed'] and g['floor']==record['floor'] and g['ref']['seq']<record['ref']['seq']]
  if matching:
   start=max(matching,key=lambda g:g['ref']['seq']);a=timestamp(start['ref']['utc']);b=timestamp(record['ref']['utc']);record['generation_to_clear_seconds']=(b-a).total_seconds() if a and b else None;record['generation_ref']=start['ref']
 net_groups=collections.defaultdict(list)
 for row in network_series:net_groups[(row['session'],row['remote_peer'])].append(row)
 net_summary=[]
 for (sid,remote),rows in net_groups.items():
  counters=[integer(r.get('snapshot_gaps')) for r in rows];counters=[v for v in counters if v is not None]
  resets=sum(b<a for a,b in zip(counters,counters[1:]));increase=sum(max(0,b-a) for a,b in zip(counters,counters[1:]))
  net_summary.append({'session':sid,'role':rows[0]['role'],'peer':rows[0]['peer'],'remote_peer':remote,'rtt_ms':stats(r['rtt_ms'] for r in rows),'reliable_loss_estimate_percent':stats(r['reliable_loss_estimate_percent'] for r in rows),'fps':stats(r['fps'] for r in rows),'first_utc':rows[0]['utc'],'last_utc':rows[-1]['utc'],'first_snapshot_gap_counter':counters[0] if counters else None,'last_snapshot_gap_counter':counters[-1] if counters else None,'observed_gap_counter_increase':increase if rows[0]['role']=='Guest' else None,'counter_resets':resets})
 issue_groups=collections.defaultdict(list)
 for issue in issues:
  d=issue['data'];key=(issue['level'],issue['event'],*[str(d.get(k)) if d.get(k) is not None else None for k in ['source','function','line','code','message','reason']])
  issue_groups[key].append(issue)
 grouped_issues=[{'count':len(values),'level':key[0],'event':key[1],'source':key[2],'function':key[3],'line':key[4],'code':key[5],'message':key[6] or key[7] or '', 'sessions':sorted({i['ref']['session'] for i in values}),'first_ref':values[0]['ref'],'last_ref':values[-1]['ref'],'stack_example':values[0]['data'].get('stack',[])} for key,values in issue_groups.items()]
 correlations=[]
 for key,group in groups.items():
  missing=group['host_observed_peers']-group['guest_viewpoints']-{'1'}
  correlations.append({'host_session':key[0],'world_session':key[1],**{k:sorted(v) for k,v in group.items()},'guest_peers_missing_viewpoint':sorted(missing)})
 return {'schema':1,'inventory':{'input_files':len(reader.sources),'raw_events':reader.raw_rows,'unique_events':len(reader.rows),'duplicate_events_removed':reader.duplicates,'conflicting_duplicates':reader.conflicts,'input_bytes':reader.total_bytes,'sources':reader.sources,'parse_warnings':reader.warnings},'sessions':summaries,'correlations':correlations,'network':net_summary,'network_series':network_series,'issues':grouped_issues,'connections':connections,'health_comparison':health,'generation':generation,'clears':clears,'damage':damage,'healing':healing,'transactions':transactions,'unmatched_actions':pending,'orphan_ends':unmatched,'grafts':grafts,'upgrades':upgrades,'markers':markers,'research':research,'party':dict(party),'life_events':life}

def write_csv(path,rows,fields):
 with path.open('w',encoding='utf-8-sig',newline='') as file:
  writer=csv.DictWriter(file,fieldnames=fields,extrasaction='ignore');writer.writeheader()
  for source in rows:
   row={k:canonical(source.get(k)) if isinstance(source.get(k),(dict,list,tuple)) else source.get(k) for k in fields}
   # Prevent spreadsheet formula interpretation of free text from logs.
   for k,v in row.items():
    if isinstance(v,str) and v.startswith(('=','+','-','@','\t','\r')):row[k]="'"+v
   writer.writerow(row)

def local_time(value,offset):
 stamp=timestamp(value)
 return stamp.astimezone(offset).strftime('%Y-%m-%d %H:%M:%S %z') if stamp else 'unknown'
def fmt(value):return '—' if value is None else f'{value:,.2f}' if isinstance(value,float) else str(value)
def reader_metadata_snapshots(report):
 return {sid:s.get('metadata_snapshot_sequences',[]) for sid,s in report['sessions'].items()}

def markdown(report,offset):
 inv=report['inventory'];sessions=report['sessions'];lines=['# Gameplay log analysis','','## Findings','',f"Read **{inv['raw_events']:,} events**, retained **{inv['unique_events']:,} unique events**, and removed **{inv['duplicate_events_removed']:,} duplicate copies** across {inv['input_files']} input files. Original inputs were not modified.",'']
 if inv['conflicting_duplicates']:lines.append(f"- {len(inv['conflicting_duplicates'])} conflicting duplicate IDs require manual review; the first copy was retained.")
 fingerprints={s['metadata'].get('build',{}).get('source_fingerprint') for s in sessions.values()};protocols={s['metadata'].get('protocol') for s in sessions.values()}
 lines.append(f"- Captured builds: {len(fingerprints-{None})} distinct runtime fingerprints; protocols: {', '.join(map(str,sorted(p for p in protocols if p is not None)))}. Filenames are not used to infer build identity.")
 missing=set()
 for group in report['correlations']:missing.update(group['guest_peers_missing_viewpoint'])
 snapshots=[]
 for sid,versions in reader_metadata_snapshots(report).items():
  if len(versions)>1:snapshots.append('`'+sid+'` ('+', '.join(map(str,versions))+')')
 if snapshots:lines.append('- Early/later exports of the same application session were merged: '+ '; '.join(snapshots)+'. These exports are not separate connected players.')
 if missing:lines.append('- Host samples show guest peer(s) without their own connected-client report: **'+', '.join(sorted(missing))+'**. Their health is visible from the host, but their local experience cannot be fully evaluated.')
 errors=sum(s['errors'] for s in sessions.values());warnings=sum(s['warnings'] for s in sessions.values())
 lines.append(f'- Recorded error-level events: **{errors}**; warning-level events: **{warnings}**. Missing/rotated history prevents treating this as proof that the full play session was error-free.')
 timeouts=[c for c in report['connections'] if c['event']=='connection_rejected' and 'timed out' in str(c['data'].get('reason','')).lower()]
 if timeouts:lines.append(f'- **{len(timeouts)} earlier join timeouts** are recorded. A timeout identifies an incomplete connection; these logs alone do not identify a specific router/firewall cause.')
 health=report['health_comparison']
 lines.append(f"- Exact host/world/actor/revision checks ({', '.join(health['fields_compared'])}): **{health['matched']}/{health['compared']} matched**, **{len(health['mismatches'])} mismatches**, {health['unavailable_host_revision']} guest updates without a retained matching host sample, {health['ambiguous_host_revision']} ambiguous host revisions. Unmatched revisions are not evidence of packet loss.")
 if report['healing']:
  applied=sum(number(e['applied_hp'],0) for e in report['healing'])
  rolled=sum(number(e['rolled_hp'],0) for e in report['healing'])
  lines.append(f'- Detailed healing records show **{applied} HP restored** from **{rolled} HP rolled** across {len(report["healing"])} retained events.')
 host_clears=[c for c in report['clears'] if c['role']=='Host']
 downs=sum(v['downs'] for v in report['party'].values());revivals=sum(v['revivals'] for v in report['party'].values())
 if downs:lines.append(f'- Retained host state shows **{downs} downs** and **{revivals} in-Wilds revivals**; Garden restorations are counted separately below. These are partial-window totals.')
 if host_clears:lines.append(f"- Host-retained gameplay includes **{len(host_clears)} encounter clears**, floors {min(c['floor'] for c in host_clears)}–{max(c['floor'] for c in host_clears)}, with **{sum(c.get('kills',0) for c in host_clears)} recorded kills**. This is the retained portion, not a full-run total.")
 rollbacks=[r for r in report['transactions'] if r['result']=='transaction_rollback']
 lines.append(f"- Save outcomes retained: {sum(t['result']=='transaction_committed' for t in report['transactions'])} commits and {len(rollbacks)} rollbacks. {len(report['unmatched_actions'])} action/transaction starts lack a retained ending; {len(report['orphan_ends'])} action endings lack their retained start. Rotation/export boundaries must be checked before diagnosing interrupted handlers.")
 if inv['parse_warnings']:
  lines+=['','## Input quality warnings','']
  for warning in inv['parse_warnings'][:20]:lines.append('- '+str(warning['issue'])+' — '+str(warning.get('source',''))+' (line '+str(warning.get('line','—'))+')')
 lines+=['','## Session coverage','','Times below use the requested fixed UTC offset. Event ordering is local sequence order; clocks on different computers may differ.','','| Session | Observed role | Unique events | Retained sequence | First → last retained time | Shutdown evidence |','|---|---|---:|---|---|---|']
 for sid,s in sessions.items():lines.append(f"| `{sid}` | {s['label']} | {s['rows']:,} | {s['first_seq']}–{s['last_seq']} | {local_time(s['first_utc'],offset)} → {local_time(s['last_utc'],offset)} | {s['exit_status']} |")
 for sid,s in sessions.items():
  if s['missing_head_events'] or s['internal_gaps'] or s['missing_tail_events']:lines.append(f"\n`{sid}`: {s['missing_head_events']:,} missing leading events; internal gaps: {canonical(s['internal_gaps'])}; {s['missing_tail_events']:,} metadata-indicated trailing events unavailable.")
 lines+=['','## Connection warnings and engine errors','','| Severity | Event | Count | Message | First evidence |','|---|---|---:|---|---|']
 for issue in report['issues']:
  ref=issue['first_ref'];message=(issue['message'] or issue.get('code') or '').replace('|','\\|').replace('\n',' ')
  lines.append(f"| {issue['level']} | {issue['event']} | {issue['count']} | {message} | `{ref['session']}:{ref['seq']}` |")
 if not report['issues']:lines.append('| — | No retained warnings/errors | 0 | Partial logs do not establish a crash-free full session. | — |')
 lines+=['','## Network measurements','','These are periodic samples of ENet’s smoothed reliable-packet estimates, not per-packet measurements or a total-loss percentage for the run. Snapshot gaps refer to the application sequence counter.','','| Viewpoint → remote peer | Samples | RTT median / p95 / max (ms) | Reliable-loss estimate mean / max (%) | Observed snapshot-gap counter increase | FPS median / min |','|---|---:|---|---|---:|---|']
 for n in report['network']:
  r=n['rtt_ms'];loss=n['reliable_loss_estimate_percent'];fps=n['fps']
  lines.append(f"| `{n['session']}` ({n['role']}) → {n['remote_peer']} | {r['samples']} | {fmt(r['median'])} / {fmt(r['p95'])} / {fmt(r['max'])} | {fmt(loss['mean'])} / {fmt(loss['max'])} | {fmt(n['observed_gap_counter_increase'])} | {fmt(fps['median'])} / {fmt(fps['min'])} |")
 lines+=['','## Retained host combat and generation','','Generation-to-clear time includes combat, looting and any delay before the clear was recorded. It is not a measure of pure attack DPS. Garden/reset generation (seed 0) is excluded from the generation-time statistics.','','| Floor | Biome | Cycle | Recorded kills | Generation → clear (s) | Clear time | Evidence |','|---:|---:|---:|---:|---:|---|---|']
 for c in host_clears:lines.append(f"| {c['floor']} | {c['biome']} | {c['cycle']} | {c['kills']} | {fmt(c.get('generation_to_clear_seconds'))} | {local_time(c['ref']['utc'],offset)} | `{c['ref']['session']}:{c['ref']['seq']}` |")
 for sid,s in sessions.items():
  values=[g['milliseconds'] for g in report['generation'] if g['session']==sid and g['seed'] and number(g['milliseconds']) is not None];st=stats(values)
  if values:lines.append(f"\n`{sid}` wilderness generation: n={st['samples']}, median {fmt(st['median'])} ms, p95 {fmt(st['p95'])} ms, max {fmt(st['max'])} ms. A generation duration is not proof of a visible hitch or network latency.")
 lines+=['','## Gameplay interactions','','Counts are log events, not necessarily successful casts or completed research. Client requests and host execution are kept separate.','','| Session | Skill requests | Damage events | Incoming damage recorded | Upgrade records | Graft rolls |','|---|---:|---:|---:|---:|---:|']
 for sid,s in sessions.items():
  d=[v for v in report['damage'] if v['session']==sid]
  lines.append(f"| `{sid}` | {s['events'].get('combat/skill_requested',0)} | {len(d)} | {sum(number(v['amount'],0) for v in d)} | {sum(u['ref']['session']==sid for u in report['upgrades'])} | {sum(g['ref']['session']==sid for g in report['grafts'])} |")
 lines+=['','## Party survival in the retained host window','','These are observed transitions, not full-session totals. Revivals require a fallen→alive transition with the logged maximum-health sacrifice for that build. Garden resets are counted separately.','','| Actor | Classes observed | Incoming damage events / amount | Downs | In-Wilds revivals | Garden restorations |','|---|---|---|---:|---:|---:|']
 for actor,state in report['party'].items():
  classes=', '.join(report.get('catalog',{}).get('classes',{}).get(str(k),str(k)) for k in state['frames'])
  lines.append(f"| {'Host' if actor=='1' else 'Guest'} `{actor}` | {classes} | {state['damage_events']} / {state['damage_recorded']} | {state['downs']} | {state['revivals']} | {state['garden_restorations']} |")
 lines+=['','Differences in down counts may reflect build, player choices, healing or accumulated revival penalties. This partial sample does not establish that a class is overpowered or underpowered.','','## Upgrades and research','', '| Upgrade | Actor | Floor | Cost | Evidence |','|---|---|---:|---:|---|']
 for upgrade in report['upgrades']:
  d=upgrade['data'];ref=upgrade['ref'];lines.append(f"| {d.get('id','')} | {upgrade.get('actor') or 'unknown'} | {d.get('floor','')} | {d.get('cost','')} | `{ref['session']}:{ref['seq']}` |")
 for sid in report['sessions']:
  changes=[r for r in report['research'] if r['session']==sid]
  nodes=sorted({str(r['active']) for r in changes if r.get('active')})
  if changes:lines.append(f"\n`{sid}`: {len(changes)} Garden/research state records; active node IDs observed: {', '.join(nodes) or 'none'}. These are sampled state changes, not a count of completed research projects.")
 lines+=['','## Player markers','']
 for marker in report['markers']:lines.append(f"- `{marker['ref']['session']}:{marker['ref']['seq']}`: {marker['note']}")
 if not report['markers']:lines.append('No issue markers were present in the retained files.')
 lines+=['','## Next investigations','','1. Collect the missing active guest’s report to complete three-way comparisons. Export promptly after a problem; rolling logs discard older events.','2. Add an issue marker at the moment of a symptom. Include what the player saw, the skill/weapon used, and whether the host saw it too.','3. For suspected health desync, inspect the exact revision matches/mismatches in `summary.json`; do not compare nearby timestamps alone.','4. Improve long-playtest coverage: routine action records have rotated away the beginning of this host session. Consider compact full-run summaries or archiving each expedition before increasing trace volume.','5. Treat generation timing and network estimates as leads. Reproduce a symptom before changing balance, networking or procedural generation.','','## Analysis limitations','','- A report exported while the game is running is not proof of a crash. Missing clean-exit metadata is intentionally reported as unknown/open.','- Rotated chunks and unavailable viewpoints limit conclusions. A lack of recorded errors is not proof that none occurred outside coverage.','- Health comparisons include capacity and fallen state when both peers recorded them. Older damage records may only contain the incoming amount.','- Host snapshot-gap counters are not applicable because the host does not receive its own world snapshots.','- Shared revision comparisons avoid cross-PC clock assumptions; this report does not estimate one-way latency or precisely align clocks.','- The script is read-only toward inputs. It emits data and evidence references; it does not change the game, saves or original logs.','']
 return '\n'.join(lines)

def coverage_svg(report,offset):
 dates=[]
 for summary in report['sessions'].values():
  dates.extend(timestamp(v) for v in [summary['metadata'].get('started_utc'),summary.get('first_utc'),summary.get('last_utc'),summary['metadata'].get('last_utc')] if timestamp(v))
 if not dates:return ''
 start=min(dates);end=max(dates);span=max(1,(end-start).total_seconds());left=360;width=700;height=100+len(report['sessions'])*68
 def x(stamp):return left+width*(stamp-start).total_seconds()/span
 parts=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1100 {height}" role="img" aria-label="Retained log coverage by application session">',f'<rect width="1100" height="{height}" fill="#162219" rx="10"/>','<text x="16" y="25" fill="#e2e9dc" font-family="sans-serif" font-size="18">Retained log coverage</text>','<text x="16" y="47" fill="#afbea4" font-family="sans-serif" font-size="12">Gray: application span at export. Green: available events. Gaps are not proof of disconnection.</text>']
 for index,(sid,summary) in enumerate(report['sessions'].items()):
  y=72+index*68
  parts.append(f'<text x="16" y="{y+7}" fill="#dce7d2" font-family="sans-serif" font-size="14">{html.escape(summary["label"])}</text>')
  parts.append(f'<text x="16" y="{y+27}" fill="#a3b896" font-family="monospace" font-size="10">{html.escape(sid)}</text>')
  first=timestamp(summary['metadata'].get('started_utc')) or timestamp(summary.get('first_utc'));last=timestamp(summary.get('last_utc')) or first
  if first and last:parts.append(f'<rect x="{x(first):.1f}" y="{y}" width="{max(2,x(last)-x(first)):.1f}" height="23" fill="#52634d" rx="3"/>')
  for segment in summary['segments']:
   a=timestamp(segment['first_utc']);b=timestamp(segment['last_utc'])
   if a and b:parts.append(f'<rect x="{x(a):.1f}" y="{y}" width="{max(2,x(b)-x(a)):.1f}" height="23" fill="#9dc879" rx="2"/>')
 axis=height-25
 for index in range(6):
  point=start+dt.timedelta(seconds=span*index/5);px=left+width*index/5
  parts.append(f'<text x="{px:.1f}" y="{axis}" text-anchor="middle" fill="#c1cfb7" font-family="sans-serif" font-size="12">{point.astimezone(offset).strftime("%H:%M:%S")}</text>')
 parts.append('</svg>');return ''.join(parts)

def html_report(md,report,offset):
 # A readable standalone report; no scripts, network requests or unescaped log text.
 def inline(value):
  value=html.escape(str(value));value=re.sub(r'\*\*(.+?)\*\*',r'<strong>\1</strong>',value);return re.sub(r'`([^`]+)`',r'<code>\1</code>',value)
 blocks=[];table=False;header=False
 for line in md.splitlines():
  if line.startswith('|'):
   if not table:blocks.append('<div class="table"><table>');table=True;header=True
   if set(line.replace('|','').replace(':','').replace('-','').strip())==set():continue
   cells=re.split(r'(?<!\\)\|',line.strip('|'));tag='th' if header else 'td';blocks.append('<tr>'+''.join('<'+tag+'>'+inline(c.strip().replace('\\|','|'))+'</'+tag+'>' for c in cells)+'</tr>');header=False;continue
  if table:blocks.append('</table></div>');table=False
  if line.startswith('# '):blocks.append('<h1>'+inline(line[2:])+'</h1>')
  elif line.startswith('## '):blocks.append('<h2>'+inline(line[3:])+'</h2>')
  elif line:blocks.append('<p>'+inline(line)+'</p>')
 if table:blocks.append('</table></div>')
 chart=coverage_svg(report,offset)
 return '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Gameplay log analysis</title><style>body{font:16px/1.55 system-ui,sans-serif;background:#101813;color:#e2e9dc;margin:0 auto;padding:32px;max-width:1400px}h1,h2{color:#c5dba3}h2{margin-top:2em}.table{overflow:auto}table{border-collapse:collapse;width:100%;font-size:13px}td,th{padding:10px;border:1px solid #42543c;text-align:left;vertical-align:top;overflow-wrap:anywhere}th{background:#293b25}p{overflow-wrap:anywhere}</style>'+chart+''.join(blocks)+'</html>'

def output(report,reader,directory,offset):
 directory=Path(directory);directory.mkdir(parents=True,exist_ok=True)
 (directory/'summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 chart=coverage_svg(report,offset)
 if chart:(directory/'coverage.svg').write_text(chart,encoding='utf-8')
 md=markdown(report,offset);
 if chart:md=md.replace('## Findings','![Available log coverage](coverage.svg)\n\n## Findings',1)
 (directory/'report.md').write_text(md,encoding='utf-8');(directory/'report.html').write_text(html_report(md,report,offset),encoding='utf-8')
 events=[]
 for row in sorted(reader.rows.values(),key=lambda r:(r['session'],r['seq'])):
  c=row.get('context',{});events.append({'session':row['session'],'seq':row['seq'],'utc':row.get('utc'),'local_time':local_time(row.get('utc'),offset),'elapsed_ms':row.get('elapsed_ms'),'role':c.get('role'),'peer':c.get('peer'),'host_session':c.get('host_session'),'world_session':c.get('world_session'),'floor':c.get('floor'),'category':row.get('category'),'event':row.get('event'),'level':row.get('level'),'data':row.get('data',{}),'source':row['_source'],'line':row['_line']})
 write_csv(directory/'events.csv',events,['session','seq','utc','local_time','elapsed_ms','role','peer','host_session','world_session','floor','category','event','level','data','source','line'])
 write_csv(directory/'network.csv',report['network_series'],['session','seq','utc','elapsed_ms','role','peer','remote_peer','host_session','world_session','floor','rtt_ms','reliable_loss_estimate_percent','loss_epoch_ms','received_sequence','sent_sequence','snapshot_gaps','rejected_snapshots','fps'])
 write_csv(directory/'research.csv',report['research'],['session','seq','utc','role','floor','host_session','world_session','source','active','knowledge','work_seconds','unlocked_count'])
 write_csv(directory/'upgrades.csv',[{'actor':u['actor'],**u['data'],'ref':u['ref'],'interaction_ref':u['interaction_ref']} for u in report['upgrades']],['actor','id','floor','cost','ref','interaction_ref'])
 write_csv(directory/'life_events.csv',report['life_events'],['actor','kind','floor','changes','ref'])
 write_csv(directory/'damage.csv',report['damage'],['session','actor','amount','applied_hp','hp_after','damage_seq','vitals_revision','hp_per_point','floor','transaction_seq','ref'])
 write_csv(directory/'healing.csv',report['healing'],['session','role','floor','party_slot','source','rolled_hp','applied_hp','hp_after','max_hp','ref'])
 write_csv(directory/'encounters.csv',report['clears'],['session','role','floor','biome','cycle','kills','generation_to_clear_seconds','ref','generation_ref'])

def main():
 base=Path(__file__).resolve().parents[2];parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--input',nargs='+',type=Path,default=[base/'Gameplay logs']);parser.add_argument('--output',type=Path,default=base/'docs/gameplay-analysis');parser.add_argument('--catalog',type=Path,default=Path(__file__).with_name('catalog.json'),help='Optional versioned class labels; only used for matching log build fingerprints')
 parser.add_argument('--utc-offset',default='+00:00',help='Fixed report display offset, e.g. --utc-offset=-05:00; raw UTC is retained')
 args=parser.parse_args()
 try:
  sign=-1 if args.utc_offset.startswith('-') else 1;hours,minutes=map(int,args.utc_offset.lstrip('+-').split(':'))
  if hours>23 or minutes>59:raise ValueError('Invalid UTC offset')
  offset=dt.timezone(sign*dt.timedelta(hours=hours,minutes=minutes))
  # Never allow reports to overwrite a supplied log or its directory.
  target=args.output.resolve()
  for source in args.input:
   origin=source.resolve()
   if origin==target or (origin.is_dir() and origin in target.parents):raise ValueError('Output must be outside the input directory')
  reader=Reader().load(args.input);report=analyze(reader)
  if args.catalog.is_file():
   catalog=json.loads(args.catalog.read_text(encoding='utf-8-sig'))
   fingerprints={s['metadata'].get('build',{}).get('source_fingerprint') for s in report['sessions'].values()}
   if fingerprints=={catalog.get('source_fingerprint')}:report['catalog']=catalog
  output(report,reader,target,offset)
  print(f"Analyzed {len(report['sessions'])} sessions, {len(reader.rows):,} unique events; removed {reader.duplicates:,} duplicates.\nReport: {target/'report.html'}")
  print(f"Errors: {sum(s['errors'] for s in report['sessions'].values())}; health revisions: {report['health_comparison']['matched']}/{report['health_comparison']['compared']} matched.")
  return 0
 except (OSError,ValueError,zipfile.BadZipFile) as error:print('Analysis failed: '+str(error),file=sys.stderr);return 1
if __name__=='__main__':sys.exit(main())
