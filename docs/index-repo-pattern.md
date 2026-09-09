# 인덱스 레포 패턴 (Index Repo Pattern)

## 1. 개념

여러 독립 git 레포를 하나의 로컬 폴더 안에 나란히 클론하고, 그 폴더 자체를 공통 규칙·스킬 관리용 git 레포로 운영하는 방식입니다.

- git submodule/monorepo **아님** — 서브 레포는 완전히 독립된 git 레포
- 인덱스 레포는 서브 레포 코드를 추적하지 않음 (`.gitignore`로 제외)
- Claude Code의 **CLAUDE.md 계층 로딩**을 활용: 상위 디렉토리의 CLAUDE.md는 하위 세션에서도 자동 로드됨

---

## 2. 폴더 구조 스키마

```
Desktop/dev/
├── agent-common-workflow/        ← 공통 워크플로우 스킬 레포 (KuruBehind/agent-common-workflow)
│   └── skills/
│       ├── workflow/SKILL.md      step 인덱스, 예외 경로
│       ├── brainstorming/SKILL.md
│       ├── writing-plans/SKILL.md
│       ├── jira-tickets/SKILL.md  (템플릿, 자격증명 없음)
│       ├── subagent-dev/SKILL.md
│       └── writing-policy/SKILL.md
│
└── [project]/                     ← 인덱스 레포 (GitHub 레포, git init)
    ├── .git/
    ├── .gitignore                 ← 서브 레포·워크트리 디렉토리 제외
    ├── .claude/
    │   └── settings.json          ← Claude Code 권한 설정
    ├── CLAUDE.md                  ← 공통 규칙 (자동 로드)
    ├── README.md                  ← 워크스페이스 셋업 가이드
    ├── skills/                    ← 프로젝트 전용 스킬 (오버라이드)
    │   ├── README.md              ← 공통 vs 전용 구분 명시
    │   ├── workflow-env/SKILL.md  ← 실행 환경 (PATH, lint 명령어)
    │   ├── jira-tickets/SKILL.md  ← 실 자격증명 오버라이드
    │   └── [기술스택별]/SKILL.md
    ├── [sub-repo-a]/              ← 서브 레포 A (독립 git, .gitignore로 제외)
    └── [sub-repo-b]/              ← 서브 레포 B (독립 git, .gitignore로 제외)
```

**실 프로젝트 대입 예시**

| 인덱스 레포 | 서브 레포 A | 서브 레포 B |
|-----------|-----------|-----------|
| kuru | kuru_mobile (Flutter) | kuru_backoffice (Flutter Web) |
| yamaharu | yamaharu-web (React+TS) | yamaharu-server (Dart Frog) |

---

## 3. 각 파일 역할 및 작성 기준

### 인덱스 레포

| 파일 | 역할 | 작성 기준 |
|------|------|---------|
| `CLAUDE.md` | 공통 페르소나·크로스 레포 협업 규칙, 스킬 경로 | 최소화 — 구조 다이어그램·기술스택 상세 제외. 서브 레포 세부 규칙은 각 레포 CLAUDE.md에 위임 |
| `skills/README.md` | 공통 vs 전용 스킬 참조 구조 | `../agent-common-workflow/skills/`와 `skills/` 역할 명시 |
| `skills/workflow-env/SKILL.md` | 실행 환경 설정 | 머신별 PATH, 서브프로젝트별 lint 명령어 |
| `skills/jira-tickets/SKILL.md` | Jira 설정 오버라이드 | 실 자격증명, 프로젝트 키, 에픽 목록 |
| `.gitignore` | 서브 레포·워크트리 디렉토리, 임시 파일 | 아래 템플릿 참조 |
| `.claude/settings.json` | Claude Code 권한 설정 | 삭제 계열만 ask, 나머지 allow |
| `README.md` | 레포 구성 및 셋업 절차 | `agent-common-workflow` 링크 포함. 실제 org/레포명 기재 |

### 각 서브 레포

```
[sub-repo]/
├── .github/
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── skills/                  ← 레포 전용 스킬 (도메인·기술스택 특화)
│       └── [도메인별 스킬]/SKILL.md
├── .claude/
│   └── settings.json
├── CLAUDE.md                    ← 레포 전용 규칙
└── docs/
    ├── specs/                   ← 브레인스토밍 산출물
    ├── plans/                   ← 플랜 작성 산출물
    ├── api-spec-[도메인].md     ← API 스펙 (서버↔클라 공유)
    └── policy-[기능명].md       ← 정책서
```

> 공통 스킬(brainstorming, writing-plans 등)은 서브 레포에 두지 않습니다.  
> `../agent-common-workflow/skills/`를 참조합니다.

---

## 4. 파일 템플릿

### `.gitignore` (인덱스 레포)

```gitignore
# 서브 레포 (독립 git 레포 — 인덱스에서 추적하지 않음)
[sub-repo-a]/
[sub-repo-b]/

# 워크트리 디렉토리 (네이밍 규칙: [project]-feat-*, [project]-fix-*)
[project]-feat-*/
[project]-fix-*/
[project]-[sub]-feat-*/
[project]-[sub]-fix-*/

# 프로젝트별 임시/소스 파일
*.jpg
*.jpeg
*.png
*.pdf
```

### `.claude/settings.json`

```json
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read(**)",
      "Edit(**)",
      "Write(**)",
      "Glob(**)",
      "Grep(**)"
    ],
    "ask": [
      "Bash(rm -rf*)",
      "Bash(rm -r*)",
      "Bash(rm *)",
      "Bash(del *)"
    ]
  }
}
```

### `CLAUDE.md` (인덱스 레포 — 최소 구조)

```markdown
# [Project] — Claude Code Instructions

## 페르소나
- 모든 설명과 코드 내 주석은 한국어(Korean)로 작성하세요.
- 요청받지 않은 전역 설정 파일을 임의로 수정하지 마세요.

## 워크플로우
> 순서 및 step별 절차: `../agent-common-workflow/skills/workflow/SKILL.md` 참조

## 크로스 레포 협업 규칙
| 규칙 | 내용 |
|------|------|
| 배포 순서 | 서버 PR → 먼저 머지 → 클라이언트 PR |
| 같은 피처 사이클 | 연동 변경은 동일 PR 사이클 안에서 처리 |
| API 스펙 우선 | 서버 구현 전 docs/에 스펙 초안 작성 |

## 스킬 카탈로그

### 공통 (`../agent-common-workflow/skills/`)
- `workflow/SKILL.md` — step 인덱스 및 예외 경로
- `brainstorming/SKILL.md` — Step 0a
- `writing-plans/SKILL.md` — Step 0b
- `jira-tickets/SKILL.md` — Step 0c 템플릿
- `subagent-dev/SKILL.md` — Step 2
- `writing-policy/SKILL.md` — Step 7

### 프로젝트 전용 (`skills/`)
- `workflow-env/SKILL.md` — 실행 환경 (PATH, lint 명령어)
- `jira-tickets/SKILL.md` — Step 0c 실행 (실 자격증명)
- [기술스택별 스킬]

### 레포별 고유 스킬
각 서브프로젝트 `.github/skills/` 참조.
```

---

## 5. 신규 프로젝트 적용 절차

```bash
# 0. agent-common-workflow 클론 (최초 1회)
git clone git@github.com:KuruBehind/agent-common-workflow.git ~/Desktop/dev/agent-common-workflow

# 1. 인덱스 폴더 생성 및 파일 작성
mkdir ~/Desktop/dev/[project] && cd ~/Desktop/dev/[project]
# CLAUDE.md, README.md, .gitignore, .claude/settings.json 작성
# skills/workflow-env/SKILL.md, skills/jira-tickets/SKILL.md 작성
# skills/README.md 작성 (공통 vs 전용 구분)

# 2. git 초기화 및 초기 커밋
git init
git add CLAUDE.md README.md .gitignore .claude/ skills/
git branch -M main
git commit -m "chore: [project] 인덱스 레포 초기 셋업"

# 3. GitHub 레포 생성 및 push
gh repo create KuruBehind/[project] --private --description "[설명]"
git remote add origin git@github.com:KuruBehind/[project].git
git push -u origin main

# 4. 서브 레포 클론 (인덱스 폴더 안으로)
git clone git@github.com:KuruBehind/[sub-repo-a].git [sub-repo-a]
git clone git@github.com:KuruBehind/[sub-repo-b].git [sub-repo-b]
```

---

## 6. 크로스 레포 워크플로우 요약

### 단독 작업 (서브 레포 단일 변경)

해당 레포의 `CLAUDE.md` 및 `.github/skills/`를 따릅니다.  
공통 스킬은 `../agent-common-workflow/skills/`에서 자동 참조.

### 동시 작업 (서브 레포 2개 이상 동시 변경)

```
[인덱스 루트에서]
Step 1   워크트리 셋업 (웹·서버 각각)
Step 0a  브레인스토밍 — API 경계 먼저 확정, 스펙 문서 초안
Step 0b  플랜 작성 — 레포별 플랜 분리, EnterPlanMode → 승인
Step 0c  Jira 티켓 생성
Step 2   서버 구현
Step 3   서버 단위 테스트
Step 4   서버 정적 검증
Step 2   웹 구현 (API 스펙 기준)
Step 3   웹 단위 테스트
Step 4   웹 정적 검증
Step 5   웹 통합 테스트
Step 6   서버 PR → 머지 확인 → 웹 PR
Step 7   정책서 작성
Step 8   워크트리 정리
```

**핵심 불변 원칙:**
- 서버 PR은 항상 웹 PR보다 먼저 머지
- **PR base 브랜치 판단 기준**: 무조건 `dev`가 아니다. 그 레포의 `.github/workflows/`에 **실제 dev 배포 워크플로우**(dev push 시 별도 dev 환경/타겟으로 배포)가 구성돼 있으면 `dev`, 없으면 `main`. 브랜치가 원격에 남아있다고 기준이 되는 게 아니라, **실제 배포 플로우가 근거**다 (예: kuru_landing은 `dev` 브랜치가 remote에 남아있지만 dev 배포 워크플로우가 없어 실제 PR base는 `main` — 2026-08-25 확인). 각 레포 CLAUDE.md 상단에 "기본 브랜치" 항목으로 명시할 것
- 워크트리 명령은 인덱스 루트에서 실행
- `git checkout dev` 절대 금지 (워크트리 생성으로 대체, 단 위 기준으로 `dev`가 base가 아닌 레포에는 해당 없음)

---

## 7. Claude Code 동작 원리 (참고)

Claude Code는 현재 작업 디렉토리에서 루트 방향으로 CLAUDE.md를 모두 탐색해 로드합니다.

```
yamaharu/CLAUDE.md               ← 자동 로드 (공통 규칙)
yamaharu/yamaharu-web/CLAUDE.md  ← 자동 로드 (레포 전용 규칙)
```

즉, `yamaharu-web/` 세션에서도 상위 `yamaharu/CLAUDE.md`가 항상 적용됩니다.

### 스킬 로딩 방식 — `@import` vs `.claude/skills/` (중요, 혼동 주의)

> ⚠️ 2026-08-24 정정: 과거 버전의 이 문서는 "CLAUDE.md에 경로를 명시하면 필요 시 로드된다"고 설명했으나 **사실이 아닙니다.** 실제 동작은 로딩 방식에 따라 완전히 다릅니다.

| 방식 | 로딩 시점 | 적용 범위 |
|------|---------|---------|
| CLAUDE.md `@path` (`@import`) | **항상 전체 강제 로드** — 작업 내용과 무관하게 매 세션 로드됨. progressive disclosure 아님 | 어떤 경로든 상대경로로 참조 가능 (예: `@../agent-common-workflow/CLAUDE.md`) |
| `.claude/skills/<name>/SKILL.md` (Skill 자동 탐색) | frontmatter `description`이 현재 작업과 매칭될 때만 **조건부 로드**. 호출 식별자는 **디렉토리명**(frontmatter `name` 필드 아님) | **현재 프로젝트 루트 밑에 물리적으로 있어야만** 인식됨. 다른 레포(`agent-common-workflow` 등)에 있는 스킬은 자동으로 안 잡힘 |

**실무 판단 기준:**
- 거의 모든 세션에 필요한 것(실행 환경 PATH, 항상 지켜야 할 페르소나 규칙 등) → CLAUDE.md `@import`로 상시 로드
- 특정 상황에만 필요한 것(특정 도메인 작업, 특정 기술스택 작업 등) → 그 레포 자체 `.claude/skills/`에 두어 조건부 로드

**`../agent-common-workflow/skills/`처럼 다른 레포에 있는 스킬을 조건부로 쓰고 싶다면?** 공식적으로는 `claude --add-dir ../agent-common-workflow` 플래그(또는 세션 중 `/add-dir` 명령)로만 가능합니다. 이건 세션마다 개인이 직접 켜야 하는 로컬 실행 옵션이라 팀 전체에 자동 적용되지 않습니다 — `.claude/settings.json`에 이를 영구 설정하는 공식 키는 없습니다. 그래서 여러 인덱스 레포가 공유하는 `agent-common-workflow`의 스킬은 현재 구조상 `@import`(상시 강제 로드)가 사실상 유일하게 팀 전체에 안전하게 보장되는 방식입니다 — 비효율적이지만 의도적인 트레이드오프로 이해하고 사용할 것.

---

## 8. 적용 프로젝트 현황

| 인덱스 레포 | GitHub | 서브 레포 |
|-----------|--------|---------|
| kuru | [KuruBehind/kuru](https://github.com/KuruBehind/kuru) | kuru_mobile, kuru_backoffice, kuru_landing, kuru_asp_server |
| yamaharu | [KuruBehind/yamaharu](https://github.com/KuruBehind/yamaharu) | yamaharu_client (웹), ai_agent_flow (서버) |

**공통 스킬 레포**

| 레포 | GitHub | 역할 |
|------|--------|------|
| agent-common-workflow | [KuruBehind/agent-common-workflow](https://github.com/KuruBehind/agent-common-workflow) | 모든 인덱스 레포가 공유하는 워크플로우 스킬 원본 |
