# ============================================================
# 用法: bash .git/goal-driven/<task>/poll.sh <round> <max-wait-seconds> [progress-seconds=3600]
# INPUT : logs/round-<round>-worker.{pid,exit}；须在仓库根目录运行
# OUTPUT: 一行状态 DONE | DEAD | NO_PROGRESS | RUNNING；维护 round-<round>-worker.progress
# POS   : Goal-Driven Master 的 Worker 轮询器（Linux/macOS；macOS 用 stat -f %m 替换 stat -c %Y）
# ============================================================
PROGRESS=${3:-3600}
f="$(dirname "$0")/logs/round-$1-worker"; end=$(( $(date +%s) + $2 ))
while :; do
  h=$({ git diff HEAD; git ls-files -o --exclude-standard | git hash-object --stdin-paths; } | git hash-object --stdin)
  [ "$h" = "$(cat "$f.progress" 2>/dev/null)" ] || echo "$h" > "$f.progress"
  kill -0 "$(cat "$f.pid")" 2>/dev/null && alive=1 || alive=0
  [ -f "$f.exit" ] && { echo "DONE exit=$(cat "$f.exit")"; exit; }
  [ $alive = 0 ] && { echo "DEAD"; exit; }
  t=$(date +%s); e=$(( t - $(stat -c %Y "$f.pid") )); s=$(( t - $(stat -c %Y "$f.progress") ))
  m="elapsed=${e}s stale=${s}s"
  [ $s -gt $PROGRESS ] && { echo "NO_PROGRESS $m"; exit; }
  [ $t -ge $end ] && { echo "RUNNING $m"; exit; }
  sleep $(( end - t < 60 ? end - t : 60 ))
done
