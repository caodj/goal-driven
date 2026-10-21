# ============================================================
# 用法: pwsh -NoProfile -File .git/goal-driven/<task>/review.ps1
# INPUT : 同目录 task.md、state.md（含 "baseline: <完整 SHA>"）；分支 goal-driven/<task>；须在仓库根目录运行
# OUTPUT: stdout 依次为 task.md、state.md、diff --stat、风险扫描（仅提示）；不写任何文件
# POS   : Criteria Task Reviewer 的只读取证器（Windows, PowerShell 7）
# ============================================================
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$d = $PSScriptRoot; $br = "goal-driven/$(Split-Path $d -Leaf)"
$b = foreach ($l in Get-Content "$d\state.md") { if ($l -match '^\s*baseline:\s*([0-9a-f]{40})') { $Matches[1]; break } }
if (-not $b) { [Console]::Error.WriteLine("baseline: <full SHA> not found in $d\state.md"); exit 1 }
$r = "$b..$br"

"=== task.md ==="; Get-Content "$d\task.md"
"=== state.md ==="; Get-Content "$d\state.md"
"=== git diff --stat $r ==="; git -c core.quotePath=false diff --stat $r
"=== risk scan: hints only; still read the full diff ==="

# ------------------------------------------------------------
# 验证相关路径：测试、fixture、快照、CI、测试与检查配置
# ------------------------------------------------------------
"--- verification paths ---"
git -c core.quotePath=false diff --name-status $r | Where-Object { $_ -match '(^|[/\s])(tests?|specs?|__tests__|fixtures?|snapshots?|__snapshots__|testdata)/|_test\.|\.test\.|\.spec\.|(^|[/\s])test_|\.snap$|(^|[/\s])\.github/|gitlab-ci|jenkinsfile|\.circleci|azure-pipelines|(jest|vitest|karma|playwright)\.config|pytest\.ini|tox\.ini|setup\.cfg|\.coveragerc|codecov|eslint|\.flake8|golangci|clippy|clang-tidy|ruff\.toml|pyproject\.toml|package\.json|makefile|cmakelists\.txt' }

# ------------------------------------------------------------
# 风险行：新增行按类别匹配，删除行查断言；<文件>:<行号>，删除行为旧文件行号
# ------------------------------------------------------------
"--- risky lines ---"
$risky = [ordered]@{
  'skip'          = 'skip|xfail|\.only\(|xit\(|xdescribe|@ignore|@disabled|#\[ignore\]'
  'mock'          = 'mock|stub|fake|monkeypatch|spyon|sinon'
  'disable-check' = 'eslint-disable|noqa|type: *ignore|ts-ignore|ts-nocheck|ts-expect-error|nolint|nosec|pylint: *disable|pragma warning|-wno-|suppresswarnings|#\[allow\('
  'tolerance'     = 'toleran|atol|rtol|epsilon|approx|closeto|almostequal'
}
$h = $false
$hits = foreach ($l in git -c core.quotePath=false diff -U0 --no-color $r) {
  if ($l -match '^diff --git ') { $h = $true }
  elseif ($l -match '^@@ -(\d+)(?:,\d+)? \+(\d+)') { $ol = [int]$Matches[1]; $nl = [int]$Matches[2]; $h = $false }
  elseif ($h) { if ($l -match '^--- (?:a/)?(.*)') { $o = $Matches[1] } elseif ($l -match '^\+\+\+ (?:b/)?(.*)') { $n = $Matches[1] } }
  elseif ($l -match '^\+') {
    $c = foreach ($k in $risky.Keys) { if ($l -match $risky[$k]) { $k } }
    if ($c) { "${n}:${nl}: $($c -join ','): $($l.Substring(1, [Math]::Min(200, $l.Length - 1)))" }
    $nl++
  }
  elseif ($l -match '^-') {
    if ($l -match 'assert|expect|should') { "${o}:${ol} (old): removed-assert: $($l.Substring(1, [Math]::Min(200, $l.Length - 1)))" }
    $ol++
  }
}
$hits | Select-Object -First 200
if ($hits.Count -gt 200) { "... $($hits.Count - 200) more" }
