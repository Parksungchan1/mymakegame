# 자동 체크포인트: 변경사항 전부 커밋 후 GitHub 푸시.
# 훅에서 자동 실행: SubagentStop / PreCompact / SessionEnd
$ErrorActionPreference = "SilentlyContinue"

# 개발실(office)에서 띄운 지시 작업은 여기서 커밋하지 않는다.
# 개발실 서버가 [역할] 태그를 붙여 직접 커밋하기 때문에, 여기서도 커밋하면
# 태그 없는 "checkpoint: auto-save" 커밋이 중복으로 쌓이고 담당자 판정이 깨진다.
if ($env:SKILLCRAFT_OFFICE_JOB -eq "1") { exit 0 }

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
