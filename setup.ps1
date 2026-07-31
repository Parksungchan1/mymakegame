# ============================================================
#  스킬 크래프트 배틀 — 새 환경 셋업
#  실행: powershell -ExecutionPolicy Bypass -File setup.ps1
# ============================================================
$ErrorActionPreference = "Continue"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$GODOT_VERSION = "4.7.1-stable"
$GODOT_DIR     = Join-Path $root "tools\Godot"
$GODOT_EXE     = Join-Path $GODOT_DIR "Godot.exe"

$problems = @()

function Say([string]$msg, [string]$color = "White") { Write-Host $msg -ForegroundColor $color }
function OK([string]$msg)   { Say "  [OK]   $msg" "Green" }
function WARN([string]$msg) { Say "  [!]    $msg" "Yellow" }
function FAIL([string]$msg) { Say "  [X]    $msg" "Red" }
function Has([string]$cmd)  { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

Say ""
Say "============================================" "Cyan"
Say "  스킬 크래프트 배틀 - 환경 셋업" "Cyan"
Say "============================================" "Cyan"
Say ""

# ------------------------------------------------------------
# 1. Git
# ------------------------------------------------------------
Say "[1/6] Git 확인" "Cyan"
if (Has "git") {
    OK ((git --version) -join "")
} else {
    FAIL "Git 이 없습니다."
    Say "         설치: winget install Git.Git"
    Say "         설치 후 PowerShell 을 새로 열고 이 스크립트를 다시 실행하세요."
    $problems += "Git 미설치"
}

# ------------------------------------------------------------
# 2. Node.js 22+
# ------------------------------------------------------------
Say ""
Say "[2/6] Node.js 확인 (22 이상 필요)" "Cyan"
$nodeOk = $false
if (Has "node") {
    $nodeVer = (node -v) -replace "^v", ""
    $major = [int]($nodeVer -split "\.")[0]
    if ($major -ge 22) { OK "Node.js v$nodeVer"; $nodeOk = $true }
    else { WARN "Node.js v$nodeVer - 22 미만입니다. 개발실이 안 돌 수 있습니다." }
} else {
    WARN "Node.js 가 없습니다. 설치를 시도합니다..."
}

if (-not $nodeOk) {
    if (Has "winget") {
        Say "         winget 으로 Node.js LTS 설치 중... (몇 분 걸립니다)"
        winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements | Out-Null
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path", "User")
        if (Has "node") { OK "Node.js $(node -v) 설치 완료"; $nodeOk = $true }
    }
    if (-not $nodeOk) {
        FAIL "Node.js 를 직접 설치해주세요: https://nodejs.org (LTS)"
        $problems += "Node.js 미설치 - 개발실이 안 켜집니다"
    }
}

# ------------------------------------------------------------
# 3. Claude Code CLI
# ------------------------------------------------------------
Say ""
Say "[3/6] Claude Code CLI 확인" "Cyan"
if (Has "claude") {
    OK "Claude Code $((claude --version) -join '')"
} elseif ($nodeOk) {
    Say "         npm 으로 설치 중..."
    npm install -g "@anthropic-ai/claude-code" 2>&1 | Out-Null
    if (Has "claude") {
        OK "Claude Code 설치 완료"
    } else {
        FAIL "설치 실패. 직접: npm install -g @anthropic-ai/claude-code"
        $problems += "Claude Code CLI 미설치 - AI 에이전트를 못 씁니다"
    }
} else {
    FAIL "Node.js 가 없어 설치할 수 없습니다."
    $problems += "Claude Code CLI 미설치"
}

# ------------------------------------------------------------
# 4. Godot 4 (무설치)
# ------------------------------------------------------------
Say ""
Say "[4/6] Godot $GODOT_VERSION 확인" "Cyan"
if (Test-Path $GODOT_EXE) {
    OK "이미 있음: tools\Godot\Godot.exe"
} else {
    $zipUrl = "https://github.com/godotengine/godot/releases/download/$GODOT_VERSION/Godot_v${GODOT_VERSION}_win64.exe.zip"
    $zipPath = Join-Path $env:TEMP "godot_$GODOT_VERSION.zip"
    Say "         다운로드 중... (약 100MB, 시간이 좀 걸립니다)"
    Say "         $zipUrl"
    try {
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        if (-not (Test-Path $GODOT_DIR)) { New-Item -ItemType Directory -Force -Path $GODOT_DIR | Out-Null }
        Expand-Archive -Path $zipPath -DestinationPath $GODOT_DIR -Force
        $found = Get-ChildItem -Path $GODOT_DIR -Recurse -Filter "Godot_v*_win64.exe" |
                 Where-Object { $_.Name -notmatch "console" } | Select-Object -First 1
        if ($found) {
            Move-Item -Path $found.FullName -Destination $GODOT_EXE -Force
            OK "Godot 준비 완료: tools\Godot\Godot.exe"
        } else {
            FAIL "압축 안에서 Godot 실행 파일을 못 찾았습니다."
            $problems += "Godot 수동 설치 필요"
        }
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    } catch {
        FAIL "다운로드 실패: $($_.Exception.Message)"
        Say "         직접 받으세요: https://godotengine.org/download/windows/"
        Say "         받은 exe 를 이 경로에 두면 됩니다: tools\Godot\Godot.exe"
        $problems += "Godot 수동 설치 필요"
    }
}

# ------------------------------------------------------------
# 5. Git 사용자 정보 (이 저장소에만)
# ------------------------------------------------------------
Say ""
Say "[5/6] Git 사용자 정보 확인" "Cyan"
if (Has "git") {
    $uname = (git config user.name)  2>$null
    $umail = (git config user.email) 2>$null
    if ([string]::IsNullOrWhiteSpace($uname)) {
        git config user.name "wfs070809"
        Say "         user.name 을 wfs070809 로 설정 (이 저장소에만)"
    }
    if ([string]::IsNullOrWhiteSpace($umail)) {
        git config user.email "wfs070809@gmail.com"
        Say "         user.email 을 wfs070809@gmail.com 로 설정 (이 저장소에만)"
    }
    OK "$(git config user.name) <$(git config user.email)>"
    Say "         바꾸려면: git config user.name `"새이름`""
}

# ------------------------------------------------------------
# 6. 게임 프로젝트 임포트 검증
# ------------------------------------------------------------
Say ""
Say "[6/6] Godot 프로젝트 임포트 검증" "Cyan"
if (Test-Path $GODOT_EXE) {
    Say "         --headless --import 실행 중..."
    & $GODOT_EXE --headless --path (Join-Path $root "game") --import --quit 2>&1 | Out-Null
    OK "임포트 완료 (game/.godot 생성됨)"
} else {
    WARN "Godot 이 없어 건너뜁니다."
}

# ------------------------------------------------------------
# 결과
# ------------------------------------------------------------
Say ""
Say "============================================" "Cyan"
if ($problems.Count -eq 0) {
    Say "  셋업 완료! 준비 끝났습니다." "Green"
} else {
    Say "  셋업 끝났지만 남은 게 있습니다:" "Yellow"
    foreach ($p in $problems) { Say "   - $p" "Yellow" }
}
Say "============================================" "Cyan"
Say ""
Say "다음 순서:" "Cyan"
Say ""
Say "  1) 로그인 (한 번만)      →  claude    ...브라우저 로그인 후 /exit"
Say "  2) 진행 상황 확인        →  STATUS.md 를 연다"
Say "  3) 개발실 켜기           →  '개발실 열기.cmd' 더블클릭  (http://localhost:3100)"
Say "  4) 게임 해보기           →  '게임 열기.cmd' 더블클릭 후 F5"
Say "  5) AI 와 작업            →  이 폴더에서  claude"
Say ""
