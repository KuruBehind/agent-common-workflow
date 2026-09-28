"""Claude·Codex 작업 등록, 인계, 인수와 교차 리뷰 명령."""

import argparse
import json
from pathlib import Path
import sys

from bridge_store import commit, git, load, locked, now, record, require_owner, snapshot, task_dir
from bridge_review import review


def parser():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--root", required=True, help="공통 상태 저장소 절대 경로 (작업 레포 밖)")
    commands = cli.add_subparsers(dest="action", required=True)
    for name in ("init", "status", "handoff", "accept", "review"):
        sub = commands.add_parser(name)
        sub.add_argument("--task", required=True)
        if name != "status":
            sub.add_argument("--owner", required=True, help="도구명:세션ID 형식의 담당자 식별자")
        if name == "init":
            sub.add_argument("--repo", required=True)
            sub.add_argument("--base", required=True, help="리뷰 기준 ref (등록 시 SHA로 고정)")
            sub.add_argument("--goal", required=True)
            sub.add_argument("--acceptance", required=True)
        if name == "handoff":
            sub.add_argument("--to", required=True)
            sub.add_argument("--notes", required=True, help="인계 내용을 담은 UTF-8 Markdown 파일")
        if name == "review":
            sub.add_argument("--runner", choices=("claude", "codex"), required=True)
            sub.add_argument("--executable", help="네이티브 CLI 실행 파일 경로")
            sub.add_argument("--timeout", type=int, default=600)
            sub.add_argument("--dry-run", action="store_true")
    return cli


def run(args):
    folder = task_dir(args.root, args.task)
    if args.action != "init" and not (folder / "task.json").is_file():
        raise ValueError("등록되지 않은 작업입니다.")
    if args.action == "init":
        repo = Path(git(Path(args.repo).resolve(), "rev-parse", "--show-toplevel").decode().strip()).resolve()
        if folder.is_relative_to(repo):
            raise ValueError("상태 저장소는 작업 레포 밖에 두세요.")
    with locked(folder):
        if args.action == "init":
            if (folder / "task.json").exists():
                raise ValueError("이미 등록된 작업입니다.")
            task = {"version": 1, "id": args.task, "repo": str(repo), "owner": args.owner,
                    "goal": args.goal, "acceptance": args.acceptance,
                    "base": commit(repo, args.base), "state": "active", "created_at": now(),
                    "snapshot": snapshot(repo)}
            record(folder, task, "registered", {"owner": args.owner})
        else:
            task = load(folder)
            if args.action == "status":
                return {"task": task, "current": snapshot(task["repo"]), "folder": str(folder)}, 0
            if args.action == "accept":
                if task["state"] != "handoff_pending" or task["handoff"]["to"] != args.owner:
                    raise ValueError("지정된 인수 대상만 대기 중 작업을 인수할 수 있습니다.")
                if snapshot(task["repo"]) != task["snapshot"]:
                    raise ValueError("인계 후 코드 상태가 바뀌었습니다. 기존 담당자가 상태를 확인해야 합니다.")
                previous = task["owner"]
                task.update(owner=args.owner, state="active")
                record(folder, task, "accepted", {"from": previous, "to": args.owner})
            elif args.action == "handoff":
                # 기존 담당자는 변경된 상태를 확인한 뒤 인계 내용을 다시 발행할 수 있다.
                if task["owner"] != args.owner or task["state"] not in {"active", "handoff_pending"}:
                    raise ValueError("현재 담당자만 인계할 수 있습니다.")
                if args.to == args.owner:
                    raise ValueError("인수 대상은 현재 담당자와 달라야 합니다.")
                notes = Path(args.notes).read_text(encoding="utf-8-sig")
                if not notes.strip():
                    raise ValueError("인계 내용이 비어 있습니다.")
                from uuid import uuid4
                filename = "handoff-" + uuid4().hex + ".md"
                (folder / filename).write_text(notes, encoding="utf-8")
                task.update(state="handoff_pending", snapshot=snapshot(task["repo"]),
                            handoff={"to": args.to, "notes": filename})
                record(folder, task, "handoff", task["handoff"])
            elif args.action == "review":
                require_owner(task, args.owner)
                if args.timeout <= 0:
                    raise ValueError("제한 시간은 양수여야 합니다.")
                result, destination = review(folder, task, args.runner, args.executable, args.timeout, args.dry_run)
                task["last_review"] = result
                record(folder, task, "review", {"review_id": result["id"], "status": result["status"]})
                return {"result": result, "folder": str(destination)}, 0 if result["status"] in {"prepared", "completed"} else 1
        return {"task": task, "folder": str(folder)}, 0


def main():
    try:
        result, code = run(parser().parse_args())
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return code
    except (OSError, ValueError) as error:
        print(f"오류: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
