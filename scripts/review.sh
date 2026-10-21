# ============================================================
# 用法: bash .git/goal-driven/<task>/review.sh
# INPUT : 同目录 task.md、state.md（含 "baseline: <完整 SHA>"）；分支 goal-driven/<task>；须在仓库根目录运行
# OUTPUT: stdout 依次为 task.md、state.md、diff --stat、风险扫描（仅提示）；不写任何文件
# POS   : Criteria Task Reviewer 的只读取证器（Linux/macOS）
# ============================================================
d="$(dirname "$0")"; br="goal-driven/$(basename "$d")"
b=$(sed -n 's/^[[:space:]]*baseline:[[:space:]]*\([0-9a-f]\{40\}\).*/\1/p' "$d/state.md" | head -n 1)
[ -n "$b" ] || { echo "baseline: <full SHA> not found in $d/state.md" >&2; exit 1; }
r="$b..$br"

echo "=== task.md ==="; cat "$d/task.md"
echo "=== state.md ==="; cat "$d/state.md"
echo "=== git diff --stat $r ==="; git -c core.quotePath=false diff --stat "$r"
echo "=== risk scan: hints only; still read the full diff ==="

# ------------------------------------------------------------
# 验证相关路径：测试、fixture、快照、CI、测试与检查配置
# ------------------------------------------------------------
echo "--- verification paths ---"
git -c core.quotePath=false diff --name-status "$r" | grep -iE '(^|[/[:space:]])(tests?|specs?|__tests__|fixtures?|snapshots?|__snapshots__|testdata)/|_test\.|\.test\.|\.spec\.|(^|[/[:space:]])test_|\.snap$|(^|[/[:space:]])\.github/|gitlab-ci|jenkinsfile|\.circleci|azure-pipelines|(jest|vitest|karma|playwright)\.config|pytest\.ini|tox\.ini|setup\.cfg|\.coveragerc|codecov|eslint|\.flake8|golangci|clippy|clang-tidy|ruff\.toml|pyproject\.toml|package\.json|makefile|cmakelists\.txt'

# ------------------------------------------------------------
# 风险行：新增行按类别匹配，删除行查断言；<文件>:<行号>，删除行为旧文件行号
# ------------------------------------------------------------
echo "--- risky lines ---"
git -c core.quotePath=false diff -U0 --no-color "$r" | awk '
/^diff --git /  { h = 1; next }
/^@@ /          { split($2, a, ","); ol = -a[1]; split($3, a, ","); nl = a[1] + 0; h = 0; next }
h && /^--- /    { o = substr($0, 5); sub(/^a\//, "", o); next }
h && /^\+\+\+ / { n = substr($0, 5); sub(/^b\//, "", n); next }
h               { next }
/^\+/ {
  l = tolower($0); c = ""
  if (l ~ /skip|xfail|\.only\(|xit\(|xdescribe|@ignore|@disabled|#\[ignore\]/) c = c ",skip"
  if (l ~ /mock|stub|fake|monkeypatch|spyon|sinon/) c = c ",mock"
  if (l ~ /eslint-disable|noqa|type: *ignore|ts-ignore|ts-nocheck|ts-expect-error|nolint|nosec|pylint: *disable|pragma warning|-wno-|suppresswarnings|#\[allow\(/) c = c ",disable-check"
  if (l ~ /toleran|atol|rtol|epsilon|approx|closeto|almostequal/) c = c ",tolerance"
  if (c != "") printf "%s:%d: %s: %s\n", n, nl, substr(c, 2), substr($0, 2, 200)
  nl++; next
}
/^-/ {
  if (tolower($0) ~ /assert|expect|should/) printf "%s:%d (old): removed-assert: %s\n", o, ol, substr($0, 2, 200)
  ol++
}' | awk 'NR <= 200; END { if (NR > 200) print "... " NR - 200 " more" }'
