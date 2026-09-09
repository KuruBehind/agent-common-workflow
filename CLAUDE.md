# agent-common-workflow — Claude Code Adapter

> **콘텐츠 정본은 [AGENTS.md](AGENTS.md)입니다.** 이 파일은 Claude Code 전용 어댑터로,
> 정본을 import하고 상시 로드 스킬 주입만 담당합니다.
> 규칙·주의사항을 고칠 때는 이 파일이 아니라 `AGENTS.md`를 고치세요.

@AGENTS.md

## 상시 로드 (프로세스 척추 — 조건부로 두면 안 되는 것만)

@skills/workflow/SKILL.md
@skills/communication/SKILL.md
@skills/code-conventions/SKILL.md

## 나머지 공통 스킬은 사용자 스코프에서 조건부 로드됩니다

`brainstorming`·`writing-plans`·`jira-tickets`·`subagent-dev`·`writing-policy`·`gcloud`·
`firebase-deploy-safety`·`ralph-loop`·`cost-proportionality-review`·`diagnosing-bugs`·`git-guardrails`

`tools/sync-agent-skills.sh`가 `skills/`를 `~/.claude/skills/`(Claude)와 `~/.agents/skills/`(Codex)에
복사하므로, **크로스레포 접근 없이** 관련 작업에서 description 매칭으로 자동 로드됩니다.

> 이전에는 위 11개까지 전부 `@import`로 상시 강제 로드했습니다(약 1,400줄). 작업과 무관해도 매 세션
> 컨텍스트를 차지했고, 다른 워크스페이스에서는 크로스레포 읽기 권한 프롬프트까지 떴습니다.
> 2026-09-09에 사용자 스코프 배포로 전환했습니다.

**공통 레포를 `git pull` 한 뒤에는 `bash tools/sync-agent-skills.sh`를 실행해야 반영됩니다.**
sync를 안 돌려도 위 3개(프로세스 척추)는 `@import`로 살아 있어 조용히 망가지지 않습니다.
