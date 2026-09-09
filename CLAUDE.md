# agent-common-workflow — Claude Code Adapter

> **콘텐츠 정본은 [AGENTS.md](AGENTS.md)입니다.** 이 파일은 Claude Code 전용 어댑터로,
> 정본을 import하고 상시 로드 스킬 주입만 담당합니다.
> 규칙·주의사항을 고칠 때는 이 파일이 아니라 `AGENTS.md`를 고치세요.

@AGENTS.md

## 상시 로드 (Claude 전용 메커니즘)

@skills/workflow/SKILL.md
@skills/brainstorming/SKILL.md
@skills/writing-plans/SKILL.md
@skills/jira-tickets/SKILL.md
@skills/subagent-dev/SKILL.md
@skills/writing-policy/SKILL.md
@skills/gcloud/SKILL.md
@skills/firebase-deploy-safety/SKILL.md
@skills/communication/SKILL.md
@skills/code-conventions/SKILL.md
@skills/ralph-loop/SKILL.md

> opt-in 스킬(`cost-proportionality-review`·`diagnosing-bugs`·`git-guardrails`)은 상시 로드하지 않습니다 —
> `AGENTS.md`의 라우팅 표를 보고 필요할 때 해당 `skills/<이름>/SKILL.md`를 직접 읽으세요.
