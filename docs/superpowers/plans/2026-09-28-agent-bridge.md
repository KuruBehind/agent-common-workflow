# Claude·Codex 핸드오버와 교차 리뷰 구현 계획

**목표:** 기존 세션을 유지하면서 작업 상태를 인계하고 다른 CLI로 커밋 단위 리뷰를 실행한다.
**승인 근거:** 제안한 첫 도입 범위에 대한 사용자의 “진행해볼래?” 요청.
**구조:** Python 표준 라이브러리 CLI와 두 도구에 동일하게 배포하는 공통 스킬. 작업당 한 레포, 명시적인 상태 저장소, 파일 잠금, 원자적 JSON 저장을 사용한다. 여러 레포 작업은 레포마다 등록하고 같은 티켓으로 묶는다.
**범위:** 기존 GUI 세션 자동 주입·자동 수정·머지·배포·상시 감시는 포함하지 않는다. Jira 티켓은 아직 미생성이다.

- [x] `skills/agent-bridge/scripts/bridge_store.py`: Git 상태/내용 지문, 상태 저장, 배타 잠금. 인계 당시와 인수 시 코드가 다르면 인수 거부.
- [x] `skills/agent-bridge/scripts/bridge_review.py`: 명시적 기준 커밋→현재 커밋 diff, CLI 어댑터, 제한 시간, 원본 출력/결과 보존. 종료 코드뿐 아니라 응답 내용과 실행 전후 코드 상태를 검사.
- [x] `skills/agent-bridge/scripts/agent_bridge.py`: init/status/handoff/accept/review 명령. dry-run은 요청만 생성하고 모델을 호출하지 않는다. 실패·시간 초과·변경된 코드에 성공 표시하지 않는다.
- [x] `skills/agent-bridge/SKILL.md`: 최소 맥락 전달, 담당자 인계, 리뷰 판단 근거, 실제 사용 명령. 실행 도구를 스킬 내부에 두어 복사 후에도 자체 동작.
- [x] `tests/test_agent_bridge.py`: 임시 Git 저장소로 내용 변경 감지, 잘못된 담당자/중복 인수, 동시 실행 잠금, 리뷰 실패/시간 초과/성공/오래된 결과 검증.
- [x] 공통 AGENTS.md와 workflow의 재개/리뷰 지점에 선택적 연결. 원본 checkout의 다른 작업은 보존.
- [x] unittest, CLI dry-run, 독립 리뷰를 진행하고 새 스킬만 사용자 스코프로 배포. 실제 모델 호출이 불가능하면 이유와 검증 범위를 보고.

검증 명령: `python -m unittest discover -s tests -p test_agent_bridge.py -v`
완료 기준: 위 실패 시나리오가 방어되고, 두 사용자 스킬 경로에서 `--help`가 동작하며, 커밋과 사용 설명이 준비되어 있다.

## 검증 결과

- 15개 unittest 통과: 실제 Windows 부모 선종료, 시간 초과, Job 등록 전 자식 생성 방지 포함.
- 독립 리뷰 지적 3건 반영: 무제한 출력 대기, 중단된 최신 상태 누락, Job 등록 시점 경쟁.
- 양쪽 사용자 스킬 경로에 새 스킬만 설치하고 --help 실행 확인.
- 실제 Codex 호출은 코드 전송에 대한 명시적 승인 부족으로 자동 승인 검토가 거절. 요청 파일 생성까지 검증했으며 모델 호출은 사용자 응답 대기.
- skill-creator quick_validate.py는 설치 환경에 PyYAML이 없어 실행하지 못함. frontmatter/name/description과 상대 경로는 직접 검사.
- PR/머지/Jira 티켓 생성은 수행하지 않음. 소스는 codex/agent-bridge 브랜치의 격리 워크트리에 보존.
