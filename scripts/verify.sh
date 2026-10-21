# ============================================================
# 用法: bash .git/goal-driven/<task>/verify.sh <round> <label> '<command>' [tail-lines=40]
# INPUT : 验证命令字符串（交给 bash -c 执行）；须在仓库根目录运行
# OUTPUT: logs/round-<round>-verify-<label>.log（完整输出）；stdout 为 EXIT/LINES/LOG 一行加日志末尾若干行
# POS   : Goal-Driven Master 的 Criterion 验证执行器（Linux/macOS）
# ============================================================
f="$(dirname "$0")/logs/round-$1-verify-$2.log"
bash -c "$3" < /dev/null > "$f" 2>&1; c=$?
echo "EXIT=$c LINES=$(wc -l < "$f" | tr -d ' ') LOG=$f"
tail -n "${4:-40}" "$f"
