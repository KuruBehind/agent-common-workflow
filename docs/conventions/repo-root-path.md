# REPO_ROOT / WORKSPACE_ROOT 경로 패턴

## 레포 구조 유형

### 유형 A — 플랫 구조 (서브 레포가 워크스페이스 루트 바로 아래)
```
dev/
├── agent-common-workflow/
└── kuru-mart/               ← 서브 레포
    └── worktrees/
        └── KM-1-feat/
```

### 유형 B — 중첩 구조 (서브 레포가 인덱스 레포 안에 있음)
```
dev/
├── agent-common-workflow/
└── kuru/                    ← 인덱스 레포
    ├── kuru_mobile/         ← 서브 레포
    └── worktrees/
        └── KM-175-kuru-mobile-feat/
```

## 올바른 패턴

```bash
REPO_ROOT=$(git rev-parse --git-common-dir | xargs dirname)
INDEX_REPO=$(cd "$REPO_ROOT/.." && pwd)    # 서브 레포의 부모 = 인덱스 레포
WORKSPACE_ROOT=$(cd "$INDEX_REPO/.." && pwd)  # 워크스페이스 루트

# agent-common-workflow 위치 자동 탐색 (유형 A/B 모두 대응)
if [ -f "$WORKSPACE_ROOT/agent-common-workflow/.env.local" ]; then
  CW="$WORKSPACE_ROOT/agent-common-workflow"   # 유형 B
else
  CW="$INDEX_REPO/agent-common-workflow"       # 유형 A (INDEX_REPO = WORKSPACE_ROOT)
fi
source "$CW/.env.local"
```

`--git-common-dir`은 워크트리 여부와 무관하게 항상 주 레포의 `.git` 경로를 반환하므로 안정적.

## 적용 대상 — 전수 체크리스트

새 스킬 파일 작성 또는 기존 스킬 수정 시, `../agent-common-workflow` 하드코딩이 없는지 확인:

```bash
grep -r "\.\./agent-common-workflow" skills/
```

결과가 나오면 모두 `$REPO_ROOT/../agent-common-workflow` 패턴으로 교체.

## 현재 적용된 파일

- `skills/workflow/SKILL.md` — Step 1 셋업, Step 7 마무리
- `skills/jira-tickets/SKILL.md` — 자격증명 확인, 에픽/중복 조회, 티켓 생성
