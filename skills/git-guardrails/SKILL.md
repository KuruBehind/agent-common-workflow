---
name: git-guardrails
description: "되돌릴 수 없는 git 명령(reset --hard, clean -f, branch -D, checkout ., restore .)을 훅으로 막는 안전장치 설치 가이드. 프로젝트에 git 안전 훅을 설치하거나 설정할 때 사용. git push는 차단 대상이 아니다."
---

# Git 위험 명령어 하드블록 (opt-in)

> 원본: [mattpocock/skills — git-guardrails-claude-code](https://github.com/mattpocock/skills/tree/main/skills/misc/git-guardrails-claude-code)를 이 팀 상황에 맞게 축소.
> **원본과의 차이**: `git push`/`push --force`는 차단 목록에서 제외했다. 각 프로젝트 `.claude/settings.json`의
> "ask" 권한으로 이미 매번 확인받고 있고, push는 정상 업무에서 수시로 필요한 명령이라 하드블록하면
> 정상 워크플로우가 막힌다. 여기서 막는 건 **정상 업무에서 쓸 일이 거의 없고 되돌릴 수 없는** 명령어만이다.

## 뭐가 다른가 — "ask" 권한과의 차이

지금도 `.claude/settings.json`의 `permissions.ask`에 `git reset --hard`, `git clean` 등이 들어있는 프로젝트가 많다.
하지만 "ask"는 **사람이 확인 버튼을 잘못 누르면 그대로 실행된다.** 이 훅은 Bash 도구 실행 자체를 가로채서
패턴에 걸리면 **확인 절차 없이 무조건 거부**한다 — 실수로 승인하는 경로 자체를 없앤다.

## 차단 대상

- `git reset --hard`
- `git clean -f` / `git clean -fd`
- `git branch -D`
- `git checkout .` / `git restore .`

(`git push`, `git push --force`는 의도적으로 제외 — 위 설명 참조)

## 설치 방법

프로젝트별로 opt-in — 필요한 레포에만 설치한다.

1. `scripts/block-dangerous-git.sh`를 그 레포의 `.claude/hooks/block-dangerous-git.sh`로 복사
2. 실행 권한 부여: `chmod +x .claude/hooks/block-dangerous-git.sh`
3. 그 레포의 `.claude/settings.json`에 아래 추가 (기존 `hooks.PreToolUse`가 있으면 배열에 병합):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

4. 검증:
   ```bash
   echo '{"tool_input":{"command":"git reset --hard"}}' | .claude/hooks/block-dangerous-git.sh
   ```
   종료 코드 2, stderr에 `BLOCKED: ...` 메시지가 나오면 정상.