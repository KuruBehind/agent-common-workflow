"""공통 작업 상태와 Git 내용 지문을 관리한다."""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from contextlib import contextmanager
from datetime import datetime, timezone
from uuid import uuid4


def now():
    return datetime.now(timezone.utc).isoformat()


def git(repo, *args):
    result = subprocess.run(
        ["git", "-C", str(repo), *args], capture_output=True, check=False
    )
    if result.returncode:
        raise ValueError(result.stderr.decode("utf-8", errors="replace").strip())
    return result.stdout


def commit(repo, ref):
    return git(repo, "rev-parse", "--verify", "--end-of-options", ref + "^{commit}").decode().strip()


def snapshot(repo):
    head = commit(repo, "HEAD")
    status = git(repo, "status", "--porcelain=v1", "-z", "--untracked-files=all")
    digest = hashlib.sha256(head.encode() + status)
    digest.update(git(repo, "diff", "--no-ext-diff", "--no-textconv", "--binary", "HEAD", "--"))
    digest.update(git(repo, "diff", "--no-ext-diff", "--no-textconv", "--binary", "--cached", "--"))
    untracked = git(repo, "ls-files", "--others", "--exclude-standard", "-z")
    for raw in untracked.split(b"\0"):
        if raw:
            path = Path(repo) / os.fsdecode(raw)
            digest.update(raw)
            if path.is_symlink():
                digest.update(os.fsencode(os.readlink(path)))
            else:
                with path.open("rb") as stream:
                    for block in iter(lambda: stream.read(1024 * 1024), b""):
                        digest.update(block)
    return {
        "head": head,
        "branch": git(repo, "branch", "--show-current").decode().strip(),
        "dirty": bool(status),
        "status": status.decode("utf-8", errors="replace").replace("\0", "\n"),
        "fingerprint": digest.hexdigest(),
    }


def save(path, value):
    temporary = path.with_name(path.name + "." + uuid4().hex + ".tmp")
    try:
        with temporary.open("x", encoding="utf-8") as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def task_dir(root, task):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,99}", task):
        raise ValueError("작업 ID는 영문·숫자·하이픈·밑줄만 사용하세요.")
    if task.split(".")[0].upper() in {"CON", "PRN", "AUX", "NUL", *[f"COM{i}" for i in range(1, 10)], *[f"LPT{i}" for i in range(1, 10)]}:
        raise ValueError("운영체제 예약 이름은 작업 ID로 사용할 수 없습니다.")
    return Path(root).resolve() / task


@contextmanager
def locked(folder):
    folder.mkdir(parents=True, exist_ok=True)
    lock = folder / ".lock"
    try:
        descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        raise ValueError(f"작업이 잠겨 있습니다: {lock}. 실행 중 프로세스를 확인하세요.") from None
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump({"pid": os.getpid(), "created_at": now()}, stream)
        yield
    finally:
        lock.unlink(missing_ok=True)


def load(folder):
    with (folder / "task.json").open(encoding="utf-8") as stream:
        return json.load(stream)


def require_owner(task, owner):
    if task["owner"] != owner or task["state"] != "active":
        raise ValueError("현재 작업 담당자만 활성 작업을 변경할 수 있습니다.")


def record(folder, task, kind, detail):
    event = {"id": uuid4().hex, "at": now(), "kind": kind, "detail": detail}
    messages = folder / "messages"
    messages.mkdir(exist_ok=True)
    save(messages / (event["id"] + ".json"), event)
    task["updated_at"] = event["at"]
    save(folder / "task.json", task)
