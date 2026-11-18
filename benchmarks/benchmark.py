#!/usr/bin/env python3
"""Reproducible synthetic status line benchmark; Python is a dev-only dependency."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import statistics
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parent.parent
MODEL = "claude-sonnet-4-20250514"


def make_history(config, mib, sessions):
    project = config / "projects" / "benchmark"
    project.mkdir(parents=True)
    # Match Claude Code's millisecond UTC timestamps, including the literal Z.
    stamp = datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
    count = 0
    for session in range(sessions):
        size = 0
        with (project / f"bench-{session}.jsonl").open("w") as file:
            while size < mib * 1024 * 1024 / sessions:
                row = {
                    "type": "assistant", "timestamp": stamp, "sessionId": f"bench-{session}",
                    "uuid": f"uuid-{count}", "requestId": f"req-{count}", "costUSD": 0.0006,
                    "message": {"id": f"msg-{count}", "role": "assistant", "model": MODEL,
                                "content": [{"type": "text", "text": "x" * 1024}],
                                "usage": {"input_tokens": 100, "output_tokens": 20,
                                          "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}},
                }
                line = json.dumps(row, separators=(",", ":")) + "\n"
                file.write(line)
                size += len(line.encode())
                count += 1
    return {"messages": count, "input_tokens": count * 100, "sessions": sessions,
            "bytes": sum(p.stat().st_size for p in project.glob("*.jsonl")),
            "timestamp": stamp}


def peak_rss_mib(raw, system):
    if system == "Darwin":
        match = re.search(r"(\d+)\s+maximum resident set size", raw)
        divisor = 1024 * 1024
    elif system == "Linux":
        match = re.search(r"Maximum resident set size \(kbytes\):\s*(\d+)", raw)
        divisor = 1024
    else:
        return None
    return int(match[1]) / divisor if match else None


def measure(command, payload, env, work, name, timeout):
    stats = work / f"{name}.time"
    system = platform.system()
    timed = system in ("Darwin", "Linux") and Path("/usr/bin/time").exists()
    argv = command
    if timed:
        argv = ["/usr/bin/time", "-l" if system == "Darwin" else "-v", "-o", str(stats), *command]
    start = time.perf_counter()
    proc = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, env=env, cwd=work, start_new_session=os.name == "posix")
    try:
        stdout, stderr = proc.communicate(payload, timeout=timeout)
    except subprocess.TimeoutExpired:
        if os.name == "posix":
            os.killpg(proc.pid, signal.SIGKILL)
        else:
            subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
            proc.kill()
        proc.communicate()
        raise RuntimeError(f"Timed out: {command}") from None
    elapsed = time.perf_counter() - start
    if proc.returncode or not stdout.strip() or "statusline error" in stdout:
        raise RuntimeError(f"Invalid measurement: {command}, exit={proc.returncode}, stderr={stderr}, stdout={stdout}")
    raw = stats.read_text() if timed else ""
    rss = peak_rss_mib(raw, system)
    if timed and rss is None:
        raise RuntimeError(f"Cannot parse /usr/bin/time output: {raw}")
    return {"elapsed_seconds": elapsed, "peak_rss_mib": rss, "time_raw": raw,
            "stdout": stdout, "stderr": stderr, "exit_code": proc.returncode}


def positive(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def benchmark_case(name, command, history, windows, args, config, env, work):
    payloads = [json.dumps({"session_id": f"bench-{i}", "model": {"id": MODEL, "display_name": "Sonnet"},
                           "cost": {"total_cost_usd": 3.14},
                           "context_window": {"used_percentage": 42, "total_input_tokens": 84000,
                                              "total_output_tokens": 1000, "context_window_size": 200000},
                           "workspace": {"current_dir": "/benchmark"}, "cwd": "/benchmark",
                           "transcript_path": str(config / "projects" / "benchmark" / f"bench-{i}.jsonl")})
                for i in range(windows)]
    case = {"tool": name, "command": command, "history": history, "windows": windows,
            "stdin": [json.loads(payload) for payload in payloads], "batches": []}
    day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    costs = Path(env["CLAUDE_COST_DIR"]) / day
    costs.mkdir(parents=True, exist_ok=True)
    for i in range(args.sessions):
        (costs / f"bench-{i}").write_text("0 3.14 0\n")
    for repeat in range(args.repeats):
        # Priming is outside measurement; don't call this a guaranteed cache hit.
        if name == "ccusage-primed-unchanged":
            for i, payload in enumerate(payloads):
                measure(command, payload, env, work, f"prime-{i}", args.timeout)
        barrier = threading.Barrier(windows)

        def invoke(i):
            barrier.wait()
            return measure(command, payloads[i], env, work, f"run-{i}", args.timeout)

        start = time.perf_counter()
        with ThreadPoolExecutor(max_workers=windows) as pool:
            samples = list(pool.map(invoke, range(windows)))
        case["batches"].append({"elapsed_seconds": time.perf_counter() - start, "samples": samples})
    elapsed = statistics.median(batch["elapsed_seconds"] for batch in case["batches"])
    rss = [sample["peak_rss_mib"] for batch in case["batches"] for sample in batch["samples"]
           if sample["peak_rss_mib"] is not None]
    memory = f"{statistics.median(rss):.2f} MiB" if rss else "unavailable"
    print(f"{history['bytes'] / 1024**2:.1f} MiB history | {windows} windows | {name}: "
          f"{elapsed:.4f}s batch median, {memory} per-invocation RSS median", flush=True)
    return case


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--history-mib", type=positive, nargs="+", default=[1, 32])
    parser.add_argument("--windows", type=positive, nargs="+", default=[1, 6])
    parser.add_argument("--repeats", type=positive, default=3)
    parser.add_argument("--sessions", type=positive, default=40)
    parser.add_argument("--timeout", type=positive, default=60)
    parser.add_argument("--ccusage", action="store_true", help="also benchmark the installed ccusage (no download)")
    parser.add_argument("--output", type=Path, required=True, help="new JSON output path; existing files are not replaced")
    args = parser.parse_args()
    if max(args.windows) > args.sessions:
        parser.error("--sessions must be at least the largest --windows value")
    if args.output.exists():
        parser.error("output already exists; choose a new path")
    commands = {"statusline.sh": ["sh", (ROOT / "statusline.sh").as_posix()],
                "statusline-today.sh": ["sh", (ROOT / "statusline-today.sh").as_posix()]}
    ccusage = shutil.which("ccusage") if args.ccusage else None
    if args.ccusage and not ccusage:
        parser.error("ccusage is not installed")
    versions = {"python": platform.python_version(),
                "jq": subprocess.check_output(["jq", "--version"], text=True).strip()}
    if ccusage:
        versions["ccusage"] = subprocess.check_output([ccusage, "--version"], text=True).strip()
    report = {"created_at": datetime.now(timezone.utc).isoformat(), "platform": platform.platform(),
              "machine": platform.machine(), "versions": versions,
              "parameters": {**vars(args), "output": str(args.output)},
              "source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                                for name in ("statusline.sh", "statusline-today.sh", "benchmarks/benchmark.py")},
              "cases": []}
    with tempfile.TemporaryDirectory(prefix="cc-usage-bench-") as temp:
        work = Path(temp)
        config_file = work / "ccusage.json"
        config_file.write_text("{}\n")
        if ccusage:
            shared = [ccusage, "statusline", "--offline", "--config", str(config_file)]
            commands["ccusage-no-cache"] = [*shared, "--no-cache"]
            commands["ccusage-primed-unchanged"] = [*shared, "--cache", "--refresh-interval", "3600"]
        for mib in args.history_mib:
            config = work / f"history-{mib}"
            history = make_history(config, mib, args.sessions)
            env = dict(os.environ, CLAUDE_CONFIG_DIR=config.as_posix(), XDG_CONFIG_HOME=(work / "config").as_posix(),
                       XDG_CACHE_HOME=(work / "cache").as_posix(), CLAUDE_COST_DIR=(work / "cost").as_posix(),
                       TMPDIR=work.as_posix(), TMP=work.as_posix(), TEMP=work.as_posix(), TZ="UTC", LC_ALL="C", NO_COLOR="1")
            # Prove the installed parser counted the generated messages, not an empty dataset.
            if ccusage:
                checked = subprocess.run([ccusage, "claude", "daily", "--json", "--offline",
                                          "--config", str(config_file), "--timezone", "UTC"],
                                         env=env, cwd=work, text=True, capture_output=True, timeout=args.timeout, check=True)
                daily = json.loads(checked.stdout)
                if sum(row["inputTokens"] for row in daily["daily"]) != history["input_tokens"]:
                    raise RuntimeError("ccusage did not count the synthetic dataset correctly")
                history["ccusage_validation"] = daily
            for windows in args.windows:
                for name, command in commands.items():
                    report["cases"].append(benchmark_case(name, command, history, windows, args, config, env, work))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x") as output:
        json.dump(report, output, indent=2)
        output.write("\n")


if __name__ == "__main__":
    main()
