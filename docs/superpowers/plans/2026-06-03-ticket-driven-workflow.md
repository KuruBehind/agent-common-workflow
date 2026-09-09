# 티켓 주도 워크플로우 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 업무 발화 기점을 Jira 티켓으로 이동하고, 워크트리 구조·경로 안정성·코드 리뷰·커뮤니케이션 원칙을 스킬 파일로 명문화한다.

**Architecture:** 기존 7-step 워크플로우를 9-step(Step 0~8) 티켓 주도 구조로 전면 재편. 신규 스킬 2개(communication, code-conventions) 추가. jira-tickets 스킬에 품질 리뷰·context.md 생성 로직 추가.

**Tech Stack:** Markdown 스킬 파일, curl REST API, bash

**Spec:** `docs/superpowers/specs/2026-06-03-ticket-driven-workflow-design.md`

---

## 파일 구조

| 작업 | 파일 |
|------|------|
| 신규 생성 | `skills/communication/SKILL.md` |
| 신규 생성 | `skills/code-conventions/SKILL.md` |
| 수정 | `CLAUDE.md` — 카탈로그 + 핵심 규칙 요약 추가 |
| 전면 수정 | `skills/jira-tickets/SKILL.md` — 품질 리뷰 + context.md |
| 전면 재작성 | `skills/workflow/SKILL.md` — Step 0~8 구조 |

---

## Task 1: communication/SKILL.md 신규 생성

**Files:**
- Create: `skills/communication/SKILL.md`

- [ ] **Step 1: 파일 작성**

```markdown
---
name: communication
description: "에이전트 커뮤니케이션 원칙 — 피드백 방식, 자율 해결 기준, 결과 제공 방식을 정의합니다."
---

# 커뮤니케이션 원칙

## 기본 자세

- **아부 금지** — 칭찬·격려가 실질적으로 필요한 상황이 아니면 생략. "좋은 질문이에요", "훌륭합니다" 류의 선행 문구 사용 금지.
- **객관적 피드백** — 의견이 아닌 사실과 근거 기반. 판단을 내릴 때는 이유를 함께 제시.
- **확정되지 않은 내용을 확정처럼 표현하지 않음** — 불확실한 내용은 "~일 수 있습니다", "~로 보입니다"로 명확히 구분.

## 자율 해결 원칙

사용자에게 직접 요청하기 전에 **10회 이상** 스스로 해결을 시도할 것:

1. 공식 문서 검색
2. 코드베이스 내 유사 패턴 탐색
3. 에러 메시지 직접 분석
4. 가설 수립 후 검증
5. 대안 접근법 시도

10회 시도 후에도 해결되지 않을 때만 사용자에게 구체적인 질문으로 요청.
"어떻게 할까요?" 같은 열린 질문 금지 — 막힌 지점과 시도한 내용을 함께 제시할 것.

## 결과 제공 방식

- **링크·URL** — 직접 열어서 내용을 확인한 후 결과를 요약해 제공. "링크 확인해보세요" 금지.
- **서버·실행 결과** — 직접 실행한 후 출력 결과나 스크린샷을 제공. "실행해보세요" 금지.
- **코드 변경** — 변경 후 테스트까지 완료한 상태로 보고. "적용해보세요" 금지.

## 요청 범위 준수

- 요청받은 범위 밖의 파일을 임의로 수정하지 않음
- 추가 개선이 필요하다고 판단되면 수정 전에 먼저 보고하고 승인을 받을 것
- 작업 완료 후 불필요한 요약·칭찬 문구 없이 결과만 간결하게 보고
```

- [ ] **Step 2: 커밋**

```bash
git add skills/communication/SKILL.md
git commit -m "feat: communication 스킬 신규 추가"
```

---

## Task 2: code-conventions/SKILL.md 신규 생성

**Files:**
- Create: `skills/code-conventions/SKILL.md`

- [ ] **Step 1: 파일 작성**

```markdown
---
name: code-conventions
description: "코드 컨벤션 및 클린코드 기준 — DRY, 디자인 패턴, 단일 책임, 네이밍을 정의합니다."
---

# 코드 컨벤션

## DRY (Don't Repeat Yourself)

- 동일하거나 유사한 로직이 **2곳 이상** 등장하면 공통 함수·모듈·상수로 분리
- 분리 기준: 내용이 같은가 (복사·붙여넣기 여부), 변경 시 두 곳을 동시에 수정해야 하는가
- 공통 분리 후 기존 코드는 분리된 단위를 호출하도록 교체

## 단일 책임 원칙

- 파일·클래스·함수는 **하나의 명확한 역할**만 담당
- 파일이 커지면 책임이 섞였다는 신호 — 역할 기준으로 분리
- 함수는 한 가지 작업만 수행. 이름만 읽어도 무엇을 하는지 알 수 있어야 함

## 네이밍

- 함수명·변수명으로 의도가 전달되어야 함
- 주석이 필요한 코드는 네이밍이 잘못된 신호
- 약어 지양 — `usrNm` 대신 `userName`, `calcTtl` 대신 `calculateTotal`
- Boolean 변수는 `is`, `has`, `can` 접두어 사용 (`isLoading`, `hasError`)

## 디자인 패턴

- 패턴 적용 시 **적용 이유를 명시** (주석 한 줄 또는 PR 설명)
- 과도한 추상화 금지 — 지금 필요한 것만 구현 (YAGNI)
- 자주 사용하는 패턴:
  - Repository 패턴: 데이터 접근 로직 분리
  - Factory 패턴: 객체 생성 로직 캡슐화
  - Observer 패턴: 이벤트 기반 상태 변경 전파

## 리뷰 체크리스트 (서브에이전트 리뷰 시 적용)

- [ ] 2곳 이상 중복 로직 없음
- [ ] 각 파일·함수의 책임이 단일하게 유지됨
- [ ] 함수명·변수명만으로 의도 파악 가능
- [ ] 불필요한 추상화·미래 대비 코드 없음
- [ ] 디자인 패턴 적용 시 이유 명시됨
- [ ] 컨벤션 위반 발견 시 수정 후 재검증
```

- [ ] **Step 2: 커밋**

```bash
git add skills/code-conventions/SKILL.md
git commit -m "feat: code-conventions 스킬 신규 추가"
```

---

## Task 3: CLAUDE.md 업데이트

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 스킬 카탈로그에 신규 스킬 추가 + 핵심 규칙 요약 섹션 추가**

현재 `CLAUDE.md` 스킬 카탈로그:
```
@skills/workflow/SKILL.md
@skills/brainstorming/SKILL.md
@skills/writing-plans/SKILL.md
@skills/jira-tickets/SKILL.md
@skills/subagent-dev/SKILL.md
@skills/writing-policy/SKILL.md
@skills/gcloud/SKILL.md
```

아래 두 줄 추가:
```
@skills/communication/SKILL.md
@skills/code-conventions/SKILL.md
```

그리고 파일 하단에 핵심 요약 섹션 추가:
```markdown
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
```

- [ ] **Step 2: 커밋**

```bash
git add CLAUDE.md
git commit -m "chore: communication·code-conventions 스킬 카탈로그 등록 및 핵심 규칙 요약 추가"
```

---

## Task 4: jira-tickets/SKILL.md 고도화

**Files:**
- Modify: `skills/jira-tickets/SKILL.md`

스펙 기준 추가 항목:
1. 진입부에 **티켓 품질 리뷰 체크리스트** 섹션 추가
2. **context.md 생성 로직** 추가 (Step 0 → Step 1 워크트리 생성 후 실행)
3. **intent 기반 동사 구조** 정리 (get / work / qa / act)

- [ ] **Step 1: 파일 상단 frontmatter 아래에 "티켓 품질 리뷰" 섹션 추가**

`## 사전 확인` 위에 삽입:
```markdown
## 티켓 품질 리뷰 (Step 0 — 게이트)

티켓 URL 또는 키를 받으면 아래 체크리스트를 실행. 미흡 항목은 Jira 코멘트 + 작성자 멘션으로 보완 요청.

### 공통 체크리스트
- [ ] 목적/배경 — 왜 이 작업이 필요한지 명시되어 있는가
- [ ] 완료 기준 (AC) — 언제 Done으로 볼 수 있는지 명시되어 있는가
- [ ] 기술 범위 — FE / BE / 인프라 중 어느 레이어를 건드리는지 명시되어 있는가

> 프로젝트별 추가 항목은 각 워크스페이스 `skills/jira-tickets/SKILL.md`에서 오버라이드.

### 미흡 시 처리
```bash
REPO_ROOT=$(git rev-parse --git-common-dir | xargs dirname)
source "$REPO_ROOT/../agent-common-workflow/.env.local"

# 코멘트 작성 + 작성자 멘션
cat > /tmp/comment.json << 'EOF'
{
  "body": {
    "type": "doc", "version": 1,
    "content": [{
      "type": "paragraph",
      "content": [
        {"type": "mention", "attrs": {"id": "<작성자-accountId>"}},
        {"type": "text", "text": " 아래 항목 보완 부탁드립니다:\n- <미흡 항목 목록>"}
      ]
    }]
  }
}
EOF
curl -s -u "$JIRA_AUTH" -X POST \
  -H "Content-Type: application/json; charset=utf-8" \
  "$JIRA_BASE/issue/<TICKET-KEY>/comment" --data-binary @/tmp/comment.json
```

사용자에게 "보완 후 진행할까요?" 확인. override 선택 시 미흡 상태로도 진행 가능.
```

- [ ] **Step 2: context.md 생성 로직 섹션 추가**

파일 하단 `## 완료 기준` 앞에 삽입:
```markdown
## context.md 생성 (Step 1 워크트리 생성 직후)

워크트리 루트에 `context.md` 생성. 수동 편집 금지. 세션 재개 시 재생성.

```bash
REPO_ROOT=$(git rev-parse --git-common-dir | xargs dirname)
source "$REPO_ROOT/../agent-common-workflow/.env.local"

TICKET_KEY="<TICKET-KEY>"
RESULT=$(curl -s -u "$JIRA_AUTH" "$JIRA_BASE/issue/$TICKET_KEY?fields=summary,issuetype,priority,assignee,parent,comment,remotelinks")

# context.md 작성 — 워크트리 루트 기준
cat > context.md << EOF
# $TICKET_KEY $(echo $RESULT | grep -o '"summary":"[^"]*"' | head -1 | cut -d'"' -f4)

## 티켓 정보
- 타입: $(echo $RESULT | grep -o '"issuetype".*"name":"[^"]*"' | head -1 | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
- 우선순위: $(echo $RESULT | grep -o '"priority".*"name":"[^"]*"' | head -1 | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
- 에픽: $(echo $RESULT | grep -o '"parent".*"key":"[^"]*"' | head -1 | grep -o '"key":"[^"]*"' | cut -d'"' -f4)

## 확정 결정
<!-- 브레인스토밍·설계 중 확정된 결정을 여기에 기록. 변경 시 이유 한 줄 포함. -->

## 연결된 PR
<!-- PR 생성 후 여기에 추가 -->
EOF
```
```

- [ ] **Step 3: intent 기반 동사 구조 섹션 추가**

파일 상단 frontmatter 바로 아래에 삽입:
```markdown
## 티켓 작업 의도별 동사

| 의도 | 동작 | 주요 사용 시점 |
|------|------|--------------|
| `get` | 티켓 정보 조회, context.md 생성 | Step 0, 세션 재개 |
| `work` | 티켓 상태 In Progress 전환, 작업 시작 코멘트 | Step 1 셋업 완료 후 |
| `qa` | 구현 내용 코멘트, PR 연결 | Step 6 PR 생성 후 |
| `act` | 티켓 상태 Done 전환, 종결 코멘트 | Step 8 종결 |
```

- [ ] **Step 4: 커밋**

```bash
git add skills/jira-tickets/SKILL.md
git commit -m "feat: jira-tickets 스킬 — 품질 리뷰 체크리스트·context.md 생성·intent 동사 구조 추가"
```

---

## Task 5: workflow/SKILL.md 전면 재작성

**Files:**
- Rewrite: `skills/workflow/SKILL.md`

기존 Step 1~7 구조를 Step 0~8로 전면 교체. 스펙 `docs/superpowers/specs/2026-06-03-ticket-driven-workflow-design.md` 기준.

- [ ] **Step 1: 파일 전체 재작성**

```markdown
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
        └── {TICKET-ID}-{feature-en}/   ← 워크트리
```

서브 레포가 없으면: `git clone git@github.com:{org}/{sub-repo}.git ../{sub-repo}`
레포명 불확실하면 사용자에게 확인.

### 경로 규칙

- 워크트리는 **서브 레포 내부 `worktrees/`** 에 생성
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

```bash
REPO_ROOT=$(git rev-parse --git-common-dir | xargs dirname)

# 1. 공통 워크플로우 최신화
git -C "$REPO_ROOT/../agent-common-workflow" pull

# 2. 잔존 서버 포트 확인 — 과도한 포트 점유 시 정리 후 진행
lsof -i :{port}                          # macOS — 포트는 서브 레포 CLAUDE.md 참조
netstat -ano | findstr :{port}           # Windows
kill -9 {PID} / taskkill /PID {PID} /F

# 3. 워크트리 생성 — 서브 레포 내부 worktrees/ 에 생성
cd "$REPO_ROOT"
git fetch origin
git pull
git worktree add worktrees/{TICKET-ID}-{feature-en} -b feat/{TICKET-ID}-{feature-en} origin/dev
cd worktrees/{TICKET-ID}-{feature-en}
# 의존성 설치: 각 서브 레포의 skills/workflow-env/SKILL.md 참조

# 4. context.md 생성 — 워크트리 루트에 작성 (수동 편집 금지)
#    REQUIRED SKILL: jira-tickets → "context.md 생성" 섹션 실행
```

> `worktrees/` 디렉토리는 서브 레포 `.gitignore`에 추가 필요.

**네이밍 예시:**
- 디렉토리: `kuru-mart/worktrees/KURU-123-cart-redesign/`
- 브랜치: `feat/KURU-123-cart-redesign`

---

## Step 2. 설계

**버그 티켓 또는 경량 작업:**
- 에이전트가 브레인스토밍 생략 제안 → 사용자 확인 후 Step 3 진입

**기능 구현:**

**REQUIRED SKILL:** `brainstorming`

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
git worktree remove worktrees/{TICKET-ID}-{feature-en}
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
gh pr view {PR_URL}                                        # 브랜치명·상태 확인
git worktree list                                          # 기존 워크트리 확인
git worktree remove worktrees/{TICKET-ID}-{feature-en}    # 있으면 제거

cd "$REPO_ROOT"
git fetch origin feat/{TICKET-ID}-{feature-en}
git worktree add worktrees/{TICKET-ID}-{feature-en} origin/feat/{TICKET-ID}-{feature-en}
cd worktrees/{TICKET-ID}-{feature-en} && git pull
# 의존성 재설치 (skills/workflow-env/SKILL.md 참조)

# context.md 재생성 — jira-tickets 스킬 → "context.md 생성" 실행
git log --oneline -5 && git diff origin/dev...HEAD --stat  # 상태 보고
```

상태 보고 후 사용자 확인을 받고 이어갈 step 결정.
```

- [ ] **Step 2: 커밋**

```bash
git add skills/workflow/SKILL.md
git commit -m "feat: workflow 스킬 전면 재작성 — 티켓 주도 Step 0~8 구조"
```

---

## Task 6: 경로 검증 + 최종 커밋

- [ ] **Step 1: 하드코딩 경로 전수 확인**

```bash
cd "$(git rev-parse --show-toplevel)"
grep -r "\.\./agent-common-workflow" skills/
```

결과가 있으면 모두 `$REPO_ROOT/../agent-common-workflow` 패턴으로 교체.

- [ ] **Step 2: skills/README.md 스킬 목록 업데이트**

communication, code-conventions 두 스킬을 테이블에 추가.

- [ ] **Step 3: 최종 커밋**

```bash
git add -A
git commit -m "chore: 스킬 목록 업데이트 및 경로 검증 완료"
```
