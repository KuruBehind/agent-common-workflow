#!/usr/bin/env bash
# sync-agent-skills.sh — 스킬을 Claude Code / Codex 양쪽 규약으로 배포
#
# 배경:
#   두 도구는 SKILL.md 포맷(name/description frontmatter, references/·scripts/)이 사실상 동일하고
#   탐색 경로만 다르다.
#     Claude : <repo>/.claude/skills/  ·  ~/.claude/skills/   (커스텀 경로 지정 불가)
#     Codex  : <repo>/.agents/skills/  ·  ~/.agents/skills/
#   심볼릭 링크는 이 팀 환경에서 git core.symlinks=false 라 커밋 시 깨지므로 복사 방식을 쓴다.
#
# 두 가지를 한다:
#   1) 공통 스킬 → 사용자 스코프(~/.claude/skills, ~/.agents/skills)
#      → 크로스레포 접근·권한 프롬프트 없이 모든 레포에서 조건부 로드된다.
#        (상시 @import 하던 1,400여 줄이 필요할 때만 로드되도록 바뀜)
#   2) 레포 고유 스킬 <repo>/.agents/skills → <repo>/.claude/skills
#      → .agents/ 가 정본(벤더 중립), .claude/ 는 생성물. 둘 다 커밋한다.
#        (gitignore 하면 클론 직후 sync 안 돌린 사람이 스킬을 조용히 잃는다)
#
# 사용법:
#   bash tools/sync-agent-skills.sh                    # 공통 스킬만
#   bash tools/sync-agent-skills.sh ../kuru            # 공통 + 해당 워크스페이스(및 서브레포)
#   bash tools/sync-agent-skills.sh ../kuru ../pin     # 여러 워크스페이스

set -euo pipefail

COMMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
total=0

count_skills() { find "$1" -name SKILL.md 2>/dev/null | wc -l | tr -d ' '; }

# 대상 디렉토리를 통째로 갈아끼운다 (삭제된 스킬이 남는 것 방지)
replace_dir() {
  local src="$1" dst="$2" label="$3"
  [ -d "$src" ] || return 0
  local n; n=$(count_skills "$src")
  [ "$n" -eq 0 ] && return 0
  rm -rf "$dst"; mkdir -p "$(dirname "$dst")"; cp -r "$src" "$dst"
  echo "  ${label} → ${dst}  (${n}개)"
  total=$((total + n))
}

echo "== 1) 공통 스킬 → 사용자 스코프 (모든 레포에서 조건부 로드) =="
replace_dir "$COMMON_ROOT/skills" "$HOME/.claude/skills" "Claude"
replace_dir "$COMMON_ROOT/skills" "$HOME/.agents/skills" "Codex "

for ws in "$@"; do
  ws="$(cd "$ws" && pwd)"
  echo "== 2) $(basename "$ws") 레포 고유 스킬 (.agents → .claude) =="

  replace_dir "$ws/.agents/skills" "$ws/.claude/skills" "$(basename "$ws")"

  for sub in "$ws"/*/; do
    name="$(basename "$sub")"
    case "$name" in
      worktrees|node_modules|.*) continue ;;
      *-feat-*|*-fix-*|*-chore-*|*-hotfix-*|*-merge-*|*-ci-*|*-perf-*|*-style-*) continue ;;
    esac
    [ -e "$sub/.git" ] || continue
    replace_dir "$sub/.agents/skills" "$sub/.claude/skills" "$name"
  done
done

echo
echo "완료: SKILL.md ${total}개 배포"
echo
echo "규칙:"
echo "  · 공통 스킬 수정 → agent-common-workflow/skills/ 에서. 수정 후 이 스크립트 재실행"
echo "  · 레포 고유 스킬 수정 → 해당 레포 .agents/skills/ 에서. .claude/skills/ 는 생성물이니 직접 고치지 말 것"
echo "  · 공통 레포를 git pull 한 뒤에도 재실행해야 사용자 스코프에 반영된다"
