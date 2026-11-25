#!/usr/bin/env bash
# prune-worktrees.sh — 다 쓴 git 워크트리를 자동 정리
#
# 배경:
#   인덱스 레포 패턴은 작업마다 <인덱스>/worktrees/ 에 워크트리를 만든다. 세션 종결(Step 8)에서
#   지우는 규칙만으로는 정리가 안 돼 한 머신에 1,400개가 쌓였고(2026-11-25), 에디터 언어 서버가
#   그 안의 프로젝트를 모두 분석해 메모리 30GB 이상을 점유했다. 그래서 정리를 기계에 맡긴다.
#
# 지우는 것 (모두 만족할 때만):
#   - 미커밋 수정·추적 안 된 파일이 없다 (git 이 무시하는 파일은 상관없음)
#   - HEAD 가 원격 기본 브랜치(origin/HEAD·dev·main·master)에 이미 들어 있거나,
#     올렸던 원격 브랜치가 지워졌다 (squash 머지 후 브랜치 삭제)
#   - 마지막 활동(마지막 커밋·체크아웃·인덱스 갱신 중 가장 최근)이 N일(기본 3일) 지났다
#     → 방금 만들어 아직 커밋이 없는 워크트리는 다른 세션이 쓰는 중일 수 있어 건드리지 않는다
#   + git 워크트리가 아닌 빈 폴더
#
# 안전성:
#   `git worktree remove` 를 --force 없이 쓴다. 폴더만 지우고 브랜치·커밋은 남으며,
#   수정이 있거나 잠긴(lock) 워크트리는 git 이 거부한다. 그래서 확인 없이 자동 실행해도 잃는 것이 없다.
#   내용이 있는데 git 워크트리가 아닌 폴더는 보고만 한다.
#
# 사용법:
#   bash tools/prune-worktrees.sh [--dry-run] [--days N] <인덱스 레포 경로>...
#   예) bash tools/prune-worktrees.sh --dry-run ~/Desktop/dev/kuru
#   워크트리 폴더 이름이 worktrees 가 아니면 WORKTREES_DIRNAME 환경변수로 지정.
#   정기 실행 등록은 README 「워크트리 자동 정리」 절.

set -uo pipefail

DRY_RUN=0
DAYS=3
ROOTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --days) shift; DAYS="$1" ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    *) ROOTS+=("$1") ;;
  esac
  shift
done
[ ${#ROOTS[@]} -gt 0 ] || { echo "인덱스 레포 경로를 지정하세요 (--help)"; exit 2; }

WT_NAME="${WORKTREES_DIRNAME:-worktrees}"
NOW=$(date +%s)
LIMIT=$((DAYS * 86400))
# 비대화 실행에서 인증 프롬프트로 멈추지 않게
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=15}"

# 파일 수정 시각(epoch). GNU(리눅스·Git Bash) / BSD(macOS) 둘 다 지원
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

declare -A FETCHED=()
removed=0; kept_dirty=0; kept_active=0; kept_unmerged=0; failed=0; rmdirs=0; orphans=0

echo "== prune-worktrees $(date '+%Y-%m-%d %H:%M:%S') days=$DAYS dry_run=$DRY_RUN"

for root in "${ROOTS[@]}"; do
  dir="$root/$WT_NAME"
  [ -d "$dir" ] || { echo "건너뜀: $dir 없음"; continue; }

  # 한 번에 여러 세션이 돌지 않게
  lock="$dir/.prune-worktrees.lock"
  mkdir "$lock" 2>/dev/null || { echo "건너뜀: $dir 다른 정리가 실행 중"; continue; }
  trap 'rmdir "$lock" 2>/dev/null' EXIT

  for wt in "$dir"/*/; do
    wt="${wt%/}"; name="${wt##*/}"
    [ -d "$wt" ] || continue

    # git 워크트리가 아닌 폴더: 비었으면 지우고, 아니면 보고만
    if [ ! -e "$wt/.git" ]; then
      if [ -z "$(ls -A "$wt" 2>/dev/null)" ]; then
        [ $DRY_RUN -eq 1 ] || rmdir "$wt"
        rmdirs=$((rmdirs + 1))
      else
        orphans=$((orphans + 1))
      fi
      continue
    fi

    common=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { failed=$((failed + 1)); echo "실패(레포 못 찾음): $name"; continue; }
    gitdir=$(git -C "$wt" rev-parse --path-format=absolute --git-dir 2>/dev/null)
    # 메인 체크아웃 자체는 대상 아님
    [ "$common" = "$gitdir" ] && continue

    # 원래 레포당 fetch 1회 (지워진 원격 브랜치를 알기 위해 --prune)
    if [ -z "${FETCHED[$common]:-}" ]; then
      git --git-dir="$common" fetch --prune -q origin 2>/dev/null || echo "경고: fetch 실패 $common (이전 원격 정보로 판단)"
      FETCHED[$common]=1
    fi

    # 마지막 활동 = 마지막 커밋과 HEAD 이동(생성·체크아웃·커밋·리셋) 중 최근.
    # index 는 git status 가 갱신해 버려 신호로 쓰지 않는다 — 반드시 status 전에 잰다
    last=$(git -C "$wt" log -1 --format=%ct 2>/dev/null || echo 0)
    for f in "$gitdir/HEAD" "$gitdir/logs/HEAD"; do
      t=$(mtime "$f"); [ "$t" -gt "$last" ] && last=$t
    done
    if [ $((NOW - last)) -lt $LIMIT ]; then
      kept_active=$((kept_active + 1)); continue
    fi

    if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null | head -1)" ]; then
      kept_dirty=$((kept_dirty + 1)); echo "유지(수정 있음): $name"; continue
    fi

    head=$(git -C "$wt" rev-parse HEAD 2>/dev/null)
    merged=0
    for base in $(git --git-dir="$common" symbolic-ref -q --short refs/remotes/origin/HEAD) origin/dev origin/main origin/master; do
      git --git-dir="$common" rev-parse -q --verify "$base" >/dev/null || continue
      if git --git-dir="$common" merge-base --is-ancestor "$head" "$base" 2>/dev/null; then merged=1; break; fi
    done
    if [ $merged -eq 0 ]; then
      branch=$(git -C "$wt" symbolic-ref -q --short HEAD)
      up=$([ -n "$branch" ] && git -C "$wt" rev-parse -q --abbrev-ref "$branch@{upstream}" 2>/dev/null)
      # 올렸던 원격 브랜치가 지워졌다 = 머지 후 삭제
      if [ -n "$up" ] && ! git --git-dir="$common" rev-parse -q --verify "refs/remotes/$up" >/dev/null; then merged=1; fi
    fi
    if [ $merged -eq 0 ]; then
      kept_unmerged=$((kept_unmerged + 1)); continue
    fi

    if [ $DRY_RUN -eq 1 ]; then
      echo "삭제 예정: $name"; removed=$((removed + 1))
    elif git --git-dir="$common" worktree remove "$wt" 2>/dev/null; then
      removed=$((removed + 1))
    else
      failed=$((failed + 1)); echo "실패(git 이 거부 — 잠김·긴 경로 등): $name"
    fi
  done

  [ $DRY_RUN -eq 1 ] || for c in "${!FETCHED[@]}"; do git --git-dir="$c" worktree prune 2>/dev/null; done
  rmdir "$lock" 2>/dev/null; trap - EXIT
done

echo "결과: 삭제 $removed · 빈 폴더 $rmdirs · 유지(수정 있음) $kept_dirty · 유지(최근 활동) $kept_active · 유지(미머지) $kept_unmerged · git 아닌 폴더 $orphans · 실패 $failed"
