import contextlib, csv, hashlib, importlib.util, io, json, tempfile, unittest, zipfile
from pathlib import Path
from unittest.mock import patch

SPEC=importlib.util.spec_from_file_location('analysis',Path(__file__).with_name('analyze_session_logs.py'))
a=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(a)
def row(sid='s',seq=1,event='sample',category='network',data=None,context=None,utc='2026-11-10T03:00:00Z',level='info'):
 return {'schema':1,'session':sid,'seq':seq,'utc':utc,'elapsed_ms':seq*100,'category':category,'event':event,'level':level,'context':context or {},'data':data or {}}
def ctx(role,peer=1):return {'role':role,'peer':peer,'host_session':'host','world_session':'world','floor':1,'map_seed':123}
def feed(reader,rows,name='input/events.jsonl'):reader.feed(name,('\n'.join(json.dumps(r) for r in rows)+'\n').encode());return reader

class AnalysisTests(unittest.TestCase):
 def setUp(self):
  fixtures=Path(__file__).resolve().parents[2]/'.godot/log-analysis-tests';fixtures.mkdir(parents=True,exist_ok=True)
  self.temp=tempfile.TemporaryDirectory(dir=fixtures);self.root=Path(self.temp.name).resolve();self.assertEqual(self.root.parent,fixtures.resolve());self.addCleanup(self.temp.cleanup)
 def test_duplicates_are_counted_once_across_sources(self):
  r=feed(a.Reader(),[row()]);feed(r,[row()],'second/events.jsonl');self.assertEqual(r.duplicates,1);self.assertEqual(len(r.rows),1)
 def test_conflicting_sequence_is_flagged_not_silently_merged(self):
  r=feed(a.Reader(),[row(data={'x':1})]);feed(r,[row(data={'x':2})],'second/events.jsonl');self.assertEqual(len(r.conflicts),1);self.assertEqual(r.rows[('s',1)]['data']['x'],1)
 def test_latest_metadata_snapshot_wins_without_implying_crash(self):
  r=feed(a.Reader(),[row(event='report_requested')]);r.feed('early/session.json',json.dumps({'session':'s','last_seq':1,'clean_exit':True}).encode());r.feed('later/session.json',json.dumps({'session':'s','last_seq':10,'clean_exit':False}).encode())
  s=a.analyze(r)['sessions']['s'];self.assertFalse(s['metadata']['clean_exit']);self.assertIn('crash not established',s['exit_status']);self.assertEqual(s['missing_tail_events'],9)
 def test_rotation_gaps_do_not_imply_unfinished_action(self):
  r=feed(a.Reader(),[row(seq=20,event='action_end',category='interaction',data={'request_seq':19}),row(seq=25,event='sample')]);s=a.analyze(r)
  self.assertEqual(s['sessions']['s']['missing_head_events'],19);self.assertEqual(s['sessions']['s']['internal_gaps'],[{'from_seq':21,'to_seq':24}]);self.assertEqual(len(s['unmatched_actions']),0)
 def test_bad_lines_and_bad_nested_fields_are_reported(self):
  r=a.Reader();data=json.dumps(row())+'\n{truncated\n'+json.dumps(row(seq=2,data={'players':[]}))+'\n'+json.dumps(row(seq=3,context=['bad']))
  r.feed('events.jsonl',data.encode());self.assertEqual(len(r.rows),1);self.assertEqual(len(r.warnings),3)
 def test_metadata_only_session_is_visible(self):
  r=a.Reader();r.feed('session.json',b'{"session":"empty","last_seq":30}')
  result=a.analyze(r);self.assertEqual(result['sessions']['empty']['rows'],0);self.assertIn('no retained events',result['sessions']['empty']['label'])
 def test_health_matches_by_revision_despite_different_clocks(self):
  host=row('h',1,data={'players':{'7':{'hp':8,'damage_seq':2,'vitals_revision':3}}},context=ctx('Host'))
  guest=row('g',1,event='vitals_received',data={'states':{'7':{'hp':8,'damage_seq':2,'revision':3}}},context=ctx('Guest',7),utc='2026-11-10T06:00:00Z')
  result=a.analyze(feed(a.Reader(),[host,guest]));self.assertEqual(result['health_comparison']['matched'],1)
 def test_missing_host_revision_is_not_a_desync(self):
  guest=row('g',1,event='vitals_received',data={'states':{'7':{'hp':8,'damage_seq':2,'revision':3}}},context=ctx('Guest',7))
  h=a.analyze(feed(a.Reader(),[guest]))['health_comparison'];self.assertEqual(h['unavailable_host_revision'],1);self.assertEqual(h['mismatches'],[])
 def test_real_revision_conflict_is_reported_with_evidence(self):
  host=row('h',1,data={'players':{'7':{'hp':8,'damage_seq':2,'vitals_revision':3}}},context=ctx('Host'))
  guest=row('g',1,event='vitals_received',data={'states':{'7':{'hp':7,'damage_seq':2,'revision':3}}},context=ctx('Guest',7))
  h=a.analyze(feed(a.Reader(),[host,guest]))['health_comparison'];self.assertEqual(len(h['mismatches']),1);self.assertEqual(h['mismatches'][0]['host_ref']['seq'],1)
 def test_ambiguous_host_revision_is_not_declared_a_conflict(self):
  rows=[row('h',1,data={'players':{'7':{'hp':8,'damage_seq':2,'vitals_revision':3}}},context=ctx('Host')),row('h',2,data={'players':{'7':{'hp':9,'damage_seq':2,'vitals_revision':3}}},context=ctx('Host')),row('g',1,event='vitals_received',data={'states':{'7':{'hp':7,'damage_seq':2,'revision':3}}},context=ctx('Guest',7))]
  h=a.analyze(feed(a.Reader(),rows))['health_comparison'];self.assertEqual(h['ambiguous_host_revision'],1);self.assertEqual(h['mismatches'],[])
 def test_missing_guest_viewpoint_is_identified(self):
  rows=[row('h',1,data={'players':{'1':{},'7':{},'8':{}}},context=ctx('Host')),row('g',1,context=ctx('Guest',7))]
  result=a.analyze(feed(a.Reader(),rows));self.assertEqual(result['correlations'][0]['guest_peers_missing_viewpoint'],['8'])
 def test_revival_and_garden_restoration_are_separate(self):
  changes=[{'fallen':{'before':False,'after':True}}, {'fallen':{'before':True,'after':False},'lost_health':{'before':0,'after':2}}, {'fallen':{'before':True,'after':False},'lost_health':{'before':2,'after':0},'wild':{'before':True,'after':False}}]
  rows=[row('h',i+1,event='player_changed',category='state',data={'actor':7,'changes':c},context=ctx('Host')) for i,c in enumerate(changes)]
  party=a.analyze(feed(a.Reader(),rows))['party']['7'];self.assertEqual((party['downs'],party['revivals'],party['garden_restorations']),(1,1,1))
 def test_revival_reads_preview_hp_scale(self):
  changes={'fallen':{'before':True,'after':False},'lost_health':{'before':0,'after':20}}
  host=row('h',1,event='player_changed',category='state',data={'actor':7,'changes':changes,'hp_per_point':10},context=ctx('Host'))
  party=a.analyze(feed(a.Reader(),[host]))['party']['7'];self.assertEqual(party['revivals'],1)
 def test_healing_and_overkill_use_applied_values(self):
  rows=[
   row('h',1,event='damage_applied',category='combat',data={'actor':7,'amount':500,'applied_hp':69,'hp':0},context=ctx('Host')),
   row('h',2,event='damage_applied',category='combat',data={'actor':7,'amount':2},context=ctx('Host')),
   row('h',3,event='healing_applied',category='combat',data={'source':'renewal','party_slot':2,'rolled_hp':5,'applied_hp':3,'hp':80,'max_hp':80},context=ctx('Host')),
  ]
  reader=feed(a.Reader(),rows);report=a.analyze(reader)
  self.assertEqual(report['party']['7']['damage_recorded'],71)
  self.assertEqual(report['damage'][0]['amount'],500)
  self.assertEqual(report['damage'][0]['applied_hp'],69)
  self.assertIsNone(report['damage'][1]['applied_hp'])
  self.assertEqual(report['healing'][0]['applied_hp'],3)
  a.output(report,reader,self.root,a.UTC)
  with (self.root/'healing.csv').open(encoding='utf-8-sig') as f:
   self.assertEqual(next(csv.DictReader(f))['rolled_hp'],'5')
 def test_capacity_mismatch_at_same_revision_is_reported(self):
  host=row('h',1,data={'players':{'7':{'hp':80,'max_hp':80,'lost_health':20,'fallen':False,'damage_seq':2,'vitals_revision':3}}},context=ctx('Host'))
  guest=row('g',1,event='vitals_received',data={'states':{'7':{'hp':80,'max_hp':100,'lost_health':0,'fallen':False,'damage_seq':2,'revision':3}}},context=ctx('Guest',7))
  result=a.analyze(feed(a.Reader(),[host,guest]))['health_comparison']
  self.assertEqual(result['fields_compared'],['hp','damage_seq','max_hp','lost_health','fallen'])
  self.assertEqual(result['mismatches'][0]['differences']['max_hp'],{'guest':100,'host':80})
 def test_archives_are_read_without_extraction(self):
  archive=self.root/'input.zip'
  with zipfile.ZipFile(archive,'w') as z:z.writestr('../../escaped/events.jsonl',json.dumps(row())+'\n')
  reader=a.Reader().load([archive]);self.assertEqual(len(reader.rows),1);self.assertFalse((self.root.parent/'escaped').exists())
 def test_html_and_csv_escape_free_text(self):
  r=feed(a.Reader(),[row(event='user_issue',category='diagnostics',data={'note':'<script>alert(1)</script>'})]);result=a.analyze(r);a.output(result,r,self.root,a.UTC)
  self.assertNotIn('<script>',(self.root/'report.html').read_text());self.assertIn('&lt;script&gt;',(self.root/'report.html').read_text())
  a.write_csv(self.root/'escape.csv',[{'note':'=1+1'}],['note'])
  with (self.root/'escape.csv').open(encoding='utf-8-sig') as f:self.assertEqual(next(csv.DictReader(f))['note'],"'=1+1")
 def test_cli_preserves_inputs_and_writes_reports(self):
  source=self.root/'input';source.mkdir();file=source/'events.jsonl';file.write_text(json.dumps(row())+'\n');before=hashlib.sha256(file.read_bytes()).hexdigest();out=self.root/'output'
  with patch('sys.argv',['analyzer','--input',str(source),'--output',str(out),'--utc-offset=-05:00']),contextlib.redirect_stdout(io.StringIO()):self.assertEqual(a.main(),0)
  self.assertEqual(before,hashlib.sha256(file.read_bytes()).hexdigest());self.assertTrue((out/'summary.json').is_file())
  with patch('sys.argv',['analyzer','--input',str(source),'--output',str(source/'bad')]),contextlib.redirect_stderr(io.StringIO()):self.assertEqual(a.main(),1)

if __name__=='__main__':unittest.main()
