---
name: workflow
description: "개발 워크플로우 — 항상 활성. 티켓 주도 Step 0~8, 진입 조건, 예외 경로를 정의합니다."
---

# 개발 워크플로우

## 레포 구조 전제

```
[workspace]/
├── agent-common-workflow/
├── [index-repo]/
└── [sub-repo]/
    └── worktrees/
        └── {TICKET-ID}-{sub-repo-name}-{feature-en}/   ← 워크트리
```

서브 레포가 없으면: `git clone git@github.com:{org}/{sub-repo}.git ../{sub-repo}`
레포명 불확실하면 사용자에게 확인.

### 경로 규칙

- 워크트리는 **인덱스 레포 내부 `worktrees/`** 에 생성 — 서브 레포 내부에 생성 금지 (운영 레포 오염 방지)
- 크로스 레포 경로는 `REPO_ROOT` 패턴으로 동적 계산 — 하드코딩 금지
- `dev` / `main` 직접 작업 절대 금지

```bash
# 모든 크로스 레포 명령어 앞에 선행
REPO_ROOT=$(git rev-parse --git-common-dir | xargs dirname)
```

---

## 실행 순서

```
Step 0  티켓 진입    URL/키 감지 → 티켓 파싱 → 품질 리뷰 (게이트)
Step 1  셋업         공통 최신화 + 서버 정리 + 워크트리 생성 + context.md 생성
Step 2  설계         버그/경량: 생략 제안 → 사용자 확인 / 기능: 브레인스토밍
Step 3  플랜         구현 계획 작성 (버그: 경량 버전)
Step 4  구현+검증    코드 → 단위테스트 → 정적검증 루프
Step 5  리뷰         서브에이전트 코드 리뷰 (필수 — 기존 코드 포함)
Step 6  PR+확인      PR 생성 → 티켓 remotelink 연결 → 개발 서버 실행
Step 7  리뷰 루프    사용자 피드백 → 코드 개선 → 티켓 업데이트
Step 8  종결         티켓 Done → 컨플루언스 문서화 → 워크트리 제거
```

**규칙:**
- step 전환 시 번호 명시. 건너뛰기·자의적 생략 금지.
- Step 4 검증 실패 → 코드 수정 후 재검증. 실패 상태에서 Step 5 진입 금지.
- 실행 환경(PATH, lint 명령어)은 `skills/workflow-env/SKILL.md` 참조.

---

## Step 0. 티켓 진입 (게이트)

대화 중 Jira URL 또는 티켓 키(`KURU-123`) 감지 시 자동 진입.

> 이 단계는 메모리 내 처리. `context.md` 파일은 Step 1 워크트리 생성 후 작성.

**REQUIRED SKILL:** `jira-tickets` → "티켓 품질 리뷰" 섹션 실행

1. URL 또는 키로 티켓 파싱 (curl REST API)
2. 품질 체크리스트 실행 (jira-tickets 스킬 참조)
3. 미흡 항목 → Jira 코멘트 + 작성자 멘션 → "보완 후 진행할까요?" 사용자 확인
4. 사용자 override 또는 티켓 충분 → Step 1 진입

---

## Step 1. 셋업

### 서브 레포 탐색

경로가 명확하지 않으면 **인덱스 레포의 `CLAUDE.md`** (이미 컨텍스트에 로드됨) 서브프로젝트 목록에서 확인.
프로젝트 키·티켓 내용으로 매칭 판단. 명확하면 자동 진행, 애매하면 사용자 확인. 없으면 `git clone` 후 진행.

---

```bash
REPO_ROOT=$(git rev-parse --git-common-dir | xargs dirname)
INDEX_REPO=$(cd "$REPO_ROOT/.." && pwd)
WORKSPACE_ROOT=$(cd "$INDEX_REPO/.." && pwd)
# 유형 A(플랫) / B(중첩) 모두 대응 — docs/conventions/repo-root-path.md 참조
if [ -f "$WORKSPACE_ROOT/agent-common-workflow/.env.local" ]; then
  CW="$WORKSPACE_ROOT/agent-common-workflow"
else
  CW="$INDEX_REPO/agent-common-workflow"
fi

# 1. 공통 워크플로우 최신화
git -C "$CW" pull

# 2. 잔존 서버 포트 확인 — 과도한 포트 점유 시 정리 후 진행
lsof -i :{port}                          # macOS — 포트는 서브 레포 CLAUDE.md 참조
netstat -ano | findstr :{port}           # Windows
kill -9 {PID} / taskkill /PID {PID} /F

# 3. 인덱스 레포의 worktrees/ 에 생성
#    인덱스 레포 = 서브 레포의 부모 디렉토리 (예: kuru/)
INDEX_REPO=$(cd "$REPO_ROOT/.." && pwd)   # 서브 레포의 부모 = 인덱스 레포
mkdir -p "$INDEX_REPO/worktrees"

cd "$REPO_ROOT"
git fetch origin
git pull   # dev 최신화 필수 — 워크트리는 항상 최신 origin/dev 기준으로 생성
git worktree add "$INDEX_REPO/worktrees/{TICKET-ID}-{sub-repo-name}-{feature-en}" \
  -b feat/{TICKET-ID}-{sub-repo-name}-{feature-en} origin/dev
cd "$INDEX_REPO/worktrees/{TICKET-ID}-{sub-repo-name}-{feature-en}"
# 의존성 설치: 각 서브 레포의 skills/workflow-env/SKILL.md 참조

# 4. context.md 생성 — 워크트리 루트에 작성 (수동 편집 금지)
#    REQUIRED SKILL: jira-tickets → "context.md 생성" 섹션 실행
```

> `worktrees/` 디렉토리는 **인덱스 레포** `.gitignore`에 추가 필요 (서브 레포 아님).

**네이밍 규칙:** `{TICKET-ID}-{sub-repo-name}-{feature-en}`
- 티켓 ID 먼저 — 티켓 주도 워크플로우에서 기본 탐색 단위
- 서브 레포명 포함 — 인덱스 레포 `worktrees/` 안에 여러 레포 워크트리가 섞이므로 구분 필요

**예시:**
- 디렉토리: `kuru/worktrees/KM-175-kuru-mobile-image-tile/`
- 브랜치: `feat/KM-175-image-tile`

---

## Step 2. 설계

**버그 티켓 또는 경량 작업:**
- 에이전트가 브레인스토밍 생략 제안 → 사용자 확인 후 Step 3 진입

**기능 구현:**

**REQUIRED SKILL:** `brainstorming`

> **중요:** 브레인스토밍은 사용자와 함께 진행하는 인터랙티브 프로세스.
> - 질문은 **한 번에 하나씩** — 다음 질문은 사용자 답변을 받은 후에만
> - 설계 각 섹션마다 사용자 승인을 받은 후 다음 섹션으로 진행
> - 사용자 승인 전 구현·플랜 작성 금지 (brainstorming 스킬 HARD-GATE 준수)
> - 에이전트 혼자 설계를 완성해서 제시하는 방식 금지

- 브레인스토밍 과정은 로컬 MD에만 기록 (임시, Jira에 올리지 않음)
- 확정된 결정만 Jira description 업데이트 또는 코멘트로 기록 (변경 이유 한 줄 포함)
- context.md `## 확정 결정` 섹션 업데이트

**Jira 문서화 원칙:**
- 의식의 흐름 → Jira에 남기지 않음
- 확정 결정 → Jira에 남김 (변경 시 이유 명시, 히스토리 유지)

---

## Step 3. 플랜

**REQUIRED SKILL:** `writing-plans`

- 기능 구현: 전체 플랜
- 버그/경량: 경량 버전 (파일, 변경 범위, 검증 방법 중심)
- 저장: `[워크트리]/docs/superpowers/plans/YYYY-MM-DD-<기능명>.md`

---

## Step 4. 구현 + 검증

테스트 및 정적 검증 명령어는 각 서브 레포의 `skills/workflow-env/SKILL.md` 참조.

- 단위 테스트: error 0개 필수
- 정적 검증: error 0개 필수 — 에이전트가 직접 실행, 사용자에게 떠넘기지 말 것

실패 시 코드 수정 후 재실행. 실패 상태에서 Step 5 진입 금지.

서브에이전트 모드: **REQUIRED SKILL:** `subagent-dev`

> `subagent-dev` 내부 spec-reviewer / code-quality-reviewer는 태스크 단위 리뷰. Step 5는 전체 구현 완료 후 통합 리뷰.

---

## Step 5. 코드 리뷰 (필수)

전체 구현 완료 후 서브에이전트 통합 리뷰. 기존 코드 수정분 포함, 생략 불가.

**REQUIRED SKILL:** `code-conventions`

- 리뷰 항목: 스펙 준수 여부, 코드 품질, 컨벤션 준수
- 이슈 발견 시 수정 후 재검증, 승인 후 Step 6 진입

---

## Step 6. PR + 결과 확인

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

PR 생성 후:
- 티켓 remotelink 자동 연결 (jira-tickets 스킬 → `qa` 단계)
- 클라이언트(UI) 프로젝트: 개발 서버 직접 실행 후 결과 제공 (실행 전 기존 포트 정리)
- 서버 전용: 선택

사용자가 결과 확인 완료 의사를 밝히면 Step 7 진입.

---

## Step 7. 리뷰 루프

사용자 종결 선언 전까지:
- 피드백 반영 → 코드 개선
- Jira 코멘트 업데이트 (확정 변경 사항만, 이유 한 줄 포함)
- 정적 검증 + 서브에이전트 리뷰 반복

---

## Step 8. 종결

**순서대로:**

**1. 티켓 Done 전환 + 구현 내용 코멘트** (jira-tickets 스킬 → `act` 단계)

```bash
REPO_ROOT=$(git rev-parse --git-common-dir | xargs dirname)
source "$REPO_ROOT/../agent-common-workflow/.env.local"
# 상태 Done 전환 + 코멘트 (PR 링크 포함)
# transition-id는 프로젝트 skills/jira-tickets/SKILL.md 참조
```

**2. 컨플루언스 문서화** (사용자 확인)
- 피쳐 구현 → 기획 문서 (비개발자 수준, `writing-policy` 7-a 준용)
- 순수 개발 작업 → 기술 문서 (아키텍처/연동 구조, `writing-policy` 7-b 준용)
- 연동 방식: 각 프로젝트 `skills/confluence/SKILL.md` 참조. 없으면 수동 게시 후 URL을 티켓 코멘트에 첨부.

**3. 서버 종료 + 워크트리 제거** (사용자 확인)

```bash
kill -9 {PID} / taskkill /PID {PID} /F
INDEX_REPO=$(cd "$(git rev-parse --git-common-dir | xargs dirname)/.." && pwd)
git worktree remove "$INDEX_REPO/worktrees/{TICKET-ID}-{sub-repo-name}-{feature-en}"
```

나중에 하겠다고 하면 그대로 두고 종료.

---

## 예외 경로

| 예외 | 조건 | 처리 |
|------|------|------|
| A. 경량 사이클 | 코드 변경 없는 설정·문서 수정 | Step 2·3 생략. 정적 검증 필수 |
| B. dev 직접 푸시 | 경량 사이클 + 사용자 명시 요청 | 워크트리 없이 직접 커밋 가능 |
| C. 머지 충돌 | `git merge` 충돌 | 충돌 해결 + 재검증 후 Step 6 재진입 |
| D. 세션 재개 | PR URL·브랜치명으로 재개 요청 | 아래 절차 |
| E. 티켓 없음 | 기존 대화 방식으로 진입 | Step 0 생략 → 브레인스토밍·플랜 진행 → Step 3 완료 후 티켓 생성 → Step 4 진입 |

**예외 D — 세션 재개:**

```bash
REPO_ROOT=$(git rev-parse --git-common-dir | xargs dirname)
INDEX_REPO=$(cd "$REPO_ROOT/.." && pwd)

gh pr view {PR_URL}                                                    # 브랜치명·상태 확인
git worktree list                                                       # 기존 워크트리 확인
git worktree remove "$INDEX_REPO/worktrees/{TICKET-ID}-{sub-repo-name}-{feature-en}"  # 있으면 제거

cd "$REPO_ROOT"
git fetch origin feat/{TICKET-ID}-{sub-repo-name}-{feature-en}
git worktree add "$INDEX_REPO/worktrees/{TICKET-ID}-{sub-repo-name}-{feature-en}" origin/feat/{TICKET-ID}-{sub-repo-name}-{feature-en}
cd "$INDEX_REPO/worktrees/{TICKET-ID}-{sub-repo-name}-{feature-en}" && git pull
# 의존성 재설치 (skills/workflow-env/SKILL.md 참조)

# context.md 재생성 — jira-tickets 스킬 → "context.md 생성" 실행
git log --oneline -5 && git diff origin/dev...HEAD --stat  # 상태 보고
```

상태 보고 후 사용자 확인을 받고 이어갈 step 결정.
