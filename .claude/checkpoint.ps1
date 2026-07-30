# 자동 체크포인트: 변경사항 전부 커밋 후 GitHub 푸시.
# 훅에서 자동 실행: SubagentStop / PreCompact / SessionEnd
$ErrorActionPreference = "SilentlyContinue"
$root = git rev-parse --show-toplevel 2>$null
if ($root) { Set-Location $root }
git add -A
$changes = git status --porcelain
if (-not $changes) { exit 0 }
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
git commit -m "checkpoint: auto-save $stamp" | Out-Null
git push 2>$null
if ($LASTEXITCODE -ne 0) { git push -u origin HEAD 2>$null }
exit 0
