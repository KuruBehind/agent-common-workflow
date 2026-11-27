# agent-common-workflow

Claude Code 공통 워크플로우 스킬셋. 기술 스택에 무관하게 어느 서비스 그룹에서도 재사용 가능한 범용 스킬 모음.

> 기술 스택 종속 스킬 (Flutter, Firebase 등)은 각 서비스 그룹 워크스페이스의 `skills/`에서 관리.

## 설치

`~/Desktop/dev/` 아래 clone:

```bash
git clone https://github.com/KuruBehind/agent-common-workflow ~/Desktop/dev/agent-common-workflow
```

### 워크트리 자동 정리 (머신마다 1회 등록)

작업마다 `<인덱스 레포>/worktrees/` 에 워크트리가 생긴다. 세션 종결 때 지우는 규칙만으로는 쌓여서
(한 머신 1,400개, 에디터 언어 서버 메모리 30GB 이상 — 2026-11-25), 정리는 `tools/prune-worktrees.sh` 를
머신 스케줄러에 걸어 자동으로 돌린다. 수정이 없고 머지된 지 3일 지난 워크트리만 지우며, 브랜치·커밋은 남는다
(기준 상세는 스크립트 상단 주석).

먼저 미리보기로 확인한다:

```bash
bash ~/Desktop/dev/agent-common-workflow/tools/prune-worktrees.sh --dry-run ~/Desktop/dev/<인덱스 레포>
```

**Windows** (PowerShell, 관리자 권한 불필요) — 매일 12:30, PC 가 꺼져 있어 놓치면 켤 때 실행. 창은 뜨지 않는다:

```powershell
$roots = '~/Desktop/dev/kuru'   # 인덱스 레포가 여럿이면 공백으로 나열: '~/Desktop/dev/kuru ~/Desktop/dev/pin'
$cmd   = "bash ~/Desktop/dev/agent-common-workflow/tools/prune-worktrees.sh $roots >> ~/.prune-worktrees.log 2>&1"
$act   = New-ScheduledTaskAction -Execute 'conhost.exe' -Argument "--headless `"C:\Program Files\Git\bin\bash.exe`" -lc `"$cmd`""
$trg   = New-ScheduledTaskTrigger -Daily -At 12:30
$set   = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
Register-ScheduledTask -TaskName prune-worktrees -Action $act -Trigger $trg -Settings $set -Force
```

**macOS** — `crontab -e` 에 한 줄 (잠자기로 놓친 실행은 건너뛴다):

```
30 12 * * * bash ~/Desktop/dev/agent-common-workflow/tools/prune-worktrees.sh ~/Desktop/dev/<인덱스 레포> >> ~/.prune-worktrees.log 2>&1
```

결과는 `~/.prune-worktrees.log`. 등록 확인: Windows `Get-ScheduledTask prune-worktrees`, macOS `crontab -l`.

### 개발 프로세스 자동 정리 (Windows, 머신마다 1회 등록)

세션이 끝나도 QA 브라우저·vite/flutter 웹 서버·멈춘 gcloud 가 남아 메모리를 채운다
(한 머신 커밋 메모리 99%, 잔여물 약 27GB — 2026-11-27). `tools/prune-dev-processes.ps1` 이 실행 시간 기준으로 정리한다:
임시 프로필 QA 브라우저 12시간·개발 서버 24시간·gcloud 15분 초과. 사용자 본인 Chrome(기본 프로필)은 대상이 아니다.

미리보기:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File $HOME\Desktop\dev\agent-common-workflow\tools\prune-dev-processes.ps1 -DryRun
```

등록 (1시간마다, 창 없음, 관리자 권한 불필요):

```powershell
$ps  = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$arg = "--headless `"$ps`" -NoProfile -ExecutionPolicy Bypass -Command `"& '$HOME\Desktop\dev\agent-common-workflow\tools\prune-dev-processes.ps1' *>&1 | Out-File -Append -Encoding utf8 '$HOME\.prune-dev-processes.log'`""
$act = New-ScheduledTaskAction -Execute 'conhost.exe' -Argument $arg
$trg = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
$set = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
Register-ScheduledTask -TaskName prune-dev-processes -Action $act -Trigger $trg -Settings $set -Force
```

결과는 `~/.prune-dev-processes.log`. 기준을 바꾸려면 `-QaBrowserHours`·`-DevServerHours`·`-GcloudMinutes` 를 붙인다.

> **에디터 설정도 함께** — 인덱스 루트를 VS Code 로 열면 언어 서버가 `worktrees/` 안 프로젝트를 전부 분석한다.
> 인덱스 레포 `.vscode/settings.json` 에 `worktrees` 를 분석·감시·검색 제외로 둘 것
> (Dart 는 `dart.analysisExcludedFolders`, 공통은 `files.watcherExclude`·`search.exclude`).

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
| `skills/artifact-publishing` | 상황부 | 내부 공유 페이지(Claude Artifact) 게시·동기화·권한 |
| `skills/ui-mockup` | 상황부 | 화면 시안 — 실제 화면 캡처를 바탕에 깐 Design 캔버스, 바뀌는 자리만 그리기 |

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
