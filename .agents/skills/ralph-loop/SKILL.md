---
name: ralph-loop
description: >-
  Run autonomous Ralph Loop execute -> verify -> fix -> repeat cycles natively
  in Antigravity using the workspace Stop hook or headless `agy -p` PRD mode.
  Activate whenever the user asks to start, check, or stop a Ralph loop or
  loop iteratively until tests, builds, or PRD tasks pass.
---

# Ralph Loop Workflow (Native Antigravity Implementation)

This workspace implements the **Ralph Loop** pattern natively using Antigravity's `Stop` lifecycle hook ([hooks.json](../../../.agents/hooks.json)) and the `./scripts/ralph` CLI controller—no remote debugging CDP ports or third-party VSX injections required.

## Mode 1: In-Session Stop-Hook Loop (`./scripts/ralph start`)

When armed, Antigravity automatically evaluates your completion criteria at the end of every agent turn. If checks fail (or the completion promise has not been emitted), the `Stop` hook blocks stopping and feeds the exact failure output back into the conversation until resolved or `--max` iterations hit.

1. **Tests / Verification Loop** (runs any command cleanly until exit `0`):
   ```bash
   ./scripts/ralph start --mode command --cmd "./scripts/verify.sh --all" --max 15 --goal "Implement feature cleanly"
   ```
2. **Build Loop** (runs `./scripts/verify.sh --all` until zero QML/build errors):
   ```bash
   ./scripts/ralph start --mode build --max 15 --goal "Keep UI syntax clean"
   ```
3. **Self-Judgment Promise Loop** (continues until response contains explicit completion token):
   ```bash
   ./scripts/ralph start --mode promise --promise "DONE" --max 15 --goal "Finish refactor"
   ```
4. **Status & Disarm**:
   ```bash
   ./scripts/ralph status
   ./scripts/ralph stop
   ```

## Mode 2: Fresh-Context `PRD.md` + `progress.txt` Runner (`agy -p`)

For multi-task specs spanning long sessions without context rot:

1. Initialize `.ralph/PRD.md` and `.ralph/progress.txt`:
   ```bash
   ./scripts/ralph init-prd
   ```
2. Add `- [ ]` task bullets to `.ralph/PRD.md`, then execute fresh headless `agy` iterations until every checkbox is `- [x]`:
   ```bash
   ./scripts/ralph run-prd --max 10 --verify "./scripts/verify.sh --all" --auto-approve
   ```

## Verification

Run the Stop-hook contract test anytime to verify hook behavior:
```bash
./scripts/ralph verify
```
