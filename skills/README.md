# skills/

기술 스택에 무관하게 재사용 가능한 공통 워크플로우 스킬.  
프로젝트별 오버라이드(자격증명, 실행 환경 등)는 각 워크스페이스의 `skills/`에 배치합니다.

## 참조 구조

```
Desktop/dev/
├── agent-common-workflow/skills/   ← 이 디렉토리 (공통 원본)
│   ├── workflow/                    항상 활성 — step 인덱스, 예외 경로
│   ├── brainstorming/               Step 0a — 설계 수립
│   ├── writing-plans/               Step 0b — 구현 플랜
│   ├── jira-tickets/                Step 0c — 템플릿 (자격증명 없음)
│   ├── subagent-dev/                Step 2  — 독립 에이전트 실행
│   └── writing-policy/              Step 7  — 기획/개발 문서
│
└── {workspace}/skills/              ← 워크스페이스별 오버라이드
    ├── workflow-env/                실행 환경 (PATH, lint 명령어)
    ├── jira-tickets/                실 자격증명 + 프로젝트 매핑
    └── {stack-specific}/            기술스택 종속 스킬
```

## 스킬 목록

| 스킬 | step | 설명 |
|------|------|------|
| `workflow/` | 항상 활성 | 티켓 주도 Step 0~8, 진입 조건, 예외 경로 |
| `jira-tickets/` | Step 0~8 | 티켓 품질 리뷰, context.md 생성, 티켓 CRUD |
| `brainstorming/` | Step 2 | 설계 수립 — 코드 작성 전 hard gate |
| `writing-plans/` | Step 3 | 구현 플랜 작성, TDD 기반 |
| `subagent-dev/` | Step 4 | 태스크별 fresh 서브에이전트 실행 |
| `code-conventions/` | Step 5 | 통합 코드 리뷰 기준 — DRY, 단일책임, 네이밍 |
| `writing-policy/` | Step 8 | 기획 정책서(7-a) + 개발 독스(7-b) |
| `communication/` | 항상 활성 | 커뮤니케이션 원칙 — 아부 금지, 자율 해결, 직접 실행 |
| `gcloud/` | 필요시 | GCP 로그 분석, Cloud Functions/Scheduler 관리 |
| `ralph-loop/` | Step 4 (선택) | 정적 검증·빌드 오류 자동 반복 수정 루프 |

### opt-in (CLAUDE.md `@import` 카탈로그에 미등록 — 상시 로드 아님)

버그 디버깅·git 훅처럼 특정 상황에서만 필요한 스킬. 공유 레포 특성상 조건부 자동 로드가 안 되므로,
필요할 때 `claude --add-dir ../agent-common-workflow` 세션에서 트리거하거나 수동으로 참조한다.
(왜 상시 등록 안 하는지: [docs/index-repo-pattern.md](../docs/index-repo-pattern.md) 7번 섹션 참조)

| 스킬 | 설명 |
|------|------|
| `diagnosing-bugs/` | 어려운 버그·성능 회귀 진단 6단계 절차 (원문 영어 유지, [mattpocock/skills](https://github.com/mattpocock/skills) 이식) |
| `git-guardrails/` | `git reset --hard`/`clean -f`/`branch -D` 등 되돌릴 수 없는 명령어를 훅으로 하드블록 (프로젝트별 opt-in 설치, [mattpocock/skills](https://github.com/mattpocock/skills)에서 push 제외하고 축소 이식) |
| `cost-proportionality-review/` | 새 API·DB 쿼리·스케줄러/인프라·외부 유료 API 설계 시, 비용 구조가 실사용 목적·빈도에 비례하는지 점검 (kuru/sabakeru 실사고 근거). `brainstorming` 체크리스트에서 참조됨 |

## 오버라이드 방법

공통 스킬에서 `<!-- 플레이스홀더 -->` 처리된 항목은 워크스페이스의 동명 파일로 오버라이드합니다.

```markdown
<!-- CLAUDE.md 스킬 카탈로그 예시 -->

### 공통 스킬 (`../agent-common-workflow/skills/`)
- [Jira 티켓 템플릿] `../agent-common-workflow/skills/jira-tickets/SKILL.md`

### 워크스페이스 전용 스킬 (`skills/`)
- [Jira 티켓] `skills/jira-tickets/SKILL.md`  ← 실 자격증명 오버라이드
- [워크플로우 환경] `skills/workflow-env/SKILL.md`  ← PATH 설정
```

## 업데이트

```bash
cd ~/Desktop/dev/agent-common-workflow && git pull
```
