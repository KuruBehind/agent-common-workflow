// e2e-qa — QA 전용 브라우저를 원격 디버깅 포트와 함께 띄운다(프로필 유지).
// 한 번 띄우면 로그인 상태가 프로필에 남으므로, 조작은 qa-act.mjs 가 CDP 로 붙어서 한다. 다시 띄우지 말 것.
//
// 사용: node qa-browser.mjs [시작 URL ...]
// 환경변수(모두 선택):
//   QA_NAME        프로필·스크린샷 접두사 (기본 qa)            예) KBO-820
//   QA_CDP_PORT    원격 디버깅 포트 (기본 9243)
//   QA_PROFILE_DIR 영구 프로필 경로 (기본 %TEMP%/claude/qa-browser-<QA_NAME>)
//   QA_WINDOW      창 크기 WxH (기본 1280x960) — Flutter 웹은 창 크기가 곧 뷰포트
// 시작 URL 을 여러 개 주면 서비스마다 탭을 하나씩 연다(HQ·BO·앱 연계 QA).
// 이 프로세스가 죽으면 브라우저도 닫히므로 Bash 도구의 run_in_background 로 띄운다(`&` 는 셸 종료 시 정리될 수 있음).
// 창 크기(QA_WINDOW)는 브라우저 UI 를 포함한다 — 실제 뷰포트는 qa-act.mjs 가 찍는 viewport= 값이 기준.
// playwright 는 스크립트 위치가 아니라 "실행한 디렉토리"(워크스페이스 루트)의 node_modules 에서 찾는다.
import { createRequire } from 'node:module';
const { chromium } = createRequire(process.cwd() + '/')('playwright');
import os from 'node:os';
import path from 'node:path';

const name = process.env.QA_NAME ?? 'qa';
const port = Number(process.env.QA_CDP_PORT ?? 9243);
const dir = process.env.QA_PROFILE_DIR ?? path.join(os.tmpdir(), 'claude', `qa-browser-${name}`);
const [w, h] = (process.env.QA_WINDOW ?? '1280x960').split('x').map(Number);
const urls = process.argv.slice(2);

const ctx = await chromium.launchPersistentContext(dir, {
  headless: false,
  viewport: null,
  args: [`--remote-debugging-port=${port}`, '--window-position=0,0', `--window-size=${w},${h}`],
});
const first = ctx.pages()[0] ?? (await ctx.newPage());
if (urls.length) {
  await first.goto(urls[0]);
  for (const u of urls.slice(1)) await (await ctx.newPage()).goto(u);
}
console.log(`[e2e-qa] ${name} launched — CDP ${port}, profile ${dir}, tabs ${urls.length || 1}`);
await new Promise(() => {}); // 프로세스를 살려 두어야 브라우저가 유지된다 (run_in_background 로 실행)
