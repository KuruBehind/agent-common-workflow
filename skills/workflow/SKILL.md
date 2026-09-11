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
Step 1  셋업         공통 최신화 + 빈 포트 확인 + 워크트리 생성 + context.md 생성
Step 2  설계         버그/경량: 생략 제안 → 사용자 확인 / 기능: 브레인스토밍
Step 3  플랜         구현 계획 작성 (버그: 경량 버전)
Step 4  구현+검증    코드 → 단위테스트 → 정적검증 루프
Step 5  리뷰         서브에이전트 적대적 리뷰 (필수, PR 전 최소 1회 — 이후 추가 여부 질문)
Step 6  PR+확인      PR 생성 → 티켓 remotelink 연결 → 개발 서버 실행
Step 7  리뷰 루프    사용자 피드백 → 코드 개선 → 티켓 업데이트
Step 8  종결         티켓 Done → 컨플루언스 문서화 → 이 세션이 만든 포트·워크트리 정리 (남기면 목록 보고)
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

# 2. 포트 — 점유된 포트는 건드리지 않고 빈 포트를 새로 잡는다 (kill 금지)
#    상세·스니펫: 아래 "로컬 리소스 규칙 > 포트"

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

## Step 5. 코드 리뷰 (필수 — 적대적 리뷰 최소 1회)

전체 구현 완료 후, **PR 생성 전에** 서브에이전트로 리뷰한다. 기존 코드 수정분 포함, 생략 불가.

**REQUIRED SKILL:** `code-conventions`

### 적대적 리뷰 (최소 1회)

리뷰어 서브에이전트에게 "승인"이 아니라 **"깨뜨려라"**를 지시한다. 구현한 맥락 그대로 검토하면 같은 가정을 공유해서 같은 곳을 놓친다.

- **역할 지시**: 목표는 결함 발견. 통과 판정을 내리지 말 것
- **반드시 볼 것**: 엣지 케이스·경계값 / 실패 경로(네트워크·권한·빈 데이터·타임아웃) / 동시성·중복 실행 / 기존 동작 회귀 / 보안(입력 검증·권한) / 비용(`cost-proportionality-review` 해당 시)
- **지적은 구체적 실패 시나리오로**: "입력·상태 → 잘못된 결과" 형태로 받는다. "~할 수도 있다" 수준의 추측은 기각
- **검증 후 반영**: 각 지적을 재현·코드 확인으로 검증한다. 오탐은 근거와 함께 기각한다

1회 후 **반영·기각 건수와 남은 우려를 사용자에게 보고하고, 추가 라운드가 필요한지 묻는다.** 변경 범위가 크거나 돈·데이터·권한을 건드리는 변경이면 추가 라운드를 권한다.

### 일반 리뷰 항목

- 스펙 준수 여부, 코드 품질, 컨벤션 준수
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
| 없음 | `gh pr create --base <레포 기본 브랜치>` (레포 CLAUDE.md "기본 브랜치" 참조 — 무조건 dev 아님) |
| OPEN | 생성 금지 — 기존 PR에 푸시만 |
| **MERGED** | **푸시 금지.** 최신 base에서 새 브랜치를 따서 새 PR. 머지된 브랜치에 푸시하면 어느 PR에도 반영되지 않고 조용히 버려진다 |
| CLOSED | 재사용 금지. 사용자 확인 후 새 브랜치·새 PR |

**푸시 직전 한 번 더 확인한다.** Step 6 진입 시 확인한 상태가 리뷰 루프 동안 바뀌었을 수 있다(그 사이 머지되는 경우가 실제로 있다).

**PR 목록을 사용자에게 보고할 때:**
- 보고 직전 `gh pr view <번호> --json state` 로 **실시간 상태를 다시 조회**한다. 대화 앞부분에서 확인한 상태를 재사용하지 말 것
- "대기 중" 표에는 **OPEN만** 올린다. MERGED·CLOSED는 별도로 한 줄만 언급

PR 생성 후:
- 티켓 remotelink 자동 연결 (jira-tickets 스킬 → `qa` 단계)
- 클라이언트(UI) 프로젝트: 개발 서버를 **빈 포트에 새로** 띄워 결과 제공 — 기존 포트 프로세스 종료 금지 (아래 "로컬 리소스 규칙")
- 서버 전용: 선택

사용자가 결과 확인 완료 의사를 밝히면 Step 7 진입.

---

## Step 7. 리뷰 루프

사용자 종결 선언 전까지:
- 피드백 반영 → 코드 개선
- Jira 코멘트 업데이트 (확정 변경 사항만, 이유 한 줄 포함)
- 정적 검증 + 서브에이전트 리뷰 반복 (로직·데이터 경로를 바꾸는 변경이 들어가면 적대적 리뷰 재실행)

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

**3. 이 세션이 만든 포트·워크트리 정리** (아래 "로컬 리소스 규칙" 준수, 사용자 확인)

- 포트: **이 세션이 띄운 PID만** 종료
- 워크트리: PR MERGED + 미커밋 없음 + 머지 후 추가 커밋 없음을 확인한 뒤 제거
- 사용자가 "나중에"라고 하면 그대로 두되, **남긴 워크트리 경로·포트·PID를 종결 보고에 목록으로 남긴다.** 말없이 남기고 끝내지 않는다 — 워크트리가 수백 개씩 쌓이는 원인이 이것이다

---

## 로컬 리소스 규칙 (포트·워크트리)

같은 머신에서 여러 세션과 사용자 프로세스가 동시에 돈다. **이 세션이 만든 것만 정리하고, 남이 만든 것은 건드리지 않는다.**

### 포트

- **점유된 포트에 띄우지 않는다.** 기본 포트가 사용 중이면 그 프로세스를 죽이지 말고 빈 포트를 새로 잡는다
- 점유 프로세스 kill 금지 — 다른 세션의 개발 서버이거나 사용자가 띄운 앱일 수 있다
- 프로세스명 기준 일괄 종료(`taskkill /IM ...`, `pkill ...`) 금지. 사용자 브라우저·다른 세션까지 같이 죽는다
- 띄운 포트와 PID를 기록해두고, 결과를 줄 때 URL과 함께 알린다

```bash
PORT={기본포트}   # 서브 레포 CLAUDE.md 참조

# Windows (Git Bash) — 반드시 전체 경로. Git Bash PATH에 netstat가 없는 환경이 있고,
# 그러면 grep이 조용히 실패해 점유된 포트를 "빈 포트"로 오판한다 (2026-09-11 실측)
NETSTAT=/c/Windows/System32/NETSTAT.EXE
[ -x "$NETSTAT" ] && "$NETSTAT" -ano | grep -q LISTENING || { echo "포트 조회 불가 — 중단"; exit 1; }
while "$NETSTAT" -ano | grep -q ":$PORT .*LISTENING"; do PORT=$((PORT+1)); done

# macOS / Linux
command -v lsof >/dev/null || { echo "lsof 없음 — 중단"; exit 1; }
while lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; do PORT=$((PORT+1)); done

echo "사용 포트: $PORT"
```

> 조회 도구가 없거나 결과가 비면 **추정으로 진행하지 말고 멈춘다.** "점유 없음"과 "조회 실패"를 구분하지 못하면 다른 세션 서버와 같은 포트를 잡는다.

### 워크트리

- 만든 워크트리 경로를 기록해둔다 (종결 보고에 사용)
- **제거 시점**: 해당 브랜치의 PR이 MERGED 된 뒤
- **제거 전 확인** — 하나라도 걸리면 제거하지 말고 사용자에게 보고:

```bash
path="$INDEX_REPO/worktrees/{워크트리명}"; branch="{브랜치}"
git -C "$path" status --porcelain                         # 비어 있어야 함 (미커밋 없음)
head=$(gh pr list --head "$branch" --state merged --json headRefOid -q '.[0].headRefOid')
git -C "$path" log --oneline "$head"..HEAD                # 비어 있어야 함 (머지 후 추가 커밋 없음)
git worktree remove "$path"
```

- **정기 정리** — 세션 시작(Step 1)이나 종결(Step 8)에서, PR이 MERGED인 워크트리를 제거 후보로 뽑아 보고한다:

```bash
# 첫 항목(메인 체크아웃)은 제외 — git worktree remove 대상이 아니다
# 기본 브랜치(dev/main/master)도 제외 — 과거 dev→main PR이 MERGED라 오탐된다
git worktree list --porcelain \
  | awk '/^worktree /{p=$2; n++} /^branch /{sub("refs/heads/","",$2); if (n>1) print p" "$2}' \
  | while read -r p b; do
      case "$b" in dev|main|master) continue ;; esac
      s=$(gh pr list --head "$b" --state all --json state -q '.[0].state' 2>/dev/null)
      [ "$s" = "MERGED" ] && echo "제거 후보: $p ($b)"
    done
```

  후보는 **보고만 하고**, 위 "제거 전 확인"을 통과한 것만 사용자 확인 후 제거한다. 다른 세션이 쓰는 중일 수 있다.

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
