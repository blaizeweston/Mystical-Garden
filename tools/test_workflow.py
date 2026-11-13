"""Dependency-aware Godot validation; standard library only. See docs/VALIDATION_WORKFLOW.md."""
from __future__ import annotations
import ast, argparse, contextlib, datetime as dt, fnmatch, hashlib, json, os, re, shutil, subprocess, sys, time, uuid
from pathlib import Path

import validation_execution as execution

SCHEMA=1
TEXT_EXT={'.gd','.tscn','.tres','.godot','.cfg','.gdshader','.json'}
RES=re.compile(r"""res://([^'"\s\)]+)""")
GD_NONCODE=re.compile(
 r"""#[^\n]*|"{3}(?:\\.|(?!"{3}).)*"{3}|'{3}(?:\\.|(?!'{3}).)*'{3}"""
 r"""|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'""",re.DOTALL)
GD_WORLD_ASSIGNMENT=re.compile(
 r'\b([A-Za-z_]\w*)(?:[ \t]*:[ \t]*[A-Za-z_][\w.]*)?[ \t]*:?[ \t]*=(?!=)'
 r'\s*(?:load|preload)\s*\((\s*)\)\s*\.\s*(instantiate|new)\s*\(')
GD_MEMBER=re.compile(r'(?<![\w.])([A-Za-z_]\w*)\s*\.\s*([A-Za-z_]\w*)\b')
GD_CALLABLE=re.compile(r'\bCallable\s*\(\s*([A-Za-z_]\w*)\s*,')
GD_OPEN_CALL=re.compile(r'\s*\(')
GD_METHOD_ARGUMENT=re.compile(r"""\s*&?(["'])([A-Za-z_]\w*)\1\s*(?=[,)])""")
GD_REFLECTIVE_CALLS={'call','callv','call_deferred','call_thread_safe','call_deferred_thread_group'}

def fixture_game_references(text):
 """Find named dispatcher members and unresolved reflective calls in fixture code."""
 code=GD_NONCODE.sub(lambda match:' '*len(match[0]),text)
 receivers={'game'}
 for match in GD_WORLD_ASSIGNMENT.finditer(code):
  resource=text[match.start(2):match.end(2)].strip()
  target='res://world.tscn' if match[3]=='instantiate' else 'res://game.gd'
  if resource in (f'"{target}"',f"'{target}'"):receivers.add(match[1])
 names=set();reflective=[]
 for match in GD_MEMBER.finditer(code):
  receiver,member=match.groups()
  if receiver not in receivers:continue
  if member in GD_REFLECTIVE_CALLS:
   opening=GD_OPEN_CALL.match(code,match.end())
   reflective.append(GD_METHOD_ARGUMENT.match(text,opening.end()) if opening else None)
  else:names.add(member)
 for match in GD_CALLABLE.finditer(code):
  if match[1] in receivers:reflective.append(GD_METHOD_ARGUMENT.match(text,match.end()))
 names.update(argument[2] for argument in reflective if argument)
 return names,any(argument is None for argument in reflective)

def digest(data):return hashlib.sha256(data).hexdigest()
def hashed(value):return digest(json.dumps(value,sort_keys=True,separators=(',',':')).encode())
def read_json(path,default=None):
 try:return json.loads(Path(path).read_text(encoding='utf-8-sig'))
 except (OSError,ValueError):return default
def write_json(path,value):
 path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
 temporary=path.with_name(path.name+'.tmp');temporary.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8');os.replace(temporary,path)
def utc():return dt.datetime.now(dt.timezone.utc).isoformat()

def split_game(text):
 """Only top-level function bodies can be scoped; declarations/RPC layout form a global contract."""
 lines=text.splitlines(keepends=True);starts=[];signatures=[];body_lines=set()
 for i,line in enumerate(lines):
  match=re.match(r'^func (\w+)\(',line)
  if match:
   signature_end=i+1
   while signature_end<len(lines) and not lines[signature_end-1].rstrip().endswith(':'):signature_end+=1
   end=signature_end
   while end<len(lines) and (not lines[end].strip() or lines[end].startswith((' ','\t','#'))):end+=1
   starts.append((i,end,match[1]));signatures.append(''.join(lines[i:signature_end]).strip());body_lines.update(range(i,end))
 if not starts:return {'$contract':digest(text.encode())}
 declarations=''.join(line for i,line in enumerate(lines) if i not in body_lines and line.strip() and not line.lstrip().startswith('#'))
 tokens={'$contract':hashed({'declarations':declarations,'signatures':signatures})}
 for begin,end,name in starts:tokens[name]=digest(''.join(lines[begin:end]).strip().encode())
 return tokens

class Workflow:
 def __init__(self,project,engine):
  self.project=Path(project).resolve();self.engine=Path(engine).resolve();self.tools=self.project/'tools'
  self.root=self.project/'.godot/validation';self.root.mkdir(parents=True,exist_ok=True)
  self.map=read_json(self.tools/'test_map.json')
  if not self.map or self.map.get('schema')!=SCHEMA:raise ValueError('Missing or unsupported test map')
  if not self.engine.is_file():raise ValueError('Godot executable not found: '+str(self.engine))
  self.engine_hash=self.engine_signature();self.owner={}
  for system,definition in self.map['systems'].items():
   for file in definition['files']:self.owner.setdefault(file,[]).append(system)
  self.suites=dict(self.map['suites']);self.warnings=[]
  self.audit()
  self.cache=read_json(self.root/'cache.json',{}) or {}
  self.baseline=read_json(self.root/'full-baseline.json',{}) or {}
  self.tokens,self.domains,self.raw=self.snapshot()
  self.dispatcher_tokens={}
  for token in self.tokens:
   if token.startswith('game.gd::') and token!='game.gd::$contract':
    function=token.removeprefix('game.gd::').split('#',1)[0]
    self.dispatcher_tokens.setdefault(function,[]).append(token)
  self.fixture_calls={}
  self.input_keys={}
  self.infrastructure_paths={p.relative_to(self.project).as_posix() for p in self.infrastructure_files() if p.is_file()}
  self.infrastructure=self.infrastructure_hash()
  self.lineage=read_json(self.root/'key-lineage.json',{}) or {}
  self.keys={name:self.suite_key(name,record_inputs=True) for name in self.suites}
  self.known_inputs=set().union(*self.input_keys.values())

 def engine_signature(self):
  files=[self.engine]
  if self.engine.stem.endswith('_console'):
   editor=self.engine.with_name(self.engine.stem[:-8]+self.engine.suffix)
   if not editor.is_file():raise ValueError('Godot console launcher is missing its engine binary: '+str(editor))
   files.append(editor)
  return hashed({p.name:digest(p.read_bytes()) for p in files})

 def audit(self):
  systems=set(self.map['systems'])
  for edge in self.map.get('relationships',[]):
   if not isinstance(edge,list) or len(edge)!=3 or not all(isinstance(value,str) for value in edge) or edge[0] not in systems or edge[1] not in systems:raise ValueError('Invalid system relationship: '+str(edge))
  for path,rule in self.map.get('binary_regions',{}).items():
   if not path.startswith('assets/') or Path(path).suffix!='.glb' or not (self.project/path).is_file():raise ValueError('Invalid/missing scoped visual asset: '+path)
   if not re.fullmatch('[0-9a-f]{64}',rule.get('baseline_sha256','')) or not rule.get('contract') or not rule.get('systems') or not set(rule['systems'])<=systems:raise ValueError('Invalid visual asset boundary: '+path)
  for name,suite in self.suites.items():
   if not set(suite['systems'])<=systems:raise ValueError('Unknown system in '+name)
   if suite['kind'] not in ['unit','solo','pair','party','smoke']:raise ValueError('Unknown runner for '+name)
   source=self.source(name)
   if not source.is_file():raise ValueError('Registered test is missing: '+str(source))
  for test in sorted((self.project/'tests').glob('*.gd')):
   name='playable_solo' if test.stem=='playable' else test.stem
   if name in self.suites or test.stem in self.map['ignored_tests']:continue
   self.warnings.append('Unmapped test: '+test.name)
   self.suites[name]={'kind':'pair' if name.endswith('_coop') else 'unit','systems':list(systems),'package':False,'all_runtime':True}
  for name,values in self.map['game_functions'].items():
   if not set(values)<=systems:raise ValueError('Unknown function ownership: '+name)
  for path in self.owner:
   if not (self.project/path).is_file():raise ValueError('Mapped source is missing: '+path)

 def source(self,name):
  return self.project/('test/net_test.gd' if name=='supplied_network_smoke' else 'tests/playable.gd' if name=='playable_solo' else 'tests/'+name+'.gd')

 def owners(self,path):
  if path in self.owner:return self.owner[path]
  # Asset rules are ordered. A specific rule must precede any broader match.
  for pattern,domains in self.map['asset_rules'].items():
   if fnmatch.fnmatchcase(path,pattern):return domains
  if path.endswith('.uid') and path[:-4] in self.owner:return ['foundation']
  return ['foundation']

 def runtime_files(self):
  files=[p for p in self.project.iterdir() if p.is_file() and p.suffix in TEXT_EXT|{'.uid'}]
  files += [p for p in (self.project/'assets').rglob('*') if p.is_file() and 'source' not in p.relative_to(self.project/'assets').parts and p.name!='build_manifest.json']
  return sorted(files)

 def scoped_game(self,text):
  # Extract exact, declared wiring fragments from legacy dispatchers. The remainder
  # retains its original identity; changed fragments and their services own coverage.
  rules=self.map.get('game_regions',{});regional={};domains={}
  # Additive multi-line adapters are removed before locating existing regions.
  # This preserves prior line coordinates for untouched wiring downstream.
  for function,regions in rules.items():
   for region,rule in regions.items():
    if not rule.get('additive'):continue
    start=re.search(r'(?m)^func '+re.escape(function)+r'\(',text)
    if not start:raise ValueError('Missing scoped function: '+function)
    following=re.search(r'(?m)^func \w+\(',text[start.end():]);end=start.end()+following.start() if following else len(text)
    body=text[start.start():end];fragment=rule['match'];baseline=rule['baseline']
    if '\r\n' in body and '\r\n' not in fragment:fragment=fragment.replace('\n','\r\n');baseline=baseline.replace('\n','\r\n')
    if body.count(fragment)!=1:raise ValueError('Additive region must match once: '+function+'#'+region)
    position=body.index(fragment);prefix=body[:position];token='game.gd::'+function+'#'+region
    regional[token]={'rule':rule,'matches':[{'line':prefix.count('\n'),'column':position-prefix.rfind('\n')-1}]};domains[token]=rule['systems']
    text=text[:start.start()]+body.replace(fragment,baseline,1)+text[end:]
  lines=text.splitlines(keepends=True)
  current='';current_start=0
  for index,line in enumerate(lines):
   match=re.match(r'^func (\w+)\(',line)
   if match:current=match[1];current_start=index
   for region,rule in rules.get(current,{}).items():
    if rule.get('additive'):continue
    token='game.gd::'+current+'#'+region
    row=regional.setdefault(token,{'rule':rule,'matches':[]})
    if rule['match'] in line:
     row['matches'].append({'line':index-current_start,'column':line.index(rule['match'])});line=line.replace(rule['match'],rule['baseline']);lines[index]=line
    domains[token]=rule['systems']
  for function,regions in rules.items():
   for region in regions:
    token='game.gd::'+function+'#'+region
    if not regional.get(token,{}).get('matches'):
     self.warnings.append('Unmatched scope: '+token+' (no match in the normalized function)')
  return split_game(''.join(lines)),{key:hashed(value) for key,value in regional.items()},domains

 def snapshot(self):
  tokens={};domains={};raw={}
  file_regions=self.map.get('file_regions',{})
  unchecked=set(file_regions)
  for file in self.runtime_files():
   path=file.relative_to(self.project).as_posix();data=file.read_bytes();raw[path]=digest(data)
   if path in self.map.get('binary_regions',{}):
    # Same idea as a scoped source adapter: retain the verified pre-scope
    # dependency identity for consumers that do not inspect presentation.
    # Actual bytes still enter raw/source fingerprints and broad smoke suites.
    rule=self.map['binary_regions'][path]
    tokens[path]=rule['baseline_sha256'];domains[path]=self.owners(path)
    token=path+'::#visual';tokens[token]=hashed({'asset':raw[path],'contract':rule['contract']});domains[token]=rule['systems']
    continue
   if path=='export_presets.cfg':
    # The exporter fills local template/output paths; these do not change game behavior.
    text=data.decode('utf-8-sig');text=re.sub(r'(?m)^(export_path|custom_template/(?:debug|release))="[^"]*"',r'\1="<local>"',text);data=text.encode()
   if path=='game.gd':
    bodies,regional,region_domains=self.scoped_game(data.decode('utf-8-sig'))
    tokens.update(regional);domains.update(region_domains)
    for name,value in bodies.items():
     token='game.gd::'+name;tokens[token]=value
     domains[token]=['foundation'] if name=='$contract' else self.map['game_functions'].get(name,['foundation'])
     if name!='$contract' and name not in self.map['game_functions']:self.warnings.append('Unmapped game function: '+name)
   else:
    if path in file_regions:
     unchecked.remove(path)
     original=data.decode('utf-8-sig').replace('\r\n','\n')
     normalized=original
     specification=file_regions[path]
     for region,rule in specification['regions'].items():
      token=path+'::#'+region
      occurrences=[{'line':normalized.count('\n',0,match.start()),'column':match.start()-normalized.rfind('\n',0,match.start())-1} for match in re.finditer(re.escape(rule['match']),normalized)]
      if not occurrences:
       reason='shadowed by an earlier scope' if rule['match'] in original else 'no match in the normalized file'
       self.warnings.append('Unmatched scope: '+token+' ('+reason+')')
      normalized=normalized.replace(rule['match'],rule['baseline'])
      tokens[token]=hashed({'rule':rule,'occurrences':occurrences});domains[token]=rule['systems']
     normalized=normalized.replace('\r\n','\n')
     if specification.get('newline')=='crlf':
      # Recreate the prior byte layout for scoped files with mixed line endings.
      lf_lines=set(specification.get('lf_lines',[]))
      normalized=''.join(line if index in lf_lines else line.replace('\n','\r\n')
                         for index,line in enumerate(normalized.splitlines(keepends=True),1))
     data=normalized.encode('utf-8')
    tokens[path]=digest(data);domains[path]=self.owners(path)
    if path not in self.owner and not any(fnmatch.fnmatchcase(path,p) for p in self.map['asset_rules']) and not path.endswith('.uid'):
     self.warnings.append('Unmapped runtime file: '+path)
  for path in sorted(unchecked):
   for region in file_regions[path]['regions']:
    self.warnings.append('Unmatched scope: '+path+'::#'+region+' (file is missing or excluded from the text snapshot)')
  if 'game.gd' not in raw:
   for function,regions in self.map.get('game_regions',{}).items():
    for region in regions:
     self.warnings.append('Unmatched scope: game.gd::'+function+'#'+region+' (dispatcher file is missing)')
  return tokens,domains,raw

 def infrastructure_files(self):
  return list(self.tools.glob('*.ps1'))+[self.tools/'test_map.json',self.tools/'test_workflow.py',self.tools/'validation_execution.py']+list((self.tools/'tests').glob('*.py'))+list((self.project/'test').glob('*'))

 def infrastructure_hash(self):
  return hashed({str(p.relative_to(self.project)):digest(p.read_bytes()) for p in self.infrastructure_files() if p.is_file()})

 def runner_signature(self):
  nodes=[n for n in ast.walk(ast.parse(Path(__file__).read_text(encoding='utf-8-sig'))) if isinstance(n,ast.FunctionDef) and n.name in ['execute','environment','source']]
  return hashed([digest(Path(execution.__file__).read_bytes()),*[ast.dump(n,include_attributes=False) for n in nodes]])

 def suite_salt(self,suite):
  if self.lineage.get('runner')!=self.runner_signature():return self.infrastructure
  changes={}
  for path,old in self.lineage.get('files',{}).items():
   path=path.replace('\\','/')
   relevant=(suite['kind']=='party' and path=='tools/test_four_players.ps1') or (suite['kind']=='smoke' and path.startswith('test/'))
   if relevant:
    file=self.project/path;value=digest(file.read_bytes()) if file.is_file() else 'missing'
    if value!=old:changes[path]=value
  anchor=self.lineage['anchor']
  return hashed({'anchor':anchor,'runner_changes':changes}) if changes else anchor

 def resources(self,start,systems=None):
  """Follow literal resources, stopping traversal at the shared dispatcher."""
  visited=set();pending=list(start)
  while pending:
   path=pending.pop()
   if path in visited or path=='assets/content/build_manifest.json' or path.startswith('.godot/') or '..' in Path(path).parts:continue
   visited.add(path);file=self.project/path
   if path=='game.gd':continue
   if file.is_file() and file.suffix in TEXT_EXT:
    text=file.read_text(encoding='utf-8-sig',errors='replace')
    if systems is not None:
     for rule in self.map.get('file_regions',{}).get(path,{}).get('regions',{}).values():
      if not systems.intersection(rule['systems']):text=text.replace(rule['match'],rule['baseline'])
    pending.extend(RES.findall(text))
  return visited

 def fixture_dispatcher_calls(self,dependencies):
  direct={};dynamic=set()
  if 'game.gd' not in dependencies:return direct,dynamic
  for path in dependencies:
   file=self.project/path
   if not path.startswith(('tests/','test/')) or file.suffix!='.gd' or not file.is_file():continue
   members,unresolved=fixture_game_references(file.read_text(encoding='utf-8-sig'))
   for member in members:
    for token in self.dispatcher_tokens.get(member,[]):
     direct.setdefault(token,set()).add(path)
   if unresolved:dynamic.add(path)
  return direct,dynamic

 def suite_key(self,name,record_inputs=False):
  suite=self.suites[name];systems=set(suite['systems'])
  inputs={p:h for p,h in self.tokens.items() if suite.get('all_runtime') or 'foundation' in self.domains[p] or systems.intersection(self.domains[p])}
  initial=[self.source(name).relative_to(self.project).as_posix()]
  dependencies=self.resources(initial,systems)
  # Use the same tokens as declared ownership, so already-covered calls keep the same key.
  direct,dynamic=self.fixture_dispatcher_calls(dependencies)
  inputs.update({token:self.tokens[token] for token in direct})
  if dynamic:
   for tokens in self.dispatcher_tokens.values():
    inputs.update({token:self.tokens[token] for token in tokens})
  for path in dependencies-{'game.gd'}:
   file=self.project/path
   if file.is_file():inputs['resource:'+path]=self.tokens[path] if path in self.map.get('file_regions',{}) or path in self.map.get('binary_regions',{}) else digest(file.read_bytes())
  if record_inputs:
   self.input_keys[name]=frozenset(inputs)
   self.fixture_calls[name]=(direct,dynamic)
  return hashed({'schema':SCHEMA,'engine':self.engine_hash,'infrastructure':self.suite_salt(suite),'suite':suite,'inputs':inputs})

 def valid(self,name):
  row=self.cache.get(name,{})
  return row.get('key')==self.keys[name] and row.get('passed') is True and self.intact_evidence(row.get('logs'))

 def changed(self):
  before=self.baseline.get('tokens',{})
  return sorted(p for p in set(before)|set(self.tokens) if before.get(p)!=self.tokens.get(p))

 def changed_inputs(self,changes,preview):
  """Translate reported changes into names from the suite fingerprint input set."""
  inputs=set();notes=[];unmapped=[];unbounded=False
  for change in changes:
   token=str(change).replace('\\','/').removeprefix('./')
   literal='resource:'+token
   if not preview:
    inputs.add(token)
    if literal in self.known_inputs:inputs.add(literal)
   elif token=='game.gd':
    inputs.add('game.gd::$contract')
    notes.append('game.gd may change the shared contract. For a body-only edit, specify its function or region token.')
   elif token in self.map.get('binary_regions',{}):
    inputs.add(token+'::#visual')
   elif token in self.infrastructure_paths:
    notes.append('Validation infrastructure impact requires the edited files: '+token)
    unbounded=True
   elif token in self.tokens or token in self.known_inputs or literal in self.known_inputs:
    inputs.add(token)
    if literal in self.known_inputs:inputs.add(literal)
    regions=self.map.get('file_regions',{}).get(token,{}).get('regions',{})
    if regions:
     notes.append(token+' previews its base fingerprint. Include any affected path::#region tokens for a scoped or compound edit.')
    if token.startswith('game.gd::') and token.removeprefix('game.gd::') in self.map.get('game_regions',{}):
     notes.append(token+' previews its body fingerprint. Include affected dispatcher region tokens if the edit also changes them.')
    if token=='export_presets.cfg':
     notes.append('Local template and output paths in export_presets.cfg are normalized away.')
   elif (token.startswith(('docs/','assets/source/','.godot/')) or token=='assets/content/build_manifest.json'
         or (token.startswith('tests/') and Path(token).stem in self.map['ignored_tests'])):
    continue
   else:
    unmapped.append('Unmapped proposed input: '+token+'. Classify the input or inspect the edited project before validation.')
    unbounded=True
  return inputs,notes,unmapped,unbounded

 def input_reasons(self,name,matches):
  direct,dynamic=self.fixture_calls[name]
  calls=matches&direct.keys()
  reasons=['Fixture call: '+token+' via '+', '.join(sorted(direct[token])) for token in sorted(calls)]
  dispatcher={token for token in matches if token.startswith('game.gd::') and token!='game.gd::$contract'}
  if dispatcher and dynamic:
   reasons.append('Dynamic fixture call uses conservative game.gd coverage: '+', '.join(sorted(dynamic)))
  literal={token for token in matches if token.startswith('resource:')}
  foundation={token for token in matches if 'foundation' in self.domains.get(token,())}
  for label,keys in (('Foundation input',foundation),('Literal resource',literal),
                     ('Fingerprint input',matches-calls-foundation-literal)):
   if keys:
    names=sorted(token.removeprefix('resource:') for token in keys)
    suffix=f' (+{len(names)-5} more)' if len(names)>5 else ''
    reasons.append(label+': '+', '.join(names[:5])+suffix)
  return reasons

 def plan(self,mode='connected',changed=None,no_cache=False):
  preview=changed is not None
  changes=list(changed) if preview else self.changed()
  inputs,notes,unmapped,unbounded=self.changed_inputs(changes,preview)
  uncertain=bool(notes or unbounded)
  if preview and (inputs or unbounded):
   notes.insert(0,'Assumes the listed fingerprints change. Inspect edited files for normalized edits, new dependency edges, or compound changes.')
  affected={domain for token in inputs for domain in self.domains.get(token,())}
  reasons=sorted(set(self.warnings+unmapped))
  # Full is explicit: routine map edits and baseline age never schedule the whole game.
  full=mode=='full'
  selected={};predicted=[];reusable={name for name in self.suites if self.valid(name)}
  for name,suite in sorted(self.suites.items()):
   matches=inputs&self.input_keys[name]
   impacted=bool(matches or unbounded)
   if preview and impacted:predicted.append(name)
   if mode=='focused' and suite['kind']!='unit':continue
   if preview:
    if not impacted:continue
   elif not (full or no_cache or impacted or name not in reusable):continue
   why=self.input_reasons(name,matches)
   if preview and unbounded:why.append('Potential impact cannot be bounded from the proposed paths')
   if full and not preview:why.insert(0,'Full validation')
   if not why:why=['Cache bypass requested' if no_cache else 'Missing, changed or damaged test evidence']
   cached=not full and not no_cache and not preview and name in reusable
   selected[name]={'kind':suite['kind'],'cached':cached,'reasons':why}
  reuse_count=len(reusable.difference(predicted)) if preview else sum(n not in selected or selected[n]['cached'] for n in reusable)
  result={'schema':SCHEMA,'requested':mode,'effective':mode,'preview':preview,'changes':changes,
          'affected_systems':sorted(affected),'escalation':reasons,'blocked':bool(reasons),
          'selected':selected,'run_count':sum(not s['cached'] for s in selected.values()),
          'reuse_count':reuse_count,
          'total_suites':len(self.suites)}
  if preview:result.update(predicted_invalidations=predicted,uncertain=uncertain,notes=notes)
  return result

 def environment(self):
  env=os.environ.copy();env['APPDATA']=str(self.project/'.godot/stabilization-appdata');env['LOCALAPPDATA']=str(self.project/'.godot/stabilization-localappdata');env['MYSTICAL_GARDEN_TEST_PORT']='32283'
  Path(env['APPDATA']).mkdir(parents=True,exist_ok=True);Path(env['LOCALAPPDATA']).mkdir(parents=True,exist_ok=True)
  return env

 def execute(self,name,logdir):
  kind=self.suites[name]['kind'];token=uuid.uuid4().hex;folder=logdir/name
  started=time.monotonic()
  error=''
  codes=[]
  files=[]
  if kind=='smoke':
   shell=shutil.which('pwsh') or str(Path(os.environ.get('USERPROFILE',''))/'.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe')
   if not Path(shell).is_file():raise ValueError('PowerShell 7 is required for network test process exit-code reporting')
   folder.mkdir(parents=True,exist_ok=False)
   log=folder/'launcher.log';files=[log]
   args=[shell,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(self.project/'test/run_net_test.ps1'),
         '-Godot',str(self.engine),'-Clients','3','-Port','32311','-HostFps','60','-GuestFps','240',
         '-SkipImport','-RunId',token,'-LogRoot',str(folder)]
   with log.open('wb') as output:
    process=subprocess.Popen(args,cwd=self.project,env=self.environment(),stdout=output,stderr=subprocess.STDOUT,
                             creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
   try:
    codes=[process.wait(timeout=150)]
    if codes!=[0]:raise ValueError(f'network smoke launcher exit {codes[0]}')
    output=log.read_text(encoding='utf-8-sig',errors='replace')
    if not execution.PASS.search(output) or execution.FAIL.search(output) or execution.ENGINE_ERROR.search(output):
     raise ValueError('network smoke launcher log did not pass')
    files.extend(execution.verify_smoke_run(folder,token))
   except (ValueError,subprocess.TimeoutExpired) as failure:
    error=str(failure)
   finally:
    execution.terminate(process)
  else:
   try:
    verdict=execution.run_fixture(self.project,self.engine,name,kind,self.source(name),folder,token)
    codes=[row['exit'] for row in verdict['peers'].values()]
    if not verdict['passed']:
     error='; '.join(f"{peer}: {', '.join(row['issues'])}" for peer,row in verdict['peers'].items() if row['issues'])
    else:
     files=execution.verify_fixture_run(folder,token,name,kind,self.source(name))
   except (OSError,ValueError) as failure:
    error=str(failure)
  if error:
   files=[p for pattern in ('*.log','*.json') for p in folder.glob(pattern)]
  result={'key':self.keys[name],'passed':not error,'at':utc(),'run_id':token,
          'seconds':round(time.monotonic()-started,3),'logs':self.evidence_hashes(files),'exit_codes':codes}
  if error:result['error']=error
  return result

 def evidence_hashes(self,files):
  return {os.path.relpath(p,self.root).replace(chr(92),'/'):digest(p.read_bytes()) for p in files}

 def intact_evidence(self,logs):
  return isinstance(logs,dict) and bool(logs) and all((self.root/p).is_file() and digest((self.root/p).read_bytes())==h for p,h in logs.items())

 @contextlib.contextmanager
 def locked(self):
  path=self.root/'workflow.lock'
  try:fd=os.open(path,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
  except FileExistsError:raise ValueError('Another validation is running, or its lock was left after interruption: '+str(path))
  try:
   os.write(fd,str(os.getpid()).encode());os.close(fd);yield
  finally:path.unlink(missing_ok=True)

 def run(self,mode,no_cache=False):
  with self.locked():
   plan=self.plan(mode,no_cache=no_cache);self.print_plan(plan)
   if plan['blocked']:raise ValueError('Classify unmapped inputs and correct unmatched scopes before validation: '+'; '.join(plan['escalation']))
   run_id=dt.datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:8]
   logdir=self.root/'runs'/run_id;logdir.mkdir(parents=True)
   write_json(logdir/'plan.json',plan)
   attempted=[name for name,row in plan['selected'].items() if not row['cached']]
   # An unsuccessful retry must never leave an older pass usable for this input.
   for name in attempted:self.cache.pop(name,None)
   write_json(self.root/'cache.json',self.cache)
   results={};started=time.monotonic()
   for name,row in plan['selected'].items():
    if row['cached']:print('REUSE '+name,flush=True);continue
    result=self.execute(name,logdir);results[name]=result
    print(('PASS ' if result['passed'] else 'FAIL ')+name+' ('+str(result['seconds'])+'s)',flush=True)
   after_tokens,_,after_raw=self.snapshot()
   stable=after_raw==self.raw and after_tokens==self.tokens and self.infrastructure_hash()==self.infrastructure and self.engine_signature()==self.engine_hash and all(self.suite_key(n)==k for n,k in self.keys.items())
   if stable:self.cache.update(results);write_json(self.root/'cache.json',self.cache)
   passed=stable and all(r['passed'] for r in results.values())
   if passed and plan['effective']=='full':
    self.baseline={'schema':SCHEMA,'at':utc(),'engine':self.engine_hash,'infrastructure':self.infrastructure,'tokens':self.tokens,'run_id':run_id}
    write_json(self.root/'full-baseline.json',self.baseline)
   report={'schema':SCHEMA,'run_id':run_id,'at':utc(),'passed':passed,'stable_inputs':stable,'mode':plan['effective'],'executed':len(attempted),'reused':plan['reuse_count'],'seconds':round(time.monotonic()-started,3),'plan':plan,'release_ready':self.release_ready() if passed else False}
   write_json(logdir/'report.json',report);write_json(self.root/'latest-report.json',report)
   print(('PASS: ' if passed else 'FAIL: ')+str(len(attempted))+' executed, '+str(plan['reuse_count'])+' reused; release coverage '+('complete' if report['release_ready'] else 'incomplete'),flush=True)
   if not stable:print('Inputs changed during validation; new results were discarded.',flush=True)
   return passed

 def release_ready(self):
  plan=self.plan('connected')
  # Full requests intentionally don't reuse; a fresh baseline has no changed contracts.
  return not plan['escalation'] and all(self.valid(name) for name in self.suites)

 def verify(self):
  missing=[name for name in self.suites if not self.valid(name)]
  plan=self.plan('connected')
  if missing or plan['escalation']:raise ValueError('Validation evidence is incomplete or stale. Run validate_release.ps1. Missing: '+', '.join(missing)+'; '+ '; '.join(plan['escalation']))
  evidence={'schema':SCHEMA,'at':utc(),'engine':self.engine_hash,'infrastructure':self.infrastructure,'source':hashed(self.tokens),'suites':{n:self.keys[n] for n in self.suites}}
  write_json(self.root/'release-evidence.json',evidence)
  # Compatibility output for existing reports, now derived from current suite fingerprints.
  write_json(self.project/'.godot/stabilization/release-checks.json',[{'test':n,'passed':True,'key':self.keys[n],'evidence':self.cache[n]['logs']} for n in sorted(self.suites)])
  return evidence

 def template_signature(self):
  preset=self.project/'export_presets.cfg'
  if not preset.is_file():return self.engine_hash
  match=re.search(r'custom_template/release="([^"]+)"',preset.read_text(encoding='utf-8-sig'))
  if not match:return self.engine_hash
  template=Path(match.group(1))
  if not template.is_absolute():template=self.project/template
  if not template.is_file():raise ValueError('Release export template is missing: '+str(template))
  return digest(template.read_bytes())

 def package_plan(self,full=False):
  self.verify();cache=read_json(self.root/'package-cache.json',{}) or {};last=read_json(self.root/'latest-report.json',{}) or {}
  template=self.template_signature()
  full=full or not cache or cache.get('template')!=template or last.get('mode')=='full'
  cached_keys=cache.get('keys',{});cached_results=cache.get('results',{})
  selected={kind:[] for kind in ['unit','pair','party','smoke']};reused=[]
  for name,suite in self.suites.items():
   if not suite['package']:continue
   if full or cached_keys.get(name)!=self.keys[name] or not self.intact_evidence(cached_results.get(name)):selected[suite['kind']].append(name)
   else:reused.append(name)
  # Every new package exercises startup/catalogs separately, plus real peer connection.
  if 'supplied_network_smoke' not in selected['smoke']:selected['smoke'].append('supplied_network_smoke');reused=[n for n in reused if n!='supplied_network_smoke']
  plan={'schema':SCHEMA,'run_id':uuid.uuid4().hex,'full':full,'template':template,'source':hashed(self.tokens),'engine':self.engine_hash,'infrastructure':self.infrastructure,'keys':{n:self.keys[n] for n in self.suites if self.suites[n]['package']},'selected':selected,'reused':reused}
  write_json(self.root/'package-plan.json',plan);return plan

 def commit_package(self,pack):
  self.verify();plan=read_json(self.root/'package-plan.json',{}) or {}
  if plan.get('template')!=self.template_signature() or plan.get('source')!=hashed(self.tokens) or plan.get('infrastructure')!=self.infrastructure or plan.get('engine')!=self.engine_hash:raise ValueError('Inputs changed during export; package evidence cannot be committed')
  pack=Path(pack).resolve()
  if not pack.is_file():raise ValueError('Packaged executable missing')
  run_id=plan.get('run_id','')
  if not execution.IDENTIFIER.fullmatch(run_id):raise ValueError('Invalid package run ID')
  folder=self.root/'package-runs'/run_id
  preflight=execution.verify_fixture_run(folder/'catalog_preflight',run_id,'catalog_preflight','unit',self.project/'tests/content_validation.gd')
  startup=execution.verify_fixture_run(folder/'package_startup',run_id,'package_startup','unit',folder/'package_smoke.gd',pack)
  results={}
  for kind in ('unit','pair','party'):
   for name in plan['selected'][kind]:
    results[name]=self.evidence_hashes(execution.verify_fixture_run(folder/name,run_id,name,kind,self.source(name),pack))
  results['supplied_network_smoke']=self.evidence_hashes(execution.verify_smoke_run(folder/'supplied_network_smoke',run_id,pack))
  cache=read_json(self.root/'package-cache.json',{}) or {}
  for name in plan['reused']:
   prior=cache.get('results',{}).get(name)
   if cache.get('keys',{}).get(name)!=plan['keys'][name] or not self.intact_evidence(prior):
    raise ValueError('Missing or stale reused packaged evidence: '+name)
   results[name]=prior
  if set(results)!=set(plan['keys']):raise ValueError('Incomplete packaged suite evidence')
  write_json(self.root/'package-cache.json',{'schema':SCHEMA,'template':plan['template'],'keys':plan['keys'],'results':results})
  write_json(self.root/'last-package.json',{'at':utc(),'path':str(pack),'sha256':digest(pack.read_bytes()),
             'plan':plan,'evidence':str(folder),'startup_logs':self.evidence_hashes(preflight+startup)})

 def document(self):
  lines=['# Mechanics and test coverage map','','Generated from `tools/test_map.json` by `test_workflow.py document`.','','Edges describe gameplay/data relationships. Selection uses explicit suite coverage and resource dependencies; it does not follow every visual edge recursively.','','```mermaid','flowchart LR']
  for name,definition in self.map['systems'].items():lines.append('  '+name+'["'+definition['label'].replace(',','<br/>')+'"]')
  for a,b,reason in self.map['relationships']:lines.append('  '+a+' -->|"'+reason+'"| '+b)
  lines+=['```','','## System ownership and tests','','| System | Source files | Covering suites |','|---|---|---|']
  for name,definition in self.map['systems'].items():
   suites=[n for n,s in self.suites.items() if name in s['systems'] and not s.get('all_runtime')]
   if name=='foundation':suites=['All registered suites (implicit shared contract)']
   lines.append('| '+name+' | '+', '.join('`'+f+'`' for f in definition['files'])+' | '+', '.join('`'+n+'`' for n in suites)+' |')
  lines+=['','## Existing game dispatcher functions','','`game.gd` is currently shared by most mechanics. Body-only edits use the function ownership below. Shared declarations broaden affected coverage; Full runs require an explicit major-release request. Unmapped inputs must be classified before validation. This is a conservative bridge until the dispatcher is separated into smaller services.','','| Function | Systems |','|---|---|']
  for name,domains in sorted(self.map['game_functions'].items()):lines.append('| `'+name+'` | '+', '.join(domains)+' |')
  lines+=['','## Scoped integration wiring','','The untouched dispatcher/file remainder keeps its original coverage. These exact fragments and their source locations have the following additional consumers.','','| Location | Region | Systems |','|---|---|---|']
  for function,regions in self.map.get('game_regions',{}).items():
   for name,rule in regions.items():lines.append('| `game.gd::'+function+'` | '+name+' | '+', '.join(rule['systems'])+' |')
  for file,specification in self.map.get('file_regions',{}).items():
   for name,rule in specification['regions'].items():lines.append('| `'+file+'` | '+name+' | '+', '.join(rule['systems'])+' |')
  lines+=['','## Scoped visual assets','','The base identity is the verified pre-scope asset hash, preserved for unrelated mechanics that incidentally import the world. The visual token, raw release fingerprint and broad smoke retain actual current bytes. Bone/morph/action/skin contracts are checked by the declared character/weapon suites. A contract change must broaden ownership.','','| Asset | Visual consumers | Contract |','|---|---|---|']
  for file,rule in self.map.get('binary_regions',{}).items():lines.append('| `'+file+'` | '+', '.join(rule['systems'])+' | '+rule['contract']+' |')
  path=self.project/'docs/MECHANICS_TEST_MAP.md';path.write_text('\n'.join(lines)+'\n',encoding='utf-8');return path

 @staticmethod
 def print_plan(plan):
  heading='Validation preview: ' if plan['preview'] else 'Validation: '
  print(heading+plan['effective']+'; '+str(plan['run_count'])+' to execute, '+str(plan['reuse_count'])+' reusable, '+str(plan['total_suites'])+' registered suites',flush=True)
  for reason in plan['escalation']:print('BLOCKED: '+reason,flush=True)
  for note in plan.get('notes',[]):print('NOTE: '+note,flush=True)
  for name,row in plan['selected'].items():
   action='IMPACT ' if plan['preview'] else 'REUSE ' if row['cached'] else 'RUN '
   print(action+name+' : '+'; '.join(row['reasons']),flush=True)

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('command',choices=['plan','run','verify','document','package-plan','package-commit']);parser.add_argument('--project',type=Path,default=Path(__file__).resolve().parent.parent);parser.add_argument('--engine',type=Path);parser.add_argument('--mode',choices=['focused','connected','full'],default='connected');parser.add_argument('--changed',nargs='+');parser.add_argument('--no-cache',action='store_true');parser.add_argument('--pack');parser.add_argument('--full-package',action='store_true')
 args=parser.parse_args();engine=args.engine or args.project.parent/'Godot_v4.7.2-stable_win64_console.exe'
 try:
  workflow=Workflow(args.project,engine)
  if args.command=='plan':
   plan=workflow.plan(args.mode,args.changed,args.no_cache);workflow.print_plan(plan);write_json(workflow.root/'plan-preview.json',plan)
  elif args.command=='run':
   if args.changed:raise ValueError('--changed is preview-only; real runs always detect actual inputs')
   return 0 if workflow.run(args.mode,args.no_cache) else 1
  elif args.command=='verify':workflow.verify();print('PASS: current validation evidence covers every registered suite')
  elif args.command=='document':print(workflow.document())
  elif args.command=='package-plan':print(json.dumps(workflow.package_plan(args.full_package),indent=2))
  elif args.command=='package-commit':workflow.commit_package(args.pack);print('PASS: packaged validation evidence recorded')
  return 0
 except (OSError,ValueError,KeyError) as error:print('FAIL: '+str(error),file=sys.stderr);return 1
if __name__=='__main__':sys.exit(main())

