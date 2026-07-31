# 세션 시작 시 환경을 점검해 Claude 에게 알려준다.
# SessionStart 훅에서 자동 실행. 출력은 Claude 의 컨텍스트로 들어간다.
$ErrorActionPreference = "SilentlyContinue"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$root = git rev-parse --show-toplevel 2>$null
if (-not $root) { exit 0 }
Set-Location $root

$missing = @()

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    $missing += "Node.js (개발실이 안 켜짐)"
} else {
    $major = [int](((node -v) -replace "^v","") -split "\.")[0]
    if ($major -lt 22) { $missing += "Node.js 22+ (지금 v$major)" }
}

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    $missing += "Claude Code CLI (개발실 지시 실행 불가)"
}

$godot = $false
foreach ($p in @("tools\Godot\Godot.exe",
                 "$env:USERPROFILE\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe")) {
    if (Test-Path $p) { $godot = $true; break }
}
if (-not $godot -and (Get-Command godot -ErrorAction SilentlyContinue)) { $godot = $true }
if (-not $godot) { $missing += "Godot 4 (게임을 못 열고 못 돌림)" }

if (-not (Test-Path "game\.godot")) { $missing += "Godot 프로젝트 임포트 (game/.godot 없음)" }

if ($missing.Count -eq 0) {
    Write-Output "[환경점검] 이상 없음 - Node / Claude Code / Godot / 임포트 모두 준비됨."
} else {
    Write-Output "[환경점검] ⚠ 이 환경은 아직 셋업이 안 끝났다. 없는 것:"
    foreach ($m in $missing) { Write-Output "  - $m" }
    Write-Output ""
    Write-Output "지시: 사용자에게 다른 작업을 하기 전에, 먼저 아래를 실행해 환경을 갖출지 물어봐라."
    Write-Output "  powershell -ExecutionPolicy Bypass -File setup.ps1"
    Write-Output "(Godot 80MB 다운로드가 포함돼 몇 분 걸린다. 자세한 건 README.md 참고)"
}
exit 0
