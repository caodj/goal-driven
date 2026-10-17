# ============================================================
# 用法: pwsh -NoProfile -File .git/goal-driven/<task>/launch.ps1 <round> <worker args...>
# INPUT : logs/round-<round>-prompt.md；<worker args> 为所选 Worker 命令（不含 -p 及提示词）
# OUTPUT: logs/round-<round>-worker.{pid,log,exit}；立即返回
# POS   : Goal-Driven Master 的 Worker 后台启动器（Windows, PowerShell 7）
# ============================================================
$N, $cmd = $args
$f = "$PSScriptRoot\logs\round-$N-worker"; $p = "$PSScriptRoot\logs\round-$N-prompt.md"
$q = ($cmd | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ' '
$w = "& $q -p (Get-Content -Raw '$p') *> '$f.log'; `$LASTEXITCODE > '$f.exit.tmp'; Move-Item '$f.exit.tmp' '$f.exit'"
$proc = Start-Process pwsh -WindowStyle Hidden -PassThru -ArgumentList "-NoProfile -NonInteractive -EncodedCommand $([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($w)))"
$proc.Id > "$f.pid"
