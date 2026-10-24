# goal-driven

English | [简体中文](README.zh-CN.md)

Prompts for running long, complex, objectively verifiable tasks with a Master Agent that keeps dispatching Workers until every success criterion is independently verified.

Inspired by [lidangzzz/goal-driven](https://github.com/lidangzzz/goal-driven).

```text
while (criteria not met)
{
    let the worker work on solving the problem and achieving the Goal
}
```

## Files

| File | Used by | Purpose |
|---|---|---|
| `Criteria Task Designer.md` | Your strongest chat model | Discuss requirements, generate the task, generate follow-up tasks |
| `Criteria Task Reviewer.md` | An agent with repository access, ideally a different model | Independently review a completed task |
| `Goal-Driven.md` | The Master Agent | Dispatch Workers, verify every Criterion, checkpoint, commit |
| `scripts/` | The Master Agent; `review` by the reviewer | Detached Worker launch and polling (`launch` / `poll`), verification runs (`verify`), review evidence (`review`); `.sh` and `.ps1` |

## Prerequisites

* The target project is a git repository.
* The `Worker command` and `Worker report` lines at the top of `Goal-Driven.md` are set (see [Worker examples](#worker-examples)), and that Worker CLI is installed and works.
* The Master's shell is bash (Linux/macOS) or PowerShell 7 (Windows). On macOS, `setsid` comes from util-linux, and `poll.sh` needs `stat -f %m` instead of `stat -c %Y`.
* The `Scripts directory` line at the top of `Goal-Driven.md` is set to the absolute path of this repository's `scripts/`, and the Master can read it.
* The Master Agent has `Goal-Driven.md` loaded as its instructions.
* With Codex as the Master, set `background_terminal_max_timeout = 3600000` in `~/.codex/config.toml`; otherwise each wait on a running command is capped at 5 minutes.

## Workflow

```mermaid
flowchart TD
    A[Design conversation: discuss requirements] --> B[Generate task block]
    B --> C[Master runs on a goal-driven/* branch]
    C -->|stopped by blocker| D[Fix blocker, resume]
    D --> C
    C -->|SUCCESS| E[Review in a new conversation]
    E -->|accepted findings| F[Back to design conversation: generate follow-up]
    F --> C
    E -->|PASS| G[Merge the last branch]
```

### 1. Discuss and generate the task

Open a conversation with `Criteria Task Designer.md` as the prompt. Talk through requirements and fragmented ideas freely; the model tracks what is confirmed, revised, or dropped, and points out decisions that would change the Criteria.

When ready, ask it to generate the task. It outputs only:

```text
Goal: [[[[[ ... ]]]]]
Criteria for success: [[[[[ ... ]]]]]
```

Review the Criteria carefully. The Master runs until every Criterion passes, so a weak Criterion produces a wrong "success". Keep a copy of the block; you need it to resume and for review.

### 2. Prepare

* Check out the branch to start from, usually `main`.
* Uncommitted changes are allowed and protected as the baseline, but committing or cleaning them first is simpler.

### 3. Run the Master

You do not hand the scripts to the Master in the message. The Master finds them through the `Scripts directory` line at the top of its loaded `Goal-Driven.md`, so that line must be the absolute path of this repository's `scripts/`, for example `E:/goal-driven/scripts`.

Start the Master session at the target project's repository root, make sure it has `Goal-Driven.md` loaded, and send it the task block. Before the first Worker, it:

1. records the baseline: HEAD, stash list, status, diff, original branch;
2. creates branch `goal-driven/<task-name>` and task directory `.git/goal-driven/<task-name>/`;
3. saves `task.md` (the verbatim task block) and `rules.md` (a copy of `Goal-Driven.md`) in the task directory, and copies `launch`, `poll`, `verify`, and `review` for its shell from the Scripts directory (`.sh` for bash, `.ps1` for PowerShell 7). If the Scripts directory is unreadable, it stops and reports.

Each round, the Master writes the Worker Prompt to `logs/round-<N>-prompt.md`, starts the Worker in the background with the copied `launch`, waits for it with `poll`, then inspects the changes, verifies every Criterion, and commits accepted changes as a checkpoint.

**Do not edit the workspace while it runs.** The Master would treat your edits as Worker changes.

Monitor progress with:

* `git log --oneline`: a checkpoint commit for each round that left in-scope changes without regressing a passed Criterion, then a final commit once every Criterion passes;
* `.git/goal-driven/<task-name>/state.md`: passed and unmet Criteria, failed approaches;
* `.git/goal-driven/<task-name>/logs/`: full Worker and verification output.

### 4. Interruptions and resume

The Master stops only on blockers no Worker round can fix: the Worker command or the Scripts directory is unavailable, baseline changes are at risk, or a Criterion cannot be verified in the environment. Lack of progress is not a stop reason; the Master changes approach instead.

To resume after fixing the blocker, or after the Master session ends unexpectedly: stay on the task's `goal-driven/<task-name>` branch, start a new Master session, and send the **identical** task block. The Master continues from the last checkpoint. This also covers the Master stopping on a usage limit: it first makes sure no Worker from the previous session is still running, then inspects and verifies any unfinished round's changes before dispatching the next Worker. To continue with a different Worker, change the `Worker command` and `Worker report` lines first; the resumed Master uses them.

While fixing the blocker, do not commit, reset, or switch branches, and leave no edits in the workspace: on resume the Master stops if HEAD is not the last checkpoint, and treats any uncommitted non-baseline change as an unfinished Worker round.

### 5. Review in a new conversation

After `SUCCESS: ALL CRITERIA MET`, open a **new** conversation in an agent that can read the repository and run `git` (for example, Cursor), paste `Criteria Task Reviewer.md`, and give it the branch `goal-driven/<task-name>`. The reviewer reads `task.md` and `state.md` from the task directory and runs the diff itself, without modifying anything. If the task directory has the `review` script, the reviewer runs it first to collect this evidence in one call; its risk scan only gives hints, and the reviewer still reads the full diff.

A separate reviewer prompt and conversation keep the review independent of the design discussion and save the design conversation's context. Using a different model than the designer reduces shared blind spots. If the reviewer has no repository access, provide the task block, `git diff <baseline>..goal-driven/<task-name>` (baseline HEAD from `state.md`), and `state.md` yourself; for a large diff, send `git diff --stat` first, then files on request.

The review outputs `VERDICT: PASS | FAIL` and findings labeled `[UNMET]`, `[NEW REQUIREMENT]`, or `[SUGGESTION]`. Suggestions are subjective; decide yourself.

### 6. Follow-up task

Paste the findings you accept back into the design conversation and ask for a follow-up task. It restates every Criterion from earlier tasks as non-regression criteria and tightens any Criterion that let an `[UNMET]` problem pass.

If you generate it in a new conversation instead, paste every earlier task block of the chain too.

Then stay on the previous `goal-driven/*` branch and send the follow-up block to the Master. When it asks whether to stack on that branch, choose stack. Repeat review and follow-up until the review passes.

### 7. Merge and clean up

The Master never merges. Merge the **last** branch of the chain; it contains every round:

```bash
git switch main
git merge --squash goal-driven/<last-task-name>
git commit -m "<description>"
git branch -D goal-driven/<task-name>    # each branch in the chain
```

Task directories under `.git/goal-driven/` are never deleted automatically; remove them when no longer needed.

If a baseline uncommitted change touches a file the task also changed, `git switch main` may refuse; resolve that change first.

## Worker examples

The Master runs the Worker given by the `Worker command` and `Worker report` lines at the top of `Goal-Driven.md`; the task block does not choose it. To use another CLI or model, replace those two lines. The launch script appends `-p <prompt>` to the command, so the CLI must accept it. Keep a streaming output mode: `poll` treats a log that stops growing as idle.

agy (default):

```text
Worker command: `agy --model gemini-3.8-flash --effort high --dangerously-skip-permissions --output-format stream-json`
Worker report: the last `{"event":"result"}` line; `result.status` and `result.response`.
```

pi:

```text
Worker command: `pi -a --model llama-local/qwen3.8-27b --mode json`
Worker report: the last `{"type":"turn_end"}` line; the text in `message.content`.
```

cursor:

```text
Worker command: `agent --model grok-4.7-xhigh --force --print --output-format stream-json`
Worker report: the last `{"type":"result"}` line; `is_error` and `result`.
```

## Task directory layout

```text
.git/goal-driven/<task-name>/
├── <baseline>      # HEAD, stash list, status, diff, original branch (named by the Master)
├── task.md         # verbatim task block
├── rules.md        # copy of Goal-Driven.md used by this task
├── state.md        # goal, status, checkpoints, Criteria, failed approaches
├── launch.* poll.* verify.* review.*  # copied from scripts/ for the Master's shell (.sh or .ps1)
└── logs/
    ├── round-<N>-prompt.md     # this round's Worker Prompt
    ├── round-<N>-worker.pid    # Worker wrapper PID; mtime is the start time
    ├── round-<N>-worker.log    # raw Worker output (streamed events)
    ├── round-<N>-worker.exit   # Worker exit code, written only after exit
    ├── round-<N>-worker.progress  # workspace fingerprint, rewritten only on change; mtime is the last progress time
    └── round-<N>-verify-<label>.log  # full output of one verification command
```

Everything lives inside `.git/`, so it is never tracked or committed. One branch maps to one task directory; a new Goal always gets a new one.

## Acknowledgments

This project is inspired by [lidangzzz/goal-driven](https://github.com/lidangzzz/goal-driven), which introduced the Goal-Driven approach: a Goal, strict Criteria for success, and a Master Agent that keeps a subagent working until the Criteria are met. Many thanks to its author for the idea.
