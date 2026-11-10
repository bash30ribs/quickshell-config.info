#!/usr/bin/env python3
"""
Antigravity Native Stop-Hook Controller for Ralph Loop.
Implements the Stop hook contract in .agents/hooks.json:
- Reads Stop hook JSON payload from stdin
- Evaluates active loop state at ~/.local/state/qdeck/ralph-state.json
- Runs validation command / QML check / completion promise detection
- Returns {"decision": "continue", "reason": "..."} until verified or maxIterations reached
"""

import json
import os
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.join(HOME, ".local", "state")),
    "qdeck",
)
STATE_FILE = os.path.join(STATE_DIR, "ralph-state.json")
LOG_FILE = os.path.join(STATE_DIR, "ralph-history.log")

DEFAULT_WORKSPACE = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
SAFE_STOP_REASONS = {
    "USER_CANCELED",
    "MAX_INVOCATIONS",
    "MAX_FORCED_INVOCATIONS",
    "MAX_TOKEN_BUDGET_EXCEEDED",
    "ERROR",
}


def append_log(message):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"[{ts}] {message}\n")
    except OSError:
        pass


def load_state():
    if not os.path.isfile(STATE_FILE):
        return None
    try:
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else None
    except Exception:
        return None


def save_state(state):
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)
        f.flush()


def extract_last_planner_text(transcript_path):
    if not transcript_path:
        return ""
    candidates = [transcript_path]
    if transcript_path.endswith("transcript.jsonl"):
        full_path = transcript_path[:-len("transcript.jsonl")] + "transcript_full.jsonl"
        if os.path.isfile(full_path):
            candidates.insert(0, full_path)

    for path in candidates:
        if not os.path.isfile(path):
            continue
        last_text = ""
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        step = json.loads(line)
                    except Exception:
                        continue
                    if step.get("type") == "PLANNER_RESPONSE" and step.get("content"):
                        last_text = str(step.get("content", ""))
            if last_text:
                return last_text
        except OSError:
            continue
    return ""


def run_validation_command(cmd, cwd):
    try:
        proc = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=45,
        )
        output = (proc.stdout or "") + ("\n" + proc.stderr if proc.stderr else "")
        output = output.strip()
        if len(output) > 1800:
            output = "...(truncated)...\n" + output[-1800:]
        return proc.returncode, output
    except subprocess.TimeoutExpired:
        return 124, "Validation command timed out after 45 seconds."
    except Exception as exc:
        return 1, f"Failed to execute validation command: {exc}"


def evaluate_hook(payload):
    state = load_state()
    if not state or not state.get("active"):
        return {}

    workspace = state.get("workspace") or payload.get("cwd") or DEFAULT_WORKSPACE
    hook_cwd = payload.get("cwd") or ""
    if hook_cwd and os.path.realpath(hook_cwd) != os.path.realpath(workspace):
        return {}

    term_reason = str(payload.get("terminationReason") or "")
    if term_reason in SAFE_STOP_REASONS:
        state["active"] = False
        state["lastOutcome"] = f"stopped_by_{term_reason.lower()}"
        save_state(state)
        append_log(f"Deactivated safely due to terminationReason={term_reason}")
        return {}

    iteration = int(state.get("iteration", 0))
    max_iterations = int(state.get("maxIterations", 15))
    if iteration >= max_iterations:
        state["active"] = False
        state["lastOutcome"] = "max_iterations_reached"
        save_state(state)
        append_log(f"Max iterations reached ({iteration}/{max_iterations}); releasing control.")
        return {}

    mode = str(state.get("mode", "command")).lower()
    cmd = str(state.get("command", "./scripts/verify.sh --all")).strip()
    promise = str(state.get("completionPromise", "DONE")).strip()
    goal = str(state.get("goal", "")).strip()

    if mode in ("command", "tests", "build"):
        if mode == "build" and not cmd:
            cmd = "./scripts/verify.sh --all"
        rc, output = run_validation_command(cmd, workspace)
        if rc == 0:
            state["active"] = False
            state["lastOutcome"] = "passed"
            save_state(state)
            append_log(f"Validation passed cleanly at iteration {iteration}: `{cmd}`")
            return {}

        iteration += 1
        state["iteration"] = iteration
        state["lastOutcome"] = f"failed_exit_{rc}"
        save_state(state)
        append_log(f"Iteration {iteration}/{max_iterations} failed (exit {rc}); forcing continuation.")

        goal_line = f"\nGoal reminder: {goal}" if goal else ""
        reason = (
            f"[Ralph Loop · Iteration {iteration}/{max_iterations}] "
            f"Validation `{cmd}` failed (exit {rc}):\n"
            f"```\n{output or '(no output)'}\n```\n"
            f"Fix the issues above and verify cleanly before concluding.{goal_line}"
        )
        return {"decision": "continue", "reason": reason}

    if mode == "promise":
        last_reply = extract_last_planner_text(payload.get("transcriptPath", ""))
        if promise and promise in last_reply:
            state["active"] = False
            state["lastOutcome"] = "promise_matched"
            save_state(state)
            append_log(f"Completion promise '{promise}' matched at iteration {iteration}.")
            return {}

        iteration += 1
        state["iteration"] = iteration
        state["lastOutcome"] = "promise_pending"
        save_state(state)
        append_log(f"Iteration {iteration}/{max_iterations}: promise '{promise}' not emitted yet.")

        goal_line = f"\nGoal reminder: {goal}" if goal else ""
        reason = (
            f"[Ralph Loop · Iteration {iteration}/{max_iterations}] "
            f"Completion token `{promise}` was not found in your response. "
            f"Continue iterating cleanly until all requirements are verified, then output `{promise}`.{goal_line}"
        )
        return {"decision": "continue", "reason": reason}

    return {}


def main():
    raw = sys.stdin.read().strip()
    payload = {}
    if raw:
        try:
            payload = json.loads(raw)
        except Exception:
            payload = {}

    result = evaluate_hook(payload)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
