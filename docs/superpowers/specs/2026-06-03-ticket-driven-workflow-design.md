# 티켓 주도 워크플로우 설계

## 목표

업무 발화 기점을 Jira 티켓으로 이동. 대화 → 티켓(후처리) 방식에서 티켓 → 설계 → 구현 방식으로 전환. 장기적으로 티켓 URL 하나로 전체 플로우를 자동 처리할 수 있는 구조 마련.

---

## 페인포인트 (해결 대상)

1. 대화로 설계 후 Jira 티켓을 따로 만드는 이중작업
2. 티켓에 근거/히스토리가 충분히 남지 않아 추적 어려움
3. 자동화를 위한 단일 진입점 부재

---

## 전체 구조

### 진입점

- 대화 중 Jira URL 또는 티켓 키(예: `KURU-123`) 감지 시 자동 진입
- 명시적 커맨드(`/workflow KURU-123`) 방식도 병행 지원
- 실제 사용에서는 URL을 대화로 던지는 방식이 주요 경로

### 플로우

```
Step 0  티켓 진입    URL/키 감지 → 티켓 파싱 → context.md 생성 → 품질 리뷰 (게이트)
Step 1  셋업         공통 최신화 + 잔존 서버 정리 + 워크트리 생성
Step 2  설계         버그/경량: 생략 제안 → 사용자 확인 / 기능: 브레인스토밍
Step 3  플랜         구현 계획 작성 (버그: 경량 버전)
Step 4  구현+검증    코드 → 단위테스트 → 정적검증 루프
Step 5  리뷰         서브에이전트 코드 리뷰 (필수 — 기존 코드도 포함)
Step 6  PR+확인      PR 생성 → 티켓 remotelink 자동 연결 → 개발 서버 실행
Step 7  리뷰 루프    사용자 피드백 → 코드 개선 → 티켓 업데이트
Step 8  종결         티켓 Done → 컨플루언스 문서화 → 워크트리 제거
```

---

## Step별 상세

### Step 0. 티켓 진입 (게이트)

> 이 단계는 메모리 내에서만 처리. `context.md` 파일은 Step 1 워크트리 생성 후 작성.

1. URL 또는 키로 티켓 파싱 (curl REST API)
2. 품질 체크리스트 실행:
   - [ ] 목적/배경 (왜 하는지)
   - [ ] 완료 기준 (Acceptance Criteria)
   - [ ] 기술 범위 (FE / BE / 인프라)
   - [ ] 프로젝트별 추가 항목 (각 프로젝트 `skills/jira-tickets/SKILL.md` 오버라이드)
3. 미흡 항목 → Jira 코멘트 작성 + 작성자 멘션 → "보완 후 진행할까요?" 사용자 확인
4. 사용자가 override 선택 시 미흡 상태로도 진행 가능 (기록은 남김)
5. 티켓 충분 or 사용자 확인 → Step 1 진입

### Step 1. 셋업

**규칙:**
- `dev` / `main` 브랜치에서 직접 작업 절대 금지 — 반드시 워크트리 사용
- 워크트리는 서브 레포 내부 `worktrees/` 디렉토리에 생성
- 워크트리 생성 기준: 최신 원격 브랜치 (`origin/dev`) — 로컬 브랜치 기준 금지
- 크로스 레포 경로는 `REPO_ROOT` 패턴으로 동적 계산 — 하드코딩 금지

```bash
# 0. REPO_ROOT 설정 — 모든 크로스 레포 경로의 기준
#    (워크트리 내부 어디서 실행해도 항상 서브 레포 루트를 가리킴)
REPO_ROOT=$(git rev-parse --git-common-dir | xargs dirname)
COMMON_WORKFLOW="$REPO_ROOT/../agent-common-workflow"

# 1. 공통 워크플로우 최신화
git -C "$COMMON_WORKFLOW" pull

# 2. 잔존 서버 포트 확인 — 과도한 포트 점유 시 정리 후 진행
lsof -i :{port}                          # macOS
netstat -ano | findstr :{port}           # Windows
kill -9 {PID} / taskkill /PID {PID} /F

# 3. 워크트리 생성 — 서브 레포 내부에 생성
cd "$REPO_ROOT"
git fetch origin
git pull
git worktree add worktrees/{TICKET-ID}-{feature-en} -b feat/{TICKET-ID}-{feature-en} origin/dev
cd worktrees/{TICKET-ID}-{feature-en}
# 의존성 설치: 각 서브 레포의 skills/workflow-env/SKILL.md 참조

# 4. context.md 생성 — 워크트리 루트에 작성 (Step 0 파싱 내용 기반, 수동 편집 금지)
#    포맷은 아래 "context.md 구조" 섹션 참조
```

> `worktrees/` 디렉토리는 서브 레포 `.gitignore`에 추가 필요.

**네이밍 예시:**
- 디렉토리: `kuru-mart/worktrees/KURU-123-cart-redesign/`
- 브랜치: `feat/KURU-123-cart-redesign`

### Step 2. 설계

**버그 티켓 또는 경량 작업:**
- 에이전트가 브레인스토밍 생략 제안 → 사용자 확인
- 승인 시 Step 3으로 바로 진입

**기능 구현:**
- REQUIRED SKILL: `brainstorming`
- 브레인스토밍 과정은 로컬 MD에만 기록 (임시, Jira에 올리지 않음)
- 확정된 결정만 Jira description 업데이트 또는 코멘트로 기록 (변경 이유 한 줄 포함)

**Jira 문서화 원칙:**
- 의식의 흐름 → Jira에 남기지 않음
- 확정 결정 → Jira에 남김 (변경 시 이유 명시, 히스토리 유지)
- 브레인스토밍 과정 → 로컬 MD (커밋하지 않음)

### Step 3. 플랜

REQUIRED SKILL: `writing-plans`

- 기능 구현: 전체 플랜
- 버그/경량: 경량 버전 (파일, 변경 범위, 검증 방법 중심)
- 저장: `[워크트리]/docs/superpowers/plans/YYYY-MM-DD-<기능명>.md`

### Step 4. 구현 + 검증

테스트 및 정적 검증 명령어는 각 서브 레포의 `skills/workflow-env/SKILL.md` 참조.

- 단위 테스트: error 0개 필수
- 정적 검증: error 0개 필수 — 에이전트가 직접 실행, 사용자에게 떠넘기지 말 것

실패 시 코드 수정 후 재실행. 실패 상태에서 Step 5 진입 금지.

서브에이전트 모드: REQUIRED SKILL: `subagent-dev`
> `subagent-dev` 내부의 spec-reviewer / code-quality-reviewer는 태스크 단위 리뷰. Step 5는 전체 구현 완료 후 추가로 거치는 통합 리뷰.

### Step 5. 코드 리뷰 (필수)

전체 구현 완료 후 서브에이전트 통합 리뷰. `subagent-dev` 내부 태스크 단위 리뷰와 별개로 반드시 실행.

- 이미 작성된 코드, 기존 코드 수정분 모두 포함
- 리뷰 항목: 스펙 준수 여부, 코드 품질, 컨벤션 준수
- REQUIRED SKILL: `code-conventions`
- 이슈 발견 시 수정 후 재검증, 승인 후 Step 6 진입

### Step 6. PR + 결과 확인

```bash
git fetch origin dev && git merge origin/dev --no-edit  # 충돌 시 → 예외 C

# 커밋/푸시 전 — 기존 PR 상태 반드시 확인
gh pr list --head $(git branch --show-current) --state all
```

| PR 상태 | 조치 |
|---------|------|
| 없음 | `gh pr create --base dev` |
| OPEN | 생성 금지 — 기존 PR에 푸시만 |
| MERGED / CLOSED | 사용자 확인 후 결정 (닫힌 PR 재사용 금지) |

> **주의:** 커밋·푸시 시에도 위 확인 선행. CLOSED 상태인 PR이 있는데 새로 push하면 안 됨.

PR 생성 후:
- 티켓 remotelink 자동 연결 (PR URL + 제목)
- 클라이언트(UI) 프로젝트: 개발 서버 직접 실행 후 결과 제공 (서버 실행 전 기존 포트 정리)
- 서버 전용: 선택

### Step 7. 리뷰 루프

사용자 종결 선언 전까지:
- 피드백 반영 → 코드 개선
- Jira 코멘트 업데이트 (확정 변경 사항만)
- 정적 검증 + 서브에이전트 리뷰 반복

### Step 8. 종결

**순서대로:**

1. **티켓 Done 전환** + 구현 내용 코멘트 (PR 링크 포함)

```bash
REPO_ROOT=$(git rev-parse --git-common-dir | xargs dirname)
source "$REPO_ROOT/../agent-common-workflow/.env.local"
# 상태 Done 전환 + 코멘트 추가 — transition-id는 프로젝트 skills/jira-tickets/SKILL.md 참조
```

2. **컨플루언스 문서화** (사용자 확인):
   - 피쳐 구현 → 기획 문서 (비개발자 수준, `writing-policy` 7-a 준용)
   - 순수 개발 작업 → 기술 문서 (아키텍처/연동 구조, `writing-policy` 7-b 준용)
   - 연동 방식: 각 프로젝트 `skills/confluence/SKILL.md` 참조 (미존재 시 수동 게시 후 URL을 티켓 코멘트에 첨부)

3. **서버 종료 + 워크트리 제거** (사용자 확인):

```bash
kill -9 {PID} / taskkill /PID {PID} /F
git worktree remove worktrees/{TICKET-ID}-{feature-en}
```

나중에 하겠다고 하면 그대로 두고 종료.

---

## context.md 구조

세션 시작 시 Jira에서 자동 pull하여 생성. 수동 편집 금지. 세션 재개 시 재생성.

```markdown
# [TICKET-ID] 티켓 제목

## 티켓 정보
- 타입: Bug / Story / Task
- 우선순위: Highest / Medium / Low
- 담당자: ...
- 에픽: ...

## 확정 결정
- [2026-06-03] 결정 내용 — 변경 이유

## 연결된 PR
- PR #N: 제목 (URL)
```

---

## 신규/변경 스킬 목록

| 스킬 | 변경 내용 |
|------|----------|
| `workflow/SKILL.md` | 전면 재편 — Step 0 추가, 티켓ID 기반 네이밍, Step 5 리뷰 필수화 |
| `jira-tickets/SKILL.md` | 품질 리뷰 체크리스트 + context.md 생성 + intent 기반 동사 구조 추가 |
| `communication/SKILL.md` | 신규 — 커뮤니케이션 원칙 상세 |
| `code-conventions/SKILL.md` | 신규 — 클린코드/컨벤션 기준 상세 |
| `CLAUDE.md` | 커뮤니케이션 + 코드 컨벤션 핵심 규칙 요약 추가 |

---

## communication/SKILL.md 핵심 내용 (초안)

- 아부 금지 — 칭찬이 필요한 상황이 아니면 생략
- 객관적 피드백 — 사실 기반, 판단 근거 명시
- 사용자에게 직접 요청 전 10회 이상 자체 해결 시도
- 링크·서버·결과물은 직접 실행 후 결과를 사용자에게 제공 (확인 요청 금지)
- 확정되지 않은 내용을 확정처럼 말하지 않음

---

## code-conventions/SKILL.md 핵심 내용 (초안)

- DRY: 2개 이상 중복 함수/변수는 공통 분리 필수
- 적절한 디자인 패턴 사용 및 적용 이유 명시
- 파일/함수 단일 책임 원칙 준수
- 함수명·변수명으로 의도가 전달되어야 함 (주석 최소화)
- 서브에이전트 리뷰에서 컨벤션 위반 발견 시 수정 후 재검증

---

## 예외 경로

| 예외 | 조건 | 처리 |
|------|------|------|
| A. 경량 사이클 | 코드 변경 없는 설정·문서 수정 | Step 2·3 생략. 정적 검증 필수 |
| B. dev 직접 푸시 | 경량 사이클 + 사용자 명시 요청 | 워크트리 없이 직접 커밋 가능 |
| C. 머지 충돌 | `git merge` 충돌 | 충돌 해결 + 재검증 후 Step 6 재진입 |
| D. 세션 재개 | PR URL·브랜치명으로 재개 요청 | `worktrees/{TICKET-ID}-{feature-en}` 확인 → context.md 재생성 → 이어갈 Step 사용자 확인 |
| E. 티켓 없음 | 기존 대화 방식으로 진입 | Step 0 생략 → 브레인스토밍·플랜 진행 → Step 3 완료 후 티켓 생성 → Step 4 진입 |
