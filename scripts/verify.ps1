# ============================================================
# 用法: pwsh -NoProfile -File .git/goal-driven/<task>/verify.ps1 <round> <label> '<command>' [tail-lines=40]
# INPUT : 验证命令字符串（交给 pwsh 执行）；须在仓库根目录运行
# OUTPUT: logs/round-<round>-verify-<label>.log（完整输出）；stdout 为 EXIT/LINES/LOG 一行加日志末尾若干行
# POS   : Goal-Driven Master 的 Criterion 验证执行器（Windows, PowerShell 7）
# ============================================================
param([string]$N, [string]$Label, [string]$Cmd, [int]$Tail = 40)
$f = "$PSScriptRoot\logs\round-$N-verify-$Label.log"
# 原样传出最后一条原生命令的退出码；cmdlet 失败时为 1
$w = "$Cmd`nif (-not `$?) { exit `$(if (`$LASTEXITCODE) { `$LASTEXITCODE } else { 1 }) }"
pwsh -NoProfile -NonInteractive -EncodedCommand $([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($w))) *> $f
"EXIT=$LASTEXITCODE LINES=$((Get-Content $f).Count) LOG=$f"
Get-Content $f -Tail $Tail
