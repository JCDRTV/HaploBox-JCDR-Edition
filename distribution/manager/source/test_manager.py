import tempfile, unittest
from pathlib import Path
from unittest.mock import patch
import manager as m
class TestManager(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); base=Path(self.tmp.name); self.root=base/'game'; self.home=base/'backup'
        self.a='WTF/Account/A/Realm/Foo'; self.b='WTF/Account/B/Realm/Bar'; self.c='WTF/Account/B/Realm/Baz'
        for name in [self.a,self.b,self.c]:
            p=self.root/name; p.mkdir(parents=True); (p/'SavedVariables').mkdir(); (p/'SavedVariables'/'Questie.lua').write_text(name)
        (self.root/self.a/'layout-local.txt').write_text('new'); (self.root/self.b/'layout-local.txt').write_text('old')
    def tearDown(self): self.tmp.cleanup()
    def plan(self): return m.plan(self.root,self.a,[self.b,self.c],['Blizzard frame positions'])
    def test_scan_copy_restore(self):
        self.assertEqual(set(m.characters(self.root)),{self.a,self.b,self.c}); rows=self.plan(); self.assertEqual(len(rows),2)
        self.assertFalse((self.root/self.c/'layout-local.txt').exists()); backup=m.execute(self.root,rows,self.home,lambda:None)
        for t in [self.b,self.c]: self.assertEqual((self.root/t/'layout-local.txt').read_text(),'new'); self.assertEqual((self.root/t/'SavedVariables'/'Questie.lua').read_text(),t)
        m.restore(self.root,backup,self.home,lambda:None); self.assertEqual((self.root/self.b/'layout-local.txt').read_text(),'old'); self.assertFalse((self.root/self.c/'layout-local.txt').exists())
    def test_stale_preview(self):
        rows=self.plan(); (self.root/self.a/'layout-local.txt').write_text('changed')
        with self.assertRaises(ValueError): m.execute(self.root,rows,self.home,lambda:None)
        self.assertEqual((self.root/self.b/'layout-local.txt').read_text(),'old')
    def test_block_source(self):
        with self.assertRaises(ValueError): m.plan(self.root,self.a,[self.a],['Blizzard frame positions'])
    def test_block_unknown(self):
        with self.assertRaises(ValueError): m.plan(self.root,self.a,[self.b],['Questie.lua'])
    def test_closed_guard(self):
        def fail(): raise RuntimeError('WoW open')
        with self.assertRaises(RuntimeError): m.execute(self.root,self.plan(),self.home,fail)
        self.assertFalse(self.home.exists())
    def test_restore_conflict(self):
        b=m.execute(self.root,self.plan(),self.home,lambda:None); (self.root/self.b/'layout-local.txt').write_text('changed')
        with self.assertRaises(ValueError): m.restore(self.root,b,self.home,lambda:None)
        self.assertEqual((self.root/self.b/'layout-local.txt').read_text(),'changed')
    def test_rollback(self):
        original=m.atomic
        def fail(path,data):
            if path==self.root/self.c/'layout-local.txt': raise OSError('simulated write failure')
            return original(path,data)
        with patch.object(m,'atomic',side_effect=fail):
            with self.assertRaises(OSError): m.execute(self.root,self.plan(),self.home,lambda:None)
        self.assertEqual((self.root/self.b/'layout-local.txt').read_text(),'old'); self.assertFalse((self.root/self.c/'layout-local.txt').exists())
    def test_symlink(self):
        p=self.root/self.c/'layout-local.txt'; p.symlink_to(self.root/self.a/'layout-local.txt')
        with self.assertRaises(ValueError): self.plan()
    def test_duplicate(self): self.assertEqual(len(m.plan(self.root,self.a,[self.b,self.b],['Blizzard frame positions'])),1)
if __name__=='__main__': unittest.main(verbosity=2)
