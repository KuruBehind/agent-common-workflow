// e2e-qa — 떠 있는 QA 브라우저(CDP)에 붙어 동작을 수행하고 스크린샷을 남긴다.
//
// 사용: node qa-act.mjs <shotName> '<JSON 동작 배열>'
//   결과 스크린샷: <QA_SHOT_DIR>/<QA_NAME>_<shotName>.png  (경로를 stdout 에 찍는다 — 반드시 Read 로 열어 볼 것)
//   동작 중 예외가 나면 <QA_NAME>_<shotName>_FAIL.png 을 남기고 종료 코드 1 로 끝난다.
// 환경변수(선택): QA_NAME(기본 qa) · QA_CDP_PORT(기본 9243) · QA_SHOT_DIR(기본 현재 디렉토리) · QA_TIMEOUT(요소 대기 ms, 기본 10000)
//   QA_TAB  동작 대상 탭을 고르는 URL 정규식 (기본: 마지막 탭). 예) QA_TAB=':8093/'  QA_TAB='hq\\.'
//           매칭되는 탭이 없으면 에러로 멈춘다(다른 서비스 탭에서 조작하는 사고 방지).
//
// 동작(순서대로 실행):
//   {"goto":"url"}                 이동                      {"wait":ms}             대기
//   {"click":[x,y]}                좌표 클릭(캔버스 앱용)    {"dblclick":[x,y]}
//   {"clickText":"文字"}           텍스트로 클릭(DOM 앱용)   {"clickSel":"css"}      셀렉터 클릭
//   {"type":"text"}                키 입력                   {"key":"Enter"}         키 누름
//   {"fill":["css","text"]}        입력란 채우기             {"scroll":[x,y,dy]}     해당 위치에서 휠
//   {"tab":"url정규식"}            이후 동작의 대상 탭 전환  {"newTab":"url"}        새 탭 열고 그 탭으로 전환
//   {"reload":true}                새로고침                  {"full":true}           마지막 스크린샷을 전체 페이지로
//   {"text":true}                  DOM 앱의 innerText 를 stdout 에 덤프(캔버스 앱은 비어 있음)
//   {"eval":"js"}                  페이지에서 평가, 결과 stdout
// playwright 는 스크립트 위치가 아니라 "실행한 디렉토리"(워크스페이스 루트)의 node_modules 에서 찾는다.
import { createRequire } from 'node:module';
const { chromium } = createRequire(process.cwd() + '/')('playwright');
import path from 'node:path';

const [name, json] = process.argv.slice(2);
if (!name) { console.error('usage: node qa-act.mjs <shotName> [json-actions]'); process.exit(2); }
const prefix = process.env.QA_NAME ?? 'qa';
const port = Number(process.env.QA_CDP_PORT ?? 9243);
const shotDir = process.env.QA_SHOT_DIR ?? process.cwd();

const browser = await chromium.connectOverCDP(`http://localhost:${port}`);
const ctx = browser.contexts()[0];
const pick = (re) => ctx.pages().find((p) => new RegExp(re).test(p.url()));
const listTabs = () => ctx.pages().map((p) => p.url()).join('\n  ');

// 콘솔 에러·경고는 탭을 바꿔도 계속 모은다(탭마다 리스너 1회).
const logs = [];
const watched = new WeakSet();
const watch = (p) => {
  if (watched.has(p)) return p;
  watched.add(p);
  p.on('console', (m) => { if (['error', 'warning'].includes(m.type())) logs.push(`[${new URL(p.url()).host}] ${m.type()}: ${m.text()}`); });
  return p;
};

let page;
if (process.env.QA_TAB) {
  page = pick(process.env.QA_TAB);
  if (!page) { console.error(`[e2e-qa] QA_TAB 에 맞는 탭 없음: ${process.env.QA_TAB}\n열린 탭:\n  ${listTabs()}`); process.exit(3); }
} else {
  page = ctx.pages().at(-1);
}
watch(page);
ctx.setDefaultTimeout(Number(process.env.QA_TIMEOUT ?? 10000)); // 셀렉터·텍스트 못 찾을 때 30초씩 기다리지 않게
let fullPage = false;

const shoot = async (suffix = '') => {
  const out = path.join(shotDir, `${prefix}_${name}${suffix}.png`);
  await page.screenshot({ path: out, fullPage });
  const size = await page.evaluate(() => [innerWidth, innerHeight]).catch(() => ['?', '?']);
  console.log(`[e2e-qa] ${page.url()} viewport=${size.join('x')} shot=${out}`);
  if (logs.length) console.log('[e2e-qa] console:\n' + logs.slice(-20).join('\n'));
};

try {
  for (const a of JSON.parse(json || '[]')) {
    if (a.goto) await page.goto(a.goto);
    else if (a.reload) await page.reload();
    else if (a.wait) await page.waitForTimeout(a.wait);
    else if (a.click) await page.mouse.click(a.click[0], a.click[1]);
    else if (a.dblclick) await page.mouse.dblclick(a.dblclick[0], a.dblclick[1]);
    else if (a.clickText) await page.getByText(a.clickText, { exact: false }).first().click();
    else if (a.clickSel) await page.locator(a.clickSel).first().click();
    else if (a.type) await page.keyboard.type(a.type, { delay: 60 });
    else if (a.key) await page.keyboard.press(a.key);
    else if (a.fill) await page.locator(a.fill[0]).first().fill(a.fill[1]);
    else if (a.scroll) { await page.mouse.move(a.scroll[0], a.scroll[1]); await page.mouse.wheel(0, a.scroll[2]); }
    else if (a.tab) { const p = pick(a.tab); if (!p) throw new Error(`탭 없음: ${a.tab}\n열린 탭:\n  ${listTabs()}`); page = watch(p); await page.bringToFront(); }
    else if (a.newTab) { page = watch(await ctx.newPage()); await page.goto(a.newTab); }
    else if (a.full) fullPage = true;
    else if (a.text) console.log(await page.evaluate(() => document.body.innerText));
    else if (a.eval) console.log(JSON.stringify(await page.evaluate(a.eval)));
    else throw new Error(`알 수 없는 동작: ${JSON.stringify(a)}`);
  }
} catch (e) {
  // 실패 순간의 화면을 남겨야 원인(오버레이·좌표 어긋남·미로딩)을 볼 수 있다.
  console.error(`[e2e-qa] 동작 실패: ${e.message}`);
  await shoot('_FAIL').catch((err) => console.error(`[e2e-qa] 실패 스크린샷도 실패: ${err.message}`));
  process.exit(1);
}

await shoot();
process.exit(0);
