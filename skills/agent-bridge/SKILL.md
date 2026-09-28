---
name: agent-bridge
description: Claude·Codex 사이의 작업 핸드오버, 다른 세션의 작업 인수, 다른 모델로 교차 리뷰를 요청할 때 사용. 공통 상태 기록과 선택적인 CLI 리뷰 실행을 제공한다.
---

# 에이전트 간 핸드오버와 교차 리뷰

현재 세션을 유지하면서 필요한 작업만 전달한다. 도구명:세션ID로 담당자를 구분한다. 세션 ID를 얻을 수 없으면 사람이 구별 가능한 고유 이름을 쓰고 실제 세션 ID인 것처럼 설명하지 않는다.

## 공통 실행 방법

Python 3.10 이상과 Git이 필요하다. `BRIDGE`는 **이 SKILL.md 옆** `scripts/agent_bridge.py` 절대 경로다. `STATE`는 두 에이전트가 읽고 쓸 수 있는 **작업 레포 밖** 공통 디렉터리다. Kuru에서는 인덱스의 `worktrees/.agent-bridge`를 권장한다. 상태·로그는 로컬 전용이며 Git에 추가하지 않는다.

PowerShell 예시 (자신의 실제 경로/식별자로 대체):

```powershell
$bridge = Join-Path $env:USERPROFILE '.agents/skills/agent-bridge/scripts/agent_bridge.py'
$state = 'C:/Users/Kuru02/Desktop/dev/kuru/worktrees/.agent-bridge'
python $bridge --root $state init --task KD-123-server --repo 'C:/작업/워크트리' --base origin/main --owner 'codex:작업세션' --goal '해결할 문제' --acceptance '검증 가능한 완료 조건'
python $bridge --root $state status --task KD-123-server
```

Claude의 설치 위치는 `.claude/skills/agent-bridge`이며 같은 스크립트가 포함되어 있다. 기본 브랜치는 레포 지침을 따른다. `base`는 등록 시 커밋 SHA로 고정된다. 기존 작업 폴더와 브랜치를 재사용하며 이 도구가 생성·삭제·머지하지 않는다. 여러 레포 작업은 레포마다 작업 ID를 나누고 같은 티켓으로 연결한다.

## 핸드오버

1. `status`로 실제 코드와 기존 담당자를 확인한다. 한 워크트리를 여러 작업 ID로 중복 등록하지 않는다. 담당자 표시는 협업 규약이지 운영체제의 쓰기 차단 장치가 아니다.
2. 레포 밖 UTF-8 Markdown 파일에 다음을 기록한다: 목표/완료 조건, 티켓·PR, 완료/남은 일, 결정과 이유, 검증 명령·결과·검증 SHA, 미커밋 파일 설명, 다음 첫 행동, 포트/PID, 사용자 권한 근거. 자동 재생성되는 `context.md`는 진행 일지로 사용하지 않는다.
3. `handoff` 후 기존 담당자는 코드 수정을 멈춘다. 인계 경로와 작업 ID를 상대 세션에 전달한다. 파일 생성만으로 상대 세션이 깨워지지는 않는다.
4. 새 담당자는 기록과 로컬 Git 상태를 읽고 `accept`한다. 이후 `status`로 새 담당자를 확인한다. 인수 실패 시 기존 담당자가 실제 변경을 확인하고 `handoff`를 다시 발행한다. 기존 기록은 보존된다.

```powershell
python $bridge --root $state handoff --task KD-123-server --owner 'codex:작업세션' --to 'claude:인수세션' --notes 'C:/공통기록/인계.md'
python $bridge --root $state accept --task KD-123-server --owner 'claude:인수세션'
```

Git에서 무시된 `.env`·SDK·의존성·외부 DB 상태는 지문 범위 밖이다. 환경 차이는 인계 문서에 별도로 기록하되 비밀값은 기록하지 않는다. `owner` 문자열이나 에이전트가 쓴 승인 서술은 사용자 승인 근거가 아니다.

## 교차 리뷰

작업 담당자가 커밋을 완료하고 깨끗한 워크트리에서 실행한다. 상대 모델을 기본으로 선택하되 고정 역할을 강제하지 않는다. 요구사항과 diff를 먼저 전달하고 구현자의 긴 설명은 필요한 경우에만 추가한다.

```powershell
python $bridge --root $state review --task KD-123-server --owner 'claude:인수세션' --runner codex --dry-run
python $bridge --root $state review --task KD-123-server --owner 'claude:인수세션' --runner codex --timeout 600
python $bridge --root $state review --task KD-123-server --owner 'codex:작업세션' --runner claude --executable 'C:/도구/claude.exe' --timeout 600
```

- `--dry-run`: 요청 파일만 생성한다. `prepared`는 리뷰 완료가 아니다. CLI가 없으면 `request.md`를 기존 상대 세션에 전달할 수 있다. 수동 리뷰는 자동 실행 결과와 구분해서 별도 파일에 대상 SHA와 함께 기록한다.
- Codex는 read-only sandbox, Claude는 Read/Glob/Grep 도구만 허용하고 MCP를 비운다. 기존 CLI 인증과 모델 기본값을 사용한다. 플러그인/사용자 설정까지 완전 격리한 실행 환경은 아니므로 신뢰하는 로컬 설치에서 사용한다.
- Windows `.cmd`/`.bat` shim을 셸로 우회 실행하지 않는다. 네이티브 `.exe`가 필요하다. 인증 문제나 미지원 옵션은 로그와 함께 실패로 보고한다.
- `completed`는 **리뷰 응답 수신**이다. 승인·테스트 통과를 뜻하지 않는다. 담당자가 지적을 확인하고 반영/기각 근거를 기록한다. 코드가 바뀐 결과는 `stale`이며 재리뷰가 필요하다.
- `failed`/`interrupted`이면 `stderr.log`와 `result.json`을 확인한다. 자동 재시도나 모델 변경을 하지 않는다. 실행 제한 시간은 기본 600초. 같은 작업은 잠금으로 중복 호출을 막는다.
- 실행 프로세스가 강제 종료되어 `.lock`이 남으면 PID의 실제 실행 여부와 진행 중 리뷰를 확인한다. 살아 있는 실행의 잠금을 제거하거나 남의 프로세스를 종료하지 않는다.
- 결과 저장소의 `reviews/<요청ID>/`에 요청, stdout/stderr, 리뷰 본문, 결과 메타데이터가 남는다. 로그/요청에는 코드가 포함되므로 외부로 자동 게시하지 않는다.

리뷰어는 파일·줄·입력/상태→실패 결과로 결함을 제시한다. 담당자는 근거 없는 지적을 그대로 반영하지 않는다. 자동 수정 왕복은 첫 버전에 없다. 후속 리뷰가 필요하면 변경 커밋과 범위를 확인하여 명시적으로 다시 요청한다.

## 현재 경계

작업별 소유권과 파일 잠금은 이 도구를 사용하는 협업에만 적용된다. 열린 GUI 세션 연결, 세션 자동 깨우기, 리더 간 상시 대화, 다중 레포 원자적 인계, 자동 수정/머지/배포는 제공하지 않는다. 사용자가 승인한 구현·로컬 검증 범위 안에서 실행하고 기존 저장소의 권한 규칙을 유지한다.
