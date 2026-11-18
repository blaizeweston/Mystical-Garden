import contextlib, copy, importlib.util, io, json, os, sys, tempfile, unittest
from pathlib import Path
from unittest.mock import patch
MODULE=Path(__file__).resolve().parents[1]/'test_workflow.py'
sys.path.insert(0,str(MODULE.parent))
spec=importlib.util.spec_from_file_location('workflow',MODULE);w=importlib.util.module_from_spec(spec);spec.loader.exec_module(w)

class WorkflowTests(unittest.TestCase):
 def setUp(self):
  capture=contextlib.redirect_stdout(io.StringIO());capture.__enter__();self.addCleanup(capture.__exit__,None,None,None)
  fixtures=MODULE.parents[1]/'.godot/validation-selftests';fixtures.mkdir(parents=True,exist_ok=True)
  self.temp=tempfile.TemporaryDirectory(dir=fixtures);self.p=Path(self.temp.name).resolve()
  assert self.p.parent==fixtures.resolve()
  self.addCleanup(self.temp.cleanup)
  for name in ['tools/tests','tests','assets','test']:(self.p/name).mkdir(parents=True,exist_ok=True)
  self.engine=self.p/'engine.exe';self.engine.write_bytes(b'fixture-engine')
  self.put('core.gd','extends RefCounted\n')
  self.put('settings.gd','extends RefCounted\n')
  self.put('seeds.gd','extends RefCounted\n')
  self.put('weapons.gd','extends RefCounted\n')
  self.put('game.gd','extends Node\nconst VERSION=1\nfunc plant():\n return 1\nfunc strike():\n return 2\n')
  for n in ['seeds','weapons','settings','settings_coop']:self.put('tests/'+n+'.gd','extends SceneTree\nfunc _initialize():\n quit(0)\n')
  self.m={'schema':1,'full_after_days':7,'systems':{
   'foundation':{'label':'Core','files':['core.gd']},'seeds':{'label':'Seeds','files':['seeds.gd']},'weapons':{'label':'Weapons','files':['weapons.gd']},'settings':{'label':'Settings','files':['settings.gd']}},
   'asset_rules':{},'game_functions':{'plant':['seeds'],'strike':['weapons']},'suites':{
   'seeds':{'kind':'unit','systems':['seeds'],'package':True},'weapons':{'kind':'unit','systems':['seeds','weapons'],'package':True},'settings':{'kind':'unit','systems':['settings'],'package':True},'settings_coop':{'kind':'pair','systems':['settings'],'package':True}},'ignored_tests':{},'relationships':[]}
  self.save_map();self.flow=self.new();self.seed_passes()
 def put(self,path,text):
  p=self.p/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf-8')
 def save_map(self):w.write_json(self.p/'tools/test_map.json',self.m)
 def new(self):return w.Workflow(self.p,self.engine)
 def seed_passes(self):
  f=self.flow
  f.baseline={'at':w.utc(),'engine':f.engine_hash,'infrastructure':f.infrastructure,'tokens':copy.deepcopy(f.tokens)}
  w.write_json(f.root/'full-baseline.json',f.baseline)
  if not (f.root/'key-lineage.json').exists():w.write_json(f.root/'key-lineage.json',{'anchor':f.infrastructure,'runner':f.runner_signature(),'files':{}})
  for n in f.suites:
   log=f.root/(n+'.log');log.write_text('PASS: fixture\n')
   f.cache[n]={'passed':True,'key':f.keys[n],'logs':{log.name:w.digest(log.read_bytes())}}
  w.write_json(f.root/'cache.json',f.cache)
 def test_native_lock_editor_copies_are_not_runtime_inputs(self):
  folder='assets/native/persistence_lock/'
  library=folder+'b0_native_lock.dll'
  copies=[folder+'~b0_native_lock.dll',folder+'~b0_native_lock.dll~RF21d70d64.TMP']
  retained=[library,folder+'persistence_lock.gdextension',folder+'unrelated.TMP',
            folder+'~b0_native_lock.dll~RFnothex00.TMP',folder+'~b1_native_lock.dll',
            folder+'~b0_other.dll~RF21d70d64.TMP','assets/other/~b0_native_lock.dll~RF21d70d64.TMP']
  for name in copies+retained:self.put(name,'source input')
  flow=self.new()
  paths={path.relative_to(self.p).as_posix() for path in flow.runtime_files()}
  self.assertTrue(set(copies).isdisjoint(paths))
  self.assertTrue(set(copies).isdisjoint(flow.raw))
  self.assertTrue(set(retained)<=paths)
  self.assertTrue(set(retained)<=flow.raw.keys())
  original=flow.raw[library]
  self.put(library,'changed authoritative library')
  self.assertNotEqual(self.new().raw[library],original)

 def test_no_change_reuses_without_execution(self):
  f=self.new();plan=f.plan();self.assertEqual(plan['run_count'],0);self.assertTrue(f.release_ready())
 def test_seed_change_includes_weapon_consumers_not_settings(self):
  self.put('seeds.gd','extends RefCounted\nconst NEW=2\n');f=self.new();plan=f.plan()
  self.assertEqual({n for n,r in plan['selected'].items() if not r['cached']},{'seeds','weapons'});self.assertEqual(plan['effective'],'connected');self.assertFalse(f.release_ready())
 def test_scoped_body_change_does_not_change_contract(self):
  before=w.split_game((self.p/'game.gd').read_text());self.put('game.gd',(self.p/'game.gd').read_text().replace('return 1','return 3'));f=self.new()
  self.assertEqual(before['$contract'],w.split_game((self.p/'game.gd').read_text())['$contract']);self.assertEqual(f.plan()['effective'],'connected');self.assertTrue(f.valid('settings'));self.assertFalse(f.valid('seeds'))
 def add_world_scene(self):
  self.put('world.tscn','[ext_resource type="Script" path="res://game.gd" id="1"]\n')
  self.m['systems']['foundation']['files'].append('world.tscn')

 def test_audited_dispatcher_mutations_invalidate_direct_fixture_consumers(self):
  self.add_world_scene()
  source=('extends Node\nfunc graft_altar_open():\n return encounter_number % GRAFT_ROOM == 0\n'
          'func use_checkpoint(descend):\n return descend\n'
          'func strike_enemy(now, p):\n if now<int(p.strike_at): return\n')
  self.put('game.gd',source)
  cases={
   'graft_altar_open':('encounter_number % GRAFT_ROOM == 0','encounter_number % 9 == 0',
                       ('grafting_menu','menu_coop','shrines_hits')),
   'use_checkpoint':(' return descend',' if descend: return\n return descend',
                     ('core_combat','core_combat_coop','combat_balance_preview')),
   'strike_enemy':('if now<int(p.strike_at): return','if now>=int(p.strike_at): return',
                   ('combat_balance_preview','combat_balance_preview_coop','weapon_balance_preview','foundations','seed_progression')),
  }
  self.m['game_functions']={'graft_altar_open':['seeds'],'use_checkpoint':['seeds'],'strike_enemy':['weapons']}
  calls={}
  for function,(_,_,consumers) in cases.items():
   for name in consumers:calls.setdefault(name,[]).append(function)
  for name,functions in calls.items():
   self.m['suites'][name]={'kind':'pair' if name.endswith('_coop') else 'unit','systems':['settings'],'package':True}
   self.put(f'tests/{name}.gd','extends SceneTree\nvar game=load("res://world.tscn").instantiate()\nfunc run():\n'
            +''.join(f' game.{function}()\n' for function in functions))
  self.save_map();self.flow=self.new();self.seed_passes()
  for function,(old,new,consumers) in cases.items():
   with self.subTest(function=function):
    self.put('game.gd',source.replace(old,new));flow=self.new()
    token='game.gd::'+function
    plans=[flow.plan(),flow.plan(changed=[token])]
    for name in consumers:
     self.assertFalse(flow.valid(name))
     for plan in plans:
      self.assertFalse(plan['selected'][name]['cached'])
      self.assertIn(f'Fixture call: {token} via tests/{name}.gd',plan['selected'][name]['reasons'])
     self.assertEqual(name in flow.plan('focused')['selected'],flow.suites[name]['kind']=='unit')
    for name in set(calls)-set(consumers):self.assertTrue(flow.valid(name),name)
    self.assertTrue(flow.valid('settings'))

 def test_literal_fixture_helper_and_scoped_dispatcher_region(self):
  self.add_world_scene()
  self.put('tests/settings.gd','extends SceneTree\nconst Helper=preload("res://tests/helpers/fixture.gd")\n')
  self.put('tests/helpers/fixture.gd',"extends RefCounted\nvar world: Node = load('res://world.tscn').instantiate()\n"
           'func check():\n var callback=Callable(world, &"plant")\n world.callv("plant", [])\n'
           ' # world.strike()\n var example="""game.strike()\n another line"""\n other.strike()\n')
  self.m['game_regions']={'plant':{'adapter':{'match':'return 1','baseline':'return 0','systems':['seeds']}}}
  self.save_map();self.flow=self.new();self.seed_passes()
  self.assertTrue(self.new().valid('settings'))
  self.put('game.gd',(self.p/'game.gd').read_text().replace('return 2','return 9'))
  self.assertTrue(self.new().valid('settings'))
  self.put('game.gd',(self.p/'game.gd').read_text().replace('return 1','return 3').replace('return 9','return 2'))
  self.m['game_regions']['plant']['adapter']['match']='return 3';self.save_map()
  flow=self.new()
  self.assertEqual(flow.tokens['game.gd::plant'],self.flow.tokens['game.gd::plant'])
  self.assertFalse(flow.valid('settings'))
  self.assertTrue(flow.valid('settings_coop'))
  self.assertIn('Fixture call: game.gd::plant#adapter via tests/helpers/fixture.gd',flow.plan()['selected']['settings']['reasons'])

 def test_dynamic_dispatch_fallback_is_local_to_the_fixture(self):
  self.add_world_scene()
  self.put('tests/settings.gd','extends SceneTree\nvar game=load("res://world.tscn").instantiate()\n'
           'func dispatch(method):\n game.call_deferred(method)\n')
  self.save_map();self.flow=self.new();self.seed_passes()
  self.put('game.gd',(self.p/'game.gd').read_text().replace('return 2','return 3'))
  flow=self.new()
  self.assertFalse(flow.valid('settings'))
  self.assertTrue(flow.valid('settings_coop'))
  self.assertIn('Dynamic fixture call uses conservative game.gd coverage: tests/settings.gd',
                flow.plan()['selected']['settings']['reasons'])

 def test_inferred_tokens_preserve_evidence_already_covered_by_ownership(self):
  self.add_world_scene()
  fixture='extends SceneTree\nvar game=load("res://world.tscn").instantiate()\nfunc run():\n game.plant()\n'
  self.put('tests/seeds.gd',fixture)
  self.put('tests/settings.gd',fixture)
  self.save_map()
  with patch.object(w.Workflow,'fixture_dispatcher_calls',return_value=({},set())):
   self.flow=self.new();self.seed_passes()
  flow=self.new()
  self.assertTrue(flow.valid('seeds'))
  self.assertTrue(flow.valid('settings_coop'))
  self.assertFalse(flow.valid('settings'))

 def test_signature_rpc_and_late_global_changes_escalate(self):
  original=(self.p/'game.gd').read_text()
  for text in [original.replace('plant():','plant(value: int=0):'),original.replace('func plant','@rpc(\n "authority"\n)\nfunc plant'),original+'const NEW=2\n']:
   self.put('game.gd',text);self.assertEqual(self.new().plan()['effective'],'connected')
 def test_multiline_signature_is_global_contract(self):
  a='extends Node\nfunc plant(\n value: int=1\n):\n return value\n';b=a.replace('int=1','int=2')
  self.assertNotEqual(w.split_game(a)['$contract'],w.split_game(b)['$contract'])
 def test_preview_matches_foundation_and_dispatcher_contract_edits(self):
  self.put('project.godot','config_version=5\n')
  self.put('save_batch.gd','extends RefCounted\n')
  self.m['systems']['foundation']['files'].extend(['project.godot','save_batch.gd'])
  self.save_map();self.flow=self.new();self.seed_passes()
  baseline=self.new()
  original_game=(self.p/'game.gd').read_text()
  cases=[
   ('project.godot','project.godot','config_version=6\n'),
   ('save_batch.gd','save_batch.gd','extends RefCounted\nconst NEW=2\n'),
   ('game.gd::$contract','game.gd',original_game.replace('plant():','plant(value: int=0):')),
  ]
  for token,path,edited in cases:
   with self.subTest(token=token):
    plan=baseline.plan(changed=[token])
    self.assertFalse(plan['blocked'])
    original=(self.p/path).read_text()
    try:
     self.put(path,edited);after=self.new()
     invalidated={name for name,key in baseline.keys.items() if after.keys[name]!=key}
     self.assertEqual(invalidated,set(baseline.suites))
     self.assertEqual(set(plan['selected']),invalidated)
     self.assertEqual(set(plan['predicted_invalidations']),invalidated)
     self.assertTrue(all('Foundation input: '+token in row['reasons'] for row in plan['selected'].values()))
    finally:self.put(path,original)
  raw=baseline.plan('focused',changed=['game.gd'])
  self.assertTrue(raw['uncertain'])
  self.assertEqual(set(raw['predicted_invalidations']),set(baseline.suites))
  self.assertNotIn('settings_coop',raw['selected'])
  self.assertEqual(raw['reuse_count'],0)

 def test_new_function_and_unknown_runtime_escalate(self):
  self.put('game.gd',(self.p/'game.gd').read_text()+'func unknown():\n pass\n');self.assertEqual(self.new().plan()['effective'],'connected')
  self.put('new.gd','extends Node\n');self.assertTrue(any('Unmapped runtime' in x for x in self.new().plan()['escalation']))
 def test_deleted_file_escalates(self):
  (self.p/'settings.gd').unlink()
  with self.assertRaises(ValueError):self.new()
 def test_unmapped_suite_is_not_silently_skipped(self):
  self.put('tests/new_coop.gd','extends SceneTree\n');f=self.new();self.assertIn('new_coop',f.suites);self.assertEqual(f.plan()['effective'],'connected')
 def test_test_script_change_only_invalidates_its_suite(self):
  self.put('tests/settings.gd','extends SceneTree\n# new assertion\n');f=self.new();self.assertFalse(f.valid('settings'));self.assertTrue(f.valid('settings_coop'));self.assertEqual(f.plan()['run_count'],1)
 def test_generated_build_metadata_never_invalidates_source_cache(self):
  self.put('tests/settings.gd','extends SceneTree\nconst METADATA="res://assets/content/build_manifest.json"\n')
  self.put('assets/content/build_manifest.json','{"built_utc":"first-build"}')
  self.flow=self.new();self.seed_passes()
  self.put('assets/content/build_manifest.json','{"built_utc":"second-build"}')
  f=self.new();self.assertTrue(f.valid('settings'));self.assertEqual(f.plan()['run_count'],0)
 def test_literal_dependency_invalidates_consumer(self):
  self.put('tests/settings.gd','extends SceneTree\nconst Seeds=preload("res://seeds.gd")\n')
  self.flow=self.new();self.seed_passes();baseline=self.new()
  plan=baseline.plan(changed=['seeds.gd'])
  self.put('seeds.gd','extends RefCounted\n# changed\n');after=self.new()
  invalidated={name for name,key in baseline.keys.items() if after.keys[name]!=key}
  self.assertEqual(invalidated,{'seeds','weapons','settings'})
  self.assertEqual(set(plan['predicted_invalidations']),invalidated)
  self.assertEqual(set(plan['selected']),invalidated)
  self.assertIn('Literal resource: seeds.gd',plan['selected']['settings']['reasons'])
  self.assertTrue(after.valid('settings_coop'))
  self.assertFalse(after.valid('settings'))

 def test_unmapped_preview_is_blocked_and_real_run_stops_before_execution(self):
  baseline=self.new()
  for token in ('unclassified.gd','game.gd::unclassified'):
   with self.subTest(token=token):
    plan=baseline.plan(changed=[token])
    self.assertTrue(plan['blocked'])
    self.assertTrue(plan['uncertain'])
    self.assertEqual(set(plan['predicted_invalidations']),set(baseline.suites))
    self.assertTrue(any('Unmapped proposed input: '+token in reason for reason in plan['escalation']))
  self.put('unclassified.gd','extends Node\n')
  after=self.new()
  self.assertTrue(after.plan()['blocked'])
  with patch.object(after,'execute') as execute:
   with self.assertRaisesRegex(ValueError,'Classify unmapped inputs'):after.run('connected')
   execute.assert_not_called()

 def test_ordered_registry_routes_part_icons_and_generic_ui_separately(self):
  rules=w.read_json(MODULE.parent/'test_map.json')['asset_rules']
  self.m['asset_rules']={path:domains for path,domains in rules.items() if path in ('assets/ui/parts/**','assets/ui/**')}
  for system in ('items','presentation','progression'):
   self.m['systems'][system]={'label':system,'files':[]}
   self.m['suites'][system]={'kind':'unit','systems':[system],'package':True}
   self.put(f'tests/{system}.gd','extends SceneTree\n')
  cases={'assets/ui/parts/plant_bloodbriar.svg':{'items','presentation'},
         'assets/ui/root_frame.png':{'presentation','progression'}}
  for asset in cases:self.put(asset,'original')
  self.save_map();baseline=self.new()
  for asset,expected in cases.items():
   with self.subTest(asset=asset):
    self.assertEqual(set(baseline.owners(asset)),expected)
    plan=baseline.plan(changed=[asset])
    self.put(asset,'changed')
    try:
     after=self.new()
     changed={n for n,key in baseline.keys.items() if after.keys[n]!=key}
     self.assertEqual(changed,expected)
     self.assertEqual(set(plan['predicted_invalidations']),changed)
    finally:self.put(asset,'original')

 def test_unmatched_scopes_block_execution_and_release_even_with_cached_passes(self):
  self.put('settings.gd','extends Node\nconst LIVE=1\n')
  self.m['file_regions']={
   'settings.gd':{'regions':{
    'live':{'match':'const LIVE=1','baseline':'const LIVE=0','systems':['settings']},
    'shadowed':{'match':'LIVE=1','baseline':'LIVE=2','systems':['weapons']},
    'old':{'match':'missing()','baseline':'','systems':['settings']},
   }},
   'missing.gd':{'regions':{'old':{'match':'anything','baseline':'','systems':['settings']}}},
  }
  self.m['game_regions']={
   'plant':{'old':{'match':'missing()','baseline':'','systems':['seeds']}},
   'removed':{'old':{'match':'missing()','baseline':'','systems':['settings']}},
  }
  self.save_map();self.flow=self.new();self.seed_passes();flow=self.new()
  plan=flow.plan()
  self.assertTrue(plan['blocked'])
  expected={
   'Unmatched scope: settings.gd::#shadowed (shadowed by an earlier scope)',
   'Unmatched scope: settings.gd::#old (no match in the normalized file)',
   'Unmatched scope: missing.gd::#old (file is missing or excluded from the text snapshot)',
   'Unmatched scope: game.gd::plant#old (no match in the normalized function)',
   'Unmatched scope: game.gd::removed#old (no match in the normalized function)',
  }
  self.assertEqual(set(plan['escalation']),expected)
  self.assertTrue(all(flow.valid(n) for n in flow.suites))
  self.assertFalse(flow.release_ready())
  with self.assertRaisesRegex(ValueError,'Unmatched scope'):flow.verify()
  with patch.object(flow,'execute') as execute:
   with self.assertRaisesRegex(ValueError,'Unmatched scope'):flow.run('connected')
   execute.assert_not_called()

 def test_normalized_export_edit_has_explicit_preview_limit(self):
  self.m['systems']['foundation']['files'].append('export_presets.cfg')
  self.put('export_presets.cfg','export_path="old.exe"\n')
  self.save_map();self.flow=self.new();self.seed_passes()
  baseline=self.new();plan=baseline.plan(changed=['export_presets.cfg'])
  self.put('export_presets.cfg','export_path="new.exe"\n')
  self.assertEqual(self.new().keys,baseline.keys)
  self.assertTrue(plan['uncertain'])
  self.assertTrue(any('normalized away' in note for note in plan['notes']))

 def test_infrastructure_preview_reports_uncertainty_even_for_literal_fixture_input(self):
  self.put('test/helper.gd','extends RefCounted\n')
  self.put('tests/settings.gd','extends SceneTree\nconst Helper=preload("res://test/helper.gd")\n')
  flow=self.new()
  self.assertIn('resource:test/helper.gd',flow.input_keys['settings'])
  plan=flow.plan(changed=['test/helper.gd'])
  self.assertTrue(plan['uncertain'])
  self.assertFalse(plan['blocked'])
  self.assertEqual(set(plan['predicted_invalidations']),set(flow.suites))
  self.assertTrue(any('Validation infrastructure impact' in note for note in plan['notes']))
 def test_missing_or_modified_log_rejects_cached_pass(self):
  (self.flow.root/'settings.log').write_text('PASS: changed log\n');self.assertFalse(self.new().valid('settings'))
  (self.flow.root/'seeds.log').unlink();self.assertFalse(self.new().valid('seeds'))
 def test_engine_map_tools_changes_invalidate(self):
  self.engine.write_bytes(b'new-engine');self.assertEqual(self.new().plan()['effective'],'connected')
  self.put('tools/new.ps1','# unrelated planner wrapper');self.assertFalse(self.new().valid('settings')) # Engine still changed, so evidence remains invalid.
 def test_console_launcher_fingerprints_the_real_engine(self):
  launcher=self.engine.with_name('engine_console.exe');launcher.write_bytes(b'console-wrapper')
  first=w.Workflow(self.p,launcher).engine_hash
  self.engine.write_bytes(b'updated-real-editor')
  self.assertNotEqual(first,w.Workflow(self.p,launcher).engine_hash)
  self.engine.unlink()
  with self.assertRaises(ValueError):w.Workflow(self.p,launcher)
 def test_expired_baseline_requires_full(self):
  self.flow.baseline['at']='2001-01-01T00:00:00+00:00';w.write_json(self.flow.root/'full-baseline.json',self.flow.baseline);self.assertEqual(self.new().plan()['effective'],'connected')
 def test_focused_excludes_coop_then_connected_selects_it(self):
  self.put('settings.gd','extends RefCounted\n# changed');f=self.new();self.assertNotIn('settings_coop',f.plan('focused')['selected']);self.assertIn('settings_coop',f.plan('connected')['selected'])
 def test_foundation_cannot_be_bypassed_by_focused(self):
  self.put('core.gd','extends Node');self.assertEqual(self.new().plan('focused')['effective'],'focused')
 def test_document_only_preview_selects_nothing(self):self.assertEqual(self.new().plan(changed=['docs/notes.md'])['run_count'],0)
 def test_failed_retry_cannot_reuse_old_pass(self):
  f=self.new()
  with patch.object(f,'execute',return_value={'key':f.keys['settings'],'passed':False,'logs':{},'seconds':0}):self.assertFalse(f.run('connected',True))
  self.assertFalse(self.new().valid('settings'))
 def test_changed_inputs_during_run_discard_results(self):
  f=self.new()
  def execute(name,logdir):
   self.put('settings.gd','extends Node\n# edited mid-run');return {'key':f.keys[name],'passed':True,'logs':{},'seconds':0}
  with patch.object(f,'execute',side_effect=execute):self.assertFalse(f.run('connected',True))
  self.assertFalse(w.read_json(f.root/'latest-report.json')['stable_inputs'])
 def test_verification_refuses_stale_evidence(self):
  self.put('seeds.gd','extends Node')
  with self.assertRaises(ValueError):self.new().verify()
 def test_package_plan_reuses_only_matching_inputs(self):
  f=self.new();results={}
  for name in f.suites:
   log=f.root/('package-'+name+'.log');log.write_text('PASS: packaged fixture')
   results[name]=f.evidence_hashes([log])
  w.write_json(f.root/'package-cache.json',{'template':f.template_signature(),'keys':f.keys,'results':results})
  plan=f.package_plan();self.assertEqual(plan['selected']['unit'],[]);self.assertFalse(plan['full'])
  (f.root/'package-settings.log').write_text('altered evidence')
  self.assertIn('settings',f.package_plan()['selected']['unit'])
  self.put('settings.gd','extends Node');f=self.new()
  with self.assertRaises(ValueError):f.package_plan()
 def test_candidate_release_requires_fresh_package_evidence(self):
  self.m['suites']['settings']['candidate_release']=True;self.save_map()
  self.flow=self.new();self.seed_passes()
  f=self.new();results={}
  for name in f.suites:
   log=f.root/('candidate-'+name+'.log');log.write_text('PASS: fixture')
   results[name]=f.evidence_hashes([log])
  w.write_json(f.root/'package-cache.json',{'template':f.template_signature(),'keys':f.keys,'results':results})
  plan=f.package_plan()
  self.assertEqual(plan['selected']['unit'],['settings'])
  self.assertNotIn('settings',plan['reused'])
  plan['selected']['unit'].clear()
  w.write_json(f.root/'package-plan.json',plan)
  with self.assertRaisesRegex(ValueError,'Missing fresh candidate release evidence'):f.commit_package(self.engine)

 def test_export_template_change_forces_full_packaged_checks(self):
  f=self.new();w.write_json(f.root/'package-cache.json',{'template':'old-template','keys':{n:f.keys[n] for n in f.suites}})
  self.assertTrue(f.package_plan()['full'])
 def test_package_commit_rejects_changed_source(self):
  f=self.new();f.package_plan();self.put('seeds.gd','extends Node')
  with self.assertRaises(ValueError):self.new().commit_package(self.engine)
 def test_map_update_keeps_unrelated_evidence_and_adds_only_affected_suite(self):
  old=self.new().keys.copy();self.m['relationships'].append(['seeds','weapons','new explanation']);self.save_map();f=self.new()
  self.assertEqual(old,f.keys);self.assertEqual(f.plan()['run_count'],0)
  self.put('tests/new_seed.gd','extends SceneTree');self.m['suites']['new_seed']={'kind':'unit','systems':['seeds'],'package':True};self.save_map();f=self.new()
  self.assertTrue(f.valid('settings'));self.assertFalse(f.valid('new_seed'));self.assertEqual(f.plan()['run_count'],1)
 def test_full_is_explicit_and_never_reuses(self):
  plan=self.new().plan('full');self.assertEqual(plan['effective'],'full');self.assertEqual(plan['run_count'],4)
 def test_planner_only_changes_preserve_runtime_evidence(self):
  self.put('tools/test_map_notes.ps1','# UI for planning');f=self.new();self.assertTrue(f.valid('settings'));self.assertEqual(f.plan()['run_count'],0)
 def test_extracted_wiring_keeps_unrelated_dispatcher_evidence(self):
  self.m['game_functions']['plant']=['foundation'];self.save_map();self.flow=self.new();self.seed_passes()
  self.put('game.gd',(self.p/'game.gd').read_text().replace('return 1','return Helper.range'))
  self.m['game_regions']={'plant':{'gate':{'match':'return Helper.range','baseline':'return 1','systems':['seeds']}}};self.save_map();f=self.new()
  self.assertTrue(f.valid('settings'));self.assertFalse(f.valid('seeds'));self.assertEqual(f.plan()['effective'],'connected')
  self.put('game.gd',(self.p/'game.gd').read_text().replace('return 2','return 8'));self.assertFalse(self.new().valid('weapons'))
 def test_region_changes_and_removal_cannot_reuse_consumer_evidence(self):
  self.m['game_regions']={'plant':{'body':{'match':'return 1','baseline':'return 0','systems':['seeds']}}};self.save_map();self.flow=self.new();self.seed_passes()
  self.m['game_regions']['plant']['body']['match']='return 2';self.save_map();self.assertFalse(self.new().valid('seeds'))
 def test_scoped_file_dependency_and_location_are_not_ignored(self):
  self.put('tests/settings.gd','extends SceneTree\nconst UI=preload("res://settings.gd")\n');self.flow=self.new();self.seed_passes()
  hook='const Feature=preload("res://seeds.gd")\n';self.put('settings.gd','extends RefCounted\n'+hook)
  self.m['file_regions']={'settings.gd':{'newline':'crlf' if os.name=='nt' else 'lf','regions':{'feature':{'match':hook,'baseline':'','systems':['seeds']}}}};self.save_map();f=self.new()
  self.assertTrue(f.valid('settings'));self.assertFalse(f.valid('seeds'))
  base=f.plan(changed=['settings.gd'])
  self.assertTrue(base['uncertain'])
  self.put('settings.gd','extends RefCounted\n'+hook+'# base edit\n');base_edit=self.new()
  self.assertEqual(set(base['predicted_invalidations']),{n for n in f.keys if base_edit.keys[n]!=f.keys[n]})
  scoped=f.plan(changed=['settings.gd::#feature'])
  self.put('settings.gd',hook+'extends RefCounted\n');region_edit=self.new()
  self.assertNotEqual(f.keys['seeds'],region_edit.keys['seeds'])
  self.assertEqual(set(scoped['predicted_invalidations']),{n for n in f.keys if region_edit.keys[n]!=f.keys[n]})
  self.put('settings.gd',hook+'extends Node\n');self.assertFalse(self.new().valid('settings'))
 def test_scoped_file_preserves_mixed_baseline_line_endings(self):
  source=self.p/'settings.gd'
  baseline=b'extends RefCounted\r\n# LF in the published source\n# CRLF\r\n'
  source.write_bytes(baseline)
  self.flow=self.new();self.seed_passes()
  hook='const Feature=1\n'
  source.write_bytes(baseline+b'const Feature=1\r\n')
  self.m['file_regions']={'settings.gd':{'newline':'crlf','lf_lines':[2],'regions':{'feature':{
   'match':hook,'baseline':'','systems':['seeds']}}}}
  self.save_map();flow=self.new()
  self.assertEqual(flow.tokens['settings.gd'],w.digest(baseline))
  self.assertTrue(flow.valid('settings'));self.assertFalse(flow.valid('seeds'))
 def test_lock_blocks_concurrent_validation(self):
  with self.flow.locked():
   with self.assertRaises(ValueError):
    with self.flow.locked():pass
 @unittest.skipUnless(os.name=="nt","Windows validation mutex")
 def test_network_fixture_lock_excludes_an_independent_process(self):
  code = (
   "import sys\n"
   "sys.path.insert(0, sys.argv[1])\n"
   "from validation_execution import network_fixture_lock\n"
   "try:\n"
   " with network_fixture_lock(timeout_ms=120): print('acquired')\n"
   "except ValueError as error:\n"
   " print(error)\n"
   " sys.exit(7)\n"
  )
  command=[sys.executable,"-B","-c",code,str(MODULE.parent)]
  with w.execution.network_fixture_lock():
   blocked=w.subprocess.run(command,capture_output=True,text=True,timeout=10)
   self.assertEqual(blocked.returncode,7,blocked)
   self.assertIn("Timed out waiting",blocked.stdout)
  acquired=w.subprocess.run(command,capture_output=True,text=True,timeout=10)
  self.assertEqual(acquired.returncode,0,acquired)
  self.assertEqual(acquired.stdout.strip(),"acquired")
 def test_peer_runner_uses_powershell_seven(self):
  f=self.flow;f.suites['settings']['kind']='smoke';logdir=f.root/'peer-shell';logdir.mkdir()
  class Process:
   pid=1
   def __init__(self,args,**kwargs):
    self.args=args;self.returncode=0;kwargs['stdout'].write(b'PASS: fixture peer runner\n')
   def wait(self,**kwargs):return self.returncode
   def poll(self):return self.returncode
  with patch.object(w.shutil,'which',return_value=str(self.engine)),patch.object(w.subprocess,'Popen',Process),patch.object(w.execution,'verify_smoke_run',return_value=[]):
   result=f.execute('settings',logdir)
  self.assertTrue(result['passed'])
  with patch.object(w.shutil,'which',return_value=None),patch.dict(w.os.environ,{'USERPROFILE':str(self.p/'missing-runtime')}):
   with self.assertRaises(ValueError):f.execute('settings',logdir)

 def test_nonzero_exit_or_missing_marker_or_script_error_fails(self):
  class Process:
   pid=1
   def __init__(self,args,**kwargs):
    kwargs['stdout'].write(self.output);self.returncode=self.code
    env=kwargs['env']
    if self.payload is not None:
     result={'schema':1,'run_id':env['MYSTICAL_VALIDATION_RUN'],'fixture':env['MYSTICAL_VALIDATION_FIXTURE'],
             'peer':env['MYSTICAL_VALIDATION_PEER'],'status':'PASS','exit':0,'expected_engine_errors':[]}
     w.write_json(env['MYSTICAL_VALIDATION_RESULT'],dict(result,**self.payload))
   def wait(self,**kwargs):return self.returncode
   def poll(self):return self.returncode
  cases=[
   (0,b'PASS: complete\n',{},True),
   (1,b'PASS: misleading\n',{},False),
   (0,b'no marker\n',{},False),
   (0,b'PASS: misleading\nSCRIPT ERROR: failure\n',{},False),
   (0,b'PASS: misleading\nERROR: invalid node\n',{},False),
   (0,b'PASS: misleading\n',None,False),
   (0,b'PASS: misleading\n',{'run_id':'previous-run'},False),
   (0,b'PASS: misleading\n',{'fixture':'different_fixture'},False),
   (0,b'PASS: misleading\n',{'peer':'guest'},False),
   (0,b'PASS: misleading\n',{'expected_engine_errors':None},False),
   (0,b'PASS: expected\nERROR: Exact probe path.\n',{'expected_engine_errors':['Exact probe path.']},True),
   (0,b'PASS: unexpected duplicate\nERROR: Exact probe path.\nERROR: Exact probe path.\n',{'expected_engine_errors':['Exact probe path.']},False),
   (0,b'PASS: missing expected\n',{'expected_engine_errors':['Exact probe path.']},False),
  ]
  for i,(code,output,payload,expected) in enumerate(cases):
   with self.subTest(code=code,output=output,payload=payload):
    Process.code=code;Process.output=output;Process.payload=payload
    with patch.object(w.execution.subprocess,'Popen',Process),patch.object(w.execution,'stage_packaged_fixture_helpers',side_effect=AssertionError('source run staged package helpers')):
     result=self.flow.execute('settings',self.flow.root/f'execution-{i}')
    self.assertEqual(result['passed'],expected,result)

 def test_packaged_helpers_stage_recursive_test_only_closure(self):
  first = 'const Nested=preload("res://tests/helpers/nested.gd")\nconst Runtime=preload("res://settings.gd")\n'
  nested = 'const First=preload("res://tests/helpers/first.gd")\n'
  unused = 'extends RefCounted\n'
  self.put('tests/helpers/first.gd',first);self.put('tests/helpers/nested.gd',nested)
  self.put('tests/helpers/unused.gd',unused)
  source = 'extends SceneTree\nconst Helper=preload("res://tests/helpers/first.gd")\n'
  runtime = self.p/'external-package-fixture';runtime.mkdir()
  pack = self.p/'export.exe';pack.write_bytes(b'unchanged retail package')
  w.execution.stage_packaged_fixture_helpers(self.p,runtime,source)
  self.assertEqual({p.relative_to(runtime).as_posix() for p in runtime.rglob('*') if p.is_file()},
                   {'tests/helpers/first.gd','tests/helpers/nested.gd'})
  self.assertEqual((runtime/'tests/helpers/first.gd').read_text(),first)
  self.assertEqual((runtime/'tests/helpers/nested.gd').read_text(),nested)
  self.assertFalse((runtime/'settings.gd').exists())
  self.assertEqual((self.p/'tests/helpers/first.gd').read_text(),first)
  self.assertEqual((self.p/'tests/helpers/nested.gd').read_text(),nested)
  self.assertEqual(pack.read_bytes(),b'unchanged retail package')

 def test_packaged_startup_without_helpers_stages_nothing(self):
  runtime = self.p/'package-startup-fixture';runtime.mkdir()
  source = 'extends SceneTree\nconst Runtime=preload("res://settings.gd")\n'
  w.execution.stage_packaged_fixture_helpers(self.p,runtime,source)
  self.assertEqual(list(runtime.iterdir()),[])

 def test_packaged_helpers_reject_parent_traversal(self):
  runtime = self.p/'unsafe-package-fixture';runtime.mkdir()
  source = 'const Helper=preload("res://tests/../settings.gd")\n'
  with self.assertRaisesRegex(ValueError,'Unsafe fixture helper path'):
   w.execution.stage_packaged_fixture_helpers(self.p,runtime,source)
  self.assertEqual(list(runtime.iterdir()),[])

 def test_peer_stderr_errors_fail_and_stderr_pass_marker_is_insufficient(self):
  result={'schema':1,'run_id':'r','fixture':'fixture','peer':'host','status':'PASS','exit':0,'expected_engine_errors':[]}
  issues=w.execution.peer_issues('',result,'r','fixture','host',0,'PASS: printed on stderr')
  self.assertIn('missing fixture pass marker',issues)
  issues=w.execution.peer_issues('PASS: normal',result,'r','fixture','host',0,'ERROR: missing node')
  self.assertEqual(issues,['unexpected engine error (1): missing node'])

 def test_instrumentation_leaves_nested_scripts_and_comments_unchanged(self):
  source="extends SceneTree\nfunc run():\n var child = \"quit(5)\"\n # quit(2)\n quit(0)\n"
  result=w.execution.instrument(source.replace("\n","\r\n"))
  self.assertNotIn("\r",result)
  self.assertIn('var child = "quit(5)"',result)
  self.assertIn('# quit(2)',result)
  self.assertIn(' _validation_finish(0)',result)
  self.assertIn(' quit(code)',result)
  with self.assertRaisesRegex(ValueError,'no explicit quit'):
   w.execution.instrument('extends SceneTree\n# quit(0)')

 def test_package_commit_requires_structured_run_results(self):
  self.flow.package_plan()
  with self.assertRaisesRegex(ValueError,'missing, stale, or failed execution verdict'):
   self.flow.commit_package(self.engine)

 def test_multiline_adapter_preserves_unrelated_body_and_existing_region(self):
  source='extends Node\nfunc strike():\n var target=1\n return target\n'
  self.put('game.gd',source)
  self.m['game_regions']={'strike':{'old':{'match':'target=1','baseline':'target=0','systems':['weapons']}}}
  self.save_map();before=self.new().scoped_game(source)
  block=' if true:\n  preload("res://settings.gd").new()\n'
  self.m['game_regions']['strike']['garden']={'match':block,'baseline':'','systems':['settings'],'additive':True}
  patched=source.replace(' var target',block+' var target');self.put('game.gd',patched)
  self.save_map();after=self.new().scoped_game(patched)
  self.assertEqual(before[0],after[0])
  self.assertEqual(before[1]['game.gd::strike#old'],after[1]['game.gd::strike#old'])
  self.assertIn('game.gd::strike#garden',after[1])
  # An unclassified edit outside the adapter still invalidates the original body.
  changed=self.new().scoped_game(source.replace(' var target',block+' var target').replace('return target','return target+1'))
  self.assertNotEqual(after[0],changed[0])
 def test_relationships_validate_nodes_and_render_real_dependencies(self):
  (self.p/'docs').mkdir()
  self.m['relationships']=[['seeds','weapons','Plant parts alter weapon slots']];self.save_map()
  self.new().document()
  self.assertIn('seeds -->|"Plant parts alter weapon slots"| weapons',(self.p/'docs/MECHANICS_TEST_MAP.md').read_text(encoding='utf-8'))
  self.m['relationships']=[{'from':'seeds','to':'weapons','label':'broken shape'}];self.save_map()
  with self.assertRaisesRegex(ValueError,'Invalid system relationship'):self.new()
 def test_missing_additive_adapter_blocks_instead_of_reusing_evidence(self):
  self.m['game_regions']={'strike':{'garden':{'match':' absent()\n','baseline':'','systems':['settings'],'additive':True}}}
  self.save_map()
  with self.assertRaisesRegex(ValueError,'must match once'):self.new()

 def test_scoped_mesh_preserves_unrelated_dependency_but_checks_actual_visual_bytes(self):
  asset='assets/figure.glb';self.put(asset,'old mesh')
  self.put('tests/seeds.gd','extends SceneTree\nconst MODEL=preload("res://assets/figure.glb")\n')
  self.m['asset_rules'][asset]=['settings'];self.save_map();self.flow=self.new();self.seed_passes()
  old_source=self.flow.raw[asset];old_seed=self.flow.keys['seeds']
  self.m['binary_regions']={asset:{'baseline_sha256':old_source,'systems':['settings'],'contract':'Unchanged cosmetic skeleton interface'}};self.save_map()
  baseline=self.new();preview=baseline.plan(changed=[asset])
  self.put(asset,'new cosmetic mesh');f=self.new()
  self.assertEqual(set(preview['predicted_invalidations']),{name for name,key in baseline.keys.items() if f.keys[name]!=key})
  self.assertEqual(f.keys['seeds'],old_seed)
  self.assertTrue(f.valid('seeds'));self.assertFalse(f.valid('settings'))
  self.assertNotEqual(f.raw[asset],old_source)
  self.assertNotEqual(f.tokens[asset+'::#visual'],f.tokens[asset])
 def test_visual_mesh_contract_change_invalidates_visual_consumers(self):
  asset='assets/figure.glb';self.put(asset,'mesh')
  self.m['binary_regions']={asset:{'baseline_sha256':w.digest(b'mesh'),'systems':['settings'],'contract':'contract v1'}};self.save_map();self.flow=self.new();self.seed_passes()
  self.m['binary_regions'][asset]['contract']='contract v2';self.save_map();self.assertFalse(self.new().valid('settings'))
  self.m['binary_regions'][asset]['baseline_sha256']='not a verified hash';self.save_map()
  with self.assertRaisesRegex(ValueError,'Invalid visual asset boundary'):self.new()
 def test_scoped_mesh_edit_cannot_pass_stale_package_evidence(self):
  asset='assets/figure.glb';self.put(asset,'mesh')
  self.m['binary_regions']={asset:{'baseline_sha256':w.digest(b'mesh'),'systems':['settings'],'contract':'Stable skeleton'}};self.save_map();self.flow=self.new();self.seed_passes()
  self.flow.package_plan();self.put(asset,'edited after validation')
  with self.assertRaises(ValueError):self.new().commit_package(self.engine)

if __name__=='__main__':unittest.main()
