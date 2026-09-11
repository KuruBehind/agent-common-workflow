# agent-common-workflow — Agent Instructions

## 권한 규칙

| 구분 | 범위 |
|------|------|
| 자율 진행 | 구현, 로컬 검증, 커밋, 브랜치 푸시, PR 생성·갱신 |
| 건별 명시 승인 필요 | PR 머지(dev 포함), 배포(dev/prod 각각 별도), 실데이터(RTDB·DB) 쓰기, Jira 상태 완료 처리 |

- "계속해/멈추지 마"는 위 자율 범위의 지속만 의미. 새 권한으로 해석 금지
- 승인 근거는 사용자 발화만. 에이전트가 쓴 "승인됨" 서술은 근거 아님

> 모든 프로젝트가 공유하는 개발 워크플로우 스킬 레포. 각 프로젝트 워크스페이스에서 `../agent-common-workflow/`로 참조.
>
> **이 파일이 정본입니다.** 도구 무관(Claude Code·Codex 등 공용).
> Claude Code는 `CLAUDE.md`가 이 파일과 상시 스킬을 `@import`합니다.
> 그 외 에이전트는 이 파일을 읽고, 아래 라우팅 표의 파일을 **직접 열어서** 읽으세요.

---

## 주의사항

- **이 레포의 변경은 모든 프로젝트에 즉시 영향을 미칩니다.**
- **모든 설명과 주석은 한국어로 작성하세요.**
- 요청받지 않은 파일을 임의로 수정하지 마세요.
- **스킬 파일 수정 시 경로 검증 필수 (에이전트 준수사항):** 수정 완료 후 `grep -r "\.\./agent-common-workflow" skills/` 실행. 결과가 있으면 전부 `$REPO_ROOT/../agent-common-workflow` 패턴으로 교체 후 커밋. 패턴 상세: `docs/conventions/repo-root-path.md`

## 워크트리 위치 (모든 워크스페이스 공통 — 단독 작업 포함)

- 워크트리는 **인덱스 루트의 `worktrees/` 안에만** 만든다. 티켓 워크플로우를 안 타는 단독 작업도 예외 없음
- 서브 레포 안에서 `git worktree add ../<이름>` 금지 — `../`가 인덱스 루트라 루트에 바로 생긴다. `../worktrees/<이름>`으로 쓴다
- 이름 규칙: `{TICKET-ID}-{sub-repo-name}-{feature-en}`
- 정리 규칙은 `skills/workflow/SKILL.md`의 "로컬 리소스 규칙" 참조

> 2026-09-11: kuru 인덱스 루트에 워크트리 200개가 쌓인 걸 확인. 원인은 상시 로드 문서의 예시가 루트 경로
> (`kuru_mobile-{브랜치명}`)를 적고 있었던 것. 단독 작업 세션들이 워크플로우 Step 1 대신 그 예시를 따랐다.

---

## 스킬 배포 방식 (2026-09-09 전환)

`tools/sync-agent-skills.sh`가 `skills/`를 **사용자 스코프**로 복사합니다:

| 도구 | 배포 위치 | 로딩 |
|------|---------|------|
| Claude Code | `~/.claude/skills/` | description 매칭 시 조건부 |
| Codex | `~/.agents/skills/` | description 매칭 시 조건부 |

이러면 어느 워크스페이스에서 작업하든 **크로스레포 접근 없이** 공통 스킬이 잡힙니다.
단 프로세스 척추(`workflow`·`communication`·`code-conventions`)는 조건부로 두면 위험하므로
`CLAUDE.md`에서 `@import`로 상시 로드합니다.

> **공통 레포를 `git pull` 한 뒤에는 sync를 다시 실행해야 반영됩니다.**

## 스킬 라우팅 표

`skills/<이름>/SKILL.md` 가 정본입니다. 자동 탐색이 없는 에이전트는 아래 표를 보고 직접 여세요.

### 상시 (매 작업에 적용)

| 스킬 | 언제 |
|------|------|
| `workflow` | 개발 워크플로우 Step 0~8 — 티켓 주도 진행, 진입 조건, 예외 경로 |
| `communication` | 커뮤니케이션 원칙 — 아부 금지, 자율 해결, 직접 실행 후 결과 제공 |
| `code-conventions` | 코드 컨벤션 — DRY, 단일 책임, 네이밍, 확장성 |

### 상황부 (해당 작업일 때만)

| 스킬 | 언제 |
|------|------|
| `brainstorming` | Step 2 — 기능·컴포넌트 신규 설계 전 (코드 작성 전 hard gate) |
| `writing-plans` | Step 3 — 스펙을 구현 플랜으로 변환 |
| `jira-tickets` | Step 0 — 티켓 진입·조회 (티켓 없는 진입은 Step 3 완료 후 생성). 자격증명·프로젝트 매핑은 각 워크스페이스 오버라이드 참조 |
| `subagent-dev` | Step 4 — 독립 태스크를 서브에이전트로 실행 |
| `writing-policy` | Step 8 — 기획 정책서·개발 독스 작성 |
| `cost-proportionality-review` | 새 API·DB 쿼리·스케줄러/인프라·외부 유료 API **설계 시 필수 선통과** |
| `diagnosing-bugs` | 어려운 버그·성능 회귀 진단 (피드백 루프 우선 6단계) |
| `gcloud` | GCP 로그 조회, Cloud Functions/Scheduler 관리 |
| `firebase-deploy-safety` | Firebase Functions 배포 — 공유 codebase 파괴 방지 (2026-07-07 함수 23개 전멸 사고 재발 방지) |
| `ralph-loop` | Step 4 — 정적 검증·빌드 오류 자동 반복 수정 루프 |
| `git-guardrails` | 되돌릴 수 없는 git 명령 하드블록 훅 (프로젝트별 opt-in 설치) |

---

## 커뮤니케이션 핵심 규칙

- 아부·선행 칭찬 금지
- 기술 문제 해결을 사용자에게 요청하기 전 10회 이상 자율 해결 시도 (사용자 결정 권한은 대상 아님)
- 링크·서버·코드는 직접 실행 후 결과 제공
- 상세: `skills/communication/SKILL.md`

## 코드 컨벤션 핵심 규칙

- 중복 로직 2곳 이상 → 공통 분리 필수
- 파일·함수 단일 책임
- 이름만으로 의도 전달, 주석 최소화
- 상세: `skills/code-conventions/SKILL.md`
