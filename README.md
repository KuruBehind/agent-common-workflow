# agent-common-workflow

Claude Code 공통 워크플로우 스킬셋. 기술 스택에 무관하게 어느 서비스 그룹에서도 재사용 가능한 범용 스킬 모음.

> 기술 스택 종속 스킬 (Flutter, Firebase 등)은 각 서비스 그룹 워크스페이스의 `skills/`에서 관리.

## 설치

`~/Desktop/dev/` 아래 clone:

```bash
git clone https://github.com/KuruBehind/agent-common-workflow ~/Desktop/dev/agent-common-workflow
```

## 사용 방법

각 서비스 그룹 워크스페이스의 `CLAUDE.md`에서 상대경로로 참조:

```markdown
### 공통 워크플로우 스킬 (`../agent-common-workflow/skills/`)

- **[워크플로우]** `../agent-common-workflow/skills/workflow/SKILL.md`
- **[브레인스토밍]** `../agent-common-workflow/skills/brainstorming/SKILL.md`
- **[플랜 작성]** `../agent-common-workflow/skills/writing-plans/SKILL.md`
- **[서브에이전트]** `../agent-common-workflow/skills/subagent-dev/SKILL.md`
- **[정책서 작성]** `../agent-common-workflow/skills/writing-policy/SKILL.md`
- **[Jira 티켓 (템플릿)]** `../agent-common-workflow/skills/jira-tickets/SKILL.md`
```

CLAUDE.md 전체 템플릿은 이 레포의 `CLAUDE.md`를 복사해 사용하세요.

## 스킬 목록

| 스킬 | step | 설명 |
|------|------|------|
| `skills/workflow` | 항상 활성 | step 인덱스, 진입 조건, 예외 경로 |
| `skills/brainstorming` | Step 0a | 설계 수립 프로세스 |
| `skills/writing-plans` | Step 0b | 구현 플랜 작성 |
| `skills/jira-tickets` | Step 0c | Jira 티켓 생성 (템플릿) |
| `skills/subagent-dev` | Step 2 | 태스크별 독립 에이전트 실행 |
| `skills/writing-policy` | Step 7 | 기획 정책서 + 개발 독스 작성 |

## 프로젝트별 오버라이드

공통 스킬에서 플레이스홀더로 처리된 항목(Jira 설정, 실행 환경 PATH 등)은  
워크스페이스 `skills/` 디렉토리에 동명 파일을 두어 오버라이드합니다.

```
my-workspace/
├── CLAUDE.md                         ← 이 레포 CLAUDE.md 기반 커스터마이즈
└── skills/
    ├── jira-tickets/SKILL.md         ← 프로젝트 Jira 설정 (실 자격증명)
    └── workflow-env/SKILL.md         ← 실행 환경 PATH, lint 명령어
```

## 가이드

인덱스 레포 패턴 전체 개념·셋업 절차·템플릿: [`docs/index-repo-pattern.md`](docs/index-repo-pattern.md)

## 업데이트

```bash
cd ~/Desktop/dev/agent-common-workflow && git pull
```
