# Claude·Codex 핸드오버와 교차 리뷰 구현 계획

**목표:** 기존 세션을 유지하면서 작업 상태를 인계하고 다른 CLI로 커밋 단위 리뷰를 실행한다.
**승인 근거:** 제안한 첫 도입 범위에 대한 사용자의 “진행해볼래?” 요청.
**구조:** Python 표준 라이브러리 CLI와 두 도구에 동일하게 배포하는 공통 스킬. 작업당 한 레포, 명시적인 상태 저장소, 파일 잠금, 원자적 JSON 저장을 사용한다. 여러 레포 작업은 레포마다 등록하고 같은 티켓으로 묶는다.
**범위:** 기존 GUI 세션 자동 주입·자동 수정·머지·배포·상시 감시는 포함하지 않는다. Jira 티켓은 아직 미생성이다.

- [ ] `skills/agent-bridge/scripts/bridge_store.py`: Git 상태/내용 지문, 상태 저장, 배타 잠금. 인계 당시와 인수 시 코드가 다르면 인수 거부.
- [ ] `skills/agent-bridge/scripts/bridge_review.py`: 명시적 기준 커밋→현재 커밋 diff, CLI 어댑터, 제한 시간, 원본 출력/결과 보존. 종료 코드뿐 아니라 응답 내용과 실행 전후 코드 상태를 검사.
- [ ] `skills/agent-bridge/scripts/agent_bridge.py`: init/status/handoff/accept/review 명령. dry-run은 요청만 생성하고 모델을 호출하지 않는다. 실패·시간 초과·변경된 코드에 성공 표시하지 않는다.
- [ ] `skills/agent-bridge/SKILL.md`: 최소 맥락 전달, 담당자 인계, 리뷰 판단 근거, 실제 사용 명령. 실행 도구를 스킬 내부에 두어 복사 후에도 자체 동작.
- [ ] `tests/test_agent_bridge.py`: 임시 Git 저장소로 내용 변경 감지, 잘못된 담당자/중복 인수, 동시 실행 잠금, 리뷰 실패/시간 초과/성공/오래된 결과 검증.
- [ ] 공통 AGENTS.md와 workflow의 재개/리뷰 지점에 선택적 연결. 원본 checkout의 다른 작업은 보존.
- [ ] unittest, CLI dry-run, 독립 리뷰를 진행하고 새 스킬만 사용자 스코프로 배포. 실제 모델 호출이 불가능하면 이유와 검증 범위를 보고.

검증 명령: `python -m unittest discover -s tests -p test_agent_bridge.py -v`
완료 기준: 위 실패 시나리오가 방어되고, 두 사용자 스킬 경로에서 `--help`가 동작하며, 커밋과 사용 설명이 준비되어 있다.
