# ============================================================
# 用法: pwsh -NoProfile -File .git/goal-driven/<task>/poll.ps1 <round> <max-wait-seconds> [stall-seconds=1200] [progress-seconds=3600]
# INPUT : logs/round-<round>-worker.{pid,log,exit}；须在仓库根目录运行
# OUTPUT: 一行状态 DONE | DEAD | STALLED | NO_PROGRESS | RUNNING；维护 round-<round>-worker.progress
# POS   : Goal-Driven Master 的 Worker 轮询器（Windows, PowerShell 7）
# ============================================================
param([int]$N, [int]$Wait, [int]$Stall = 1200, [int]$Progress = 3600)
$f = "$PSScriptRoot\logs\round-$N-worker"; $end = (Get-Date).AddSeconds($Wait)
while ($true) {
  $h = & { git diff HEAD; git ls-files -o --exclude-standard | git hash-object --stdin-paths } | git hash-object --stdin
  if ($h -ne (Get-Content "$f.progress" -ErrorAction SilentlyContinue)) { $h > "$f.progress" }
  $alive = [bool](Get-Process -Id (Get-Content "$f.pid") -ErrorAction SilentlyContinue)
  if (Test-Path "$f.exit") { "DONE exit=$(Get-Content "$f.exit")"; exit }
  if (-not $alive) { "DEAD"; exit }
  $t = Get-Date
  $e, $i, $s = "$f.pid", "$f.log", "$f.progress" | ForEach-Object { [int]($t - (Get-Item $_).LastWriteTime).TotalSeconds }
  $m = "elapsed=${e}s idle=${i}s stale=${s}s"
  if ($i -gt $Stall -and $s -gt $Stall) { "STALLED $m"; exit }
  if ($s -gt $Progress) { "NO_PROGRESS $m"; exit }
  if ($t -ge $end) { "RUNNING $m"; exit }
  Start-Sleep ([Math]::Max(1, [Math]::Min(60, ($end - $t).TotalSeconds)))
}
