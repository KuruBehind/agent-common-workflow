// e2e-qa — 떠 있는 QA 브라우저를 CDP 로 닫는다(프로필은 남긴다 → 다음 세션에 로그인 유지).
//
// 사용: node qa-stop.mjs           환경변수(선택): QA_CDP_PORT(기본 9243)
// 왜 필요한가: qa-browser.mjs(node) 프로세스를 kill 해도 Windows 에서는 Chrome 자식 프로세스가 살아남아
//   포트·프로필을 계속 점유한다(2026-10-26 실측). 전역 chrome 종료는 금지이므로 이 QA 브라우저만 CDP 로 닫는다.
// playwright 는 "실행한 디렉토리"(워크스페이스 루트)의 node_modules 에서 찾는다.
import { createRequire } from 'node:module';
const { chromium } = createRequire(process.cwd() + '/')('playwright');

const port = Number(process.env.QA_CDP_PORT ?? 9243);
let browser;
try {
  browser = await chromium.connectOverCDP(`http://localhost:${port}`, { timeout: 5000 });
} catch {
  console.log(`[e2e-qa] CDP ${port} 에 브라우저 없음 — 이미 닫힘`);
  process.exit(0);
}
const session = await browser.newBrowserCDPSession();
await session.send('Browser.close').catch(() => {}); // 닫히면서 연결이 끊겨 에러가 날 수 있음
console.log(`[e2e-qa] CDP ${port} 브라우저 닫음`);
process.exit(0);
