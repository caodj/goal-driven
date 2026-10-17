# ============================================================
# 用法: bash .git/goal-driven/<task>/launch.sh <round> <worker args...>
# INPUT : logs/round-<round>-prompt.md；<worker args> 为所选 Worker 命令（不含 -p 及提示词）
# OUTPUT: logs/round-<round>-worker.{pid,log,exit}；立即返回
# POS   : Goal-Driven Master 的 Worker 后台启动器（Linux/macOS）
# ============================================================
f="$(dirname "$0")/logs/round-$1-worker"; p="$(dirname "$0")/logs/round-$1-prompt.md"; shift
setsid bash -c 'echo $$ > "$0.pid"
  "${@:2}" -p "$(cat "$1")" < /dev/null > "$0.log" 2>&1
  echo $? > "$0.exit.tmp" && mv "$0.exit.tmp" "$0.exit"' "$f" "$p" "$@" > /dev/null 2>&1 &
