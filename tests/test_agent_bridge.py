"""임시 저장소로 인계 상태 전이와 리뷰 실패 경로를 검증한다."""

import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'skills/agent-bridge/scripts'))
from agent_bridge import parser, run
from bridge_store import load, locked, snapshot
from bridge_review import final_message


class BridgeTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.git('init')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'user.name', '테스트')
        (self.repo / 'a.txt').write_text('첫 상태\n', encoding='utf-8')
        self.git('add', '.')
        self.git('commit', '-m', '초기 상태')
        self.base = self.git('rev-parse', 'HEAD').strip()
        self.call('init', '--owner', 'codex:one', '--repo', str(self.repo), '--base', self.base,
                  '--goal', '검증', '--acceptance', '상태 보존')
        self.folder = self.root / 'state/task-1'

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], stderr=subprocess.DEVNULL).decode('utf-8')

    def call(self, *args):
        return run(parser().parse_args(['--root', str(self.root / 'state'), args[0], '--task', 'task-1', *args[1:]]))

    def handoff(self):
        notes = self.root / 'notes.md'
        notes.write_text('다음 행동: 테스트 실행\n', encoding='utf-8')
        self.call('handoff', '--owner', 'codex:one', '--to', 'claude:two', '--notes', str(notes))

    def change_commit(self):
        (self.repo / 'a.txt').write_text('새 상태\n', encoding='utf-8')
        self.git('add', '.')
        self.git('commit', '-m', '변경')

    def test_handoff_and_accept(self):
        self.handoff()
        with self.assertRaises(ValueError):
            self.call('accept', '--owner', 'claude:wrong')
        self.call('accept', '--owner', 'claude:two')
        self.assertEqual(load(self.folder)['owner'], 'claude:two')
        with self.assertRaises(ValueError):
            self.call('accept', '--owner', 'claude:two')

    def test_handoff_detects_untracked_content_change(self):
        untracked = self.repo / '새 파일.txt'
        untracked.write_text('aaa', encoding='utf-8')
        self.handoff()
        untracked.write_text('bbb', encoding='utf-8')
        with self.assertRaises(ValueError):
            self.call('accept', '--owner', 'claude:two')
        self.handoff()
        self.call('accept', '--owner', 'claude:two')

    def test_snapshot_detects_index_and_worktree_changes(self):
        original = snapshot(self.repo)
        (self.repo / 'a.txt').write_text('중간', encoding='utf-8')
        self.git('add', '.')
        staged = snapshot(self.repo)
        (self.repo / 'a.txt').write_text('마지막', encoding='utf-8')
        self.assertNotEqual(original, staged)
        self.assertNotEqual(staged, snapshot(self.repo))

    def test_lock_rejects_second_writer(self):
        with locked(self.folder):
            with self.assertRaises(ValueError):
                with locked(self.folder):
                    self.fail('중복 잠금')
        self.assertFalse((self.folder / '.lock').exists())

    def test_invalid_paths_and_duplicate_registration(self):
        with self.assertRaises(ValueError):
            self.call('init', '--owner', 'other', '--repo', str(self.repo), '--base', 'HEAD', '--goal', 'x', '--acceptance', 'y')
        with self.assertRaises(ValueError):
            run(parser().parse_args(['--root', str(self.root), 'status', '--task', '../escape']))
        with self.assertRaises(ValueError):
            run(parser().parse_args(['--root', str(self.repo), 'init', '--task', 'bad', '--repo', str(self.repo), '--base', 'HEAD', '--owner', 'x', '--goal', 'x', '--acceptance', 'y']))

    def test_dirty_review_rejected(self):
        (self.repo / 'dirty.txt').write_text('작업 중')
        with self.assertRaises(ValueError):
            self.call('review', '--owner', 'codex:one', '--runner', 'claude', '--dry-run')

    def test_dry_run_has_exact_commits_without_process(self):
        self.change_commit()
        with patch('bridge_review.execute') as execute:
            result, code = self.call('review', '--owner', 'codex:one', '--runner', 'claude', '--dry-run')
        execute.assert_not_called()
        self.assertEqual(code, 0)
        self.assertEqual(result['result']['status'], 'prepared')
        self.assertEqual(result['result']['base'], self.base)
        self.assertEqual(result['result']['head'], self.git('rev-parse', 'HEAD').strip())

    def mock_review(self, response, side_effect=None):
        with patch('bridge_review.shutil.which', return_value='agent.exe'), patch('bridge_review.execute', return_value=response, side_effect=side_effect):
            return self.call('review', '--owner', 'codex:one', '--runner', 'claude')

    def test_cli_failure_timeout_empty_and_success(self):
        self.change_commit()
        for response in [(1, '', '실패', False), (0, '', '', True), (0, '{}', '', False),
                         (0, json.dumps({'subtype': 'success', 'result': ''}), '', False)]:
            result, code = self.mock_review(response)
            self.assertEqual(code, 1)
            self.assertEqual(result['result']['status'], 'failed')
        output = json.dumps({'subtype': 'success', 'result': '결함 없음. 테스트 미실행.', 'session_id': 'review-1'})
        result, code = self.mock_review((0, output, '', False))
        self.assertEqual(code, 0)
        self.assertEqual(result['result']['session_id'], 'review-1')
        self.assertTrue((Path(result['folder']) / 'review.md').is_file())

    def test_review_becomes_stale_on_code_change(self):
        self.change_commit()
        def change(*args):
            (self.repo / 'a.txt').write_text('동시 변경', encoding='utf-8')
            return 0, json.dumps({'subtype': 'success', 'result': '리뷰'}), '', False
        result, code = self.mock_review(None, side_effect=change)
        self.assertEqual(code, 1)
        self.assertEqual(result['result']['status'], 'stale')

    def test_codex_requires_completed_event(self):
        lines = [json.dumps({'type': 'thread.started', 'thread_id': 's1'}),
                 json.dumps({'type': 'item.completed', 'item': {'type': 'agent_message', 'text': '리뷰'}})]
        with self.assertRaises(ValueError):
            final_message('codex', '\n'.join(lines))
        lines.append(json.dumps({'type': 'turn.completed'}))
        self.assertEqual(final_message('codex', '\n'.join(lines)), ('리뷰', 's1'))


if __name__ == '__main__':
    unittest.main()
