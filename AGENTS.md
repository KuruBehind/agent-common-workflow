# agent-common-workflow — Agent Instructions

> 모든 프로젝트가 공유하는 개발 워크플로우 스킬 레포. 각 프로젝트 워크스페이스에서 `../agent-common-workflow/`로 참조.
>
> **이 파일이 정본입니다.** 도구 무관(Claude Code·Codex 등 공용).
> Claude Code는 `CLAUDE.md`가 이 파일과 상시 스킬을 `@import`합니다.
> 그 외 에이전트는 이 파일을 읽고, 아래 라우팅 표의 파일을 **직접 열어서** 읽으세요.

---

## 주의사항

- **이 레포의 변경은 모든 프로젝트에 즉시 영향을 미칩니다.** 스킬 수정 전 반드시 사용자에게 확인. 수정 전 `git pull`, 수정 후 main에 커밋/푸시.
- **모든 설명과 주석은 한국어로 작성하세요.**
- 요청받지 않은 파일을 임의로 수정하지 마세요.
- **스킬 파일 수정 시 경로 검증 필수 (에이전트 준수사항):** 수정 완료 후 `grep -r "\.\./agent-common-workflow" skills/` 실행. 결과가 있으면 전부 `$REPO_ROOT/../agent-common-workflow` 패턴으로 교체 후 커밋. 패턴 상세: `docs/conventions/repo-root-path.md`

---

## 스킬 라우팅 표

`skills/<이름>/SKILL.md` 경로에 있습니다. Claude Code는 상시 항목을 `CLAUDE.md`에서 자동 주입하므로 수동 참조가 불필요합니다.

### 상시 (매 작업에 적용)

| 스킬 | 언제 |
|------|------|
| `workflow` | 개발 워크플로우 Step 0~8 — 티켓 주도 진행, 진입 조건, 예외 경로 |
| `communication` | 커뮤니케이션 원칙 — 아부 금지, 자율 해결, 직접 실행 후 결과 제공 |
| `code-conventions` | 코드 컨벤션 — DRY, 단일 책임, 네이밍, 확장성 |

### 상황부 (해당 작업일 때만)

| 스킬 | 언제 |
|------|------|
| `brainstorming` | Step 0a — 기능·컴포넌트 신규 설계 전 (코드 작성 전 hard gate) |
| `writing-plans` | Step 0b — 스펙을 구현 플랜으로 변환 |
| `jira-tickets` | Step 0c — 티켓 생성·조회. 자격증명·프로젝트 매핑은 각 워크스페이스 오버라이드 참조 |
| `subagent-dev` | Step 2 — 독립 태스크를 서브에이전트로 실행 |
| `writing-policy` | Step 7 — 기획 정책서·개발 독스 작성 |
| `cost-proportionality-review` | 새 API·DB 쿼리·스케줄러/인프라·외부 유료 API **설계 시 필수 선통과** |
| `diagnosing-bugs` | 어려운 버그·성능 회귀 진단 (피드백 루프 우선 6단계) |
| `gcloud` | GCP 로그 조회, Cloud Functions/Scheduler 관리 |
| `firebase-deploy-safety` | Firebase Functions 배포 — 공유 codebase 파괴 방지 (2026-07-07 함수 23개 전멸 사고 재발 방지) |
| `ralph-loop` | Step 4 — 정적 검증·빌드 오류 자동 반복 수정 루프 |
| `git-guardrails` | 되돌릴 수 없는 git 명령 하드블록 훅 (프로젝트별 opt-in 설치) |

---

## 커뮤니케이션 핵심 규칙

- 아부·선행 칭찬 금지
- 사용자 요청 전 10회 이상 자율 해결 시도
- 링크·서버·코드는 직접 실행 후 결과 제공
- 상세: `skills/communication/SKILL.md`

## 코드 컨벤션 핵심 규칙

- 중복 로직 2곳 이상 → 공통 분리 필수
- 파일·함수 단일 책임
- 이름만으로 의도 전달, 주석 최소화
- 상세: `skills/code-conventions/SKILL.md`
