param(
    [string]$VersionTag,

    [switch]$CleanBinRelease = $true
)

# 設定輸出為 UTF-8，讓中文訊息在 Jenkins / CMD 正常顯示
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

. "$PSScriptRoot\Load-Env.ps1"

$solutionDir  = $env:Build_Link

git -C $solutionDir status

# 不再手動寫 "點餐通_併版.sln"，改用檔案系統抓真正檔名
# 如果你希望更精準，可以把 *改成 *併版*.sln
$solutionItem = Get-ChildItem -LiteralPath $solutionDir -Filter '*.sln' | Select-Object -First 1

if (-not $solutionItem) {
    throw "找不到方案檔: 在 $solutionDir 找不到任何 .sln 檔案"
}

$solutionPath = $solutionItem.FullName

Write-Host "=== 建置資訊 ==="
Write-Host "Solution: $solutionPath"

$msbuildPath = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
if (-not (Test-Path $msbuildPath)) {
    throw "找不到 MSBuild: $msbuildPath"
}

function Remove-BinReleaseFolders([string]$root) {
    Write-Host "=== 清除所有 bin\\Release ==="

    $targets =
        Get-ChildItem -Path $root -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "\\bin\\Release$" }

    if (-not $targets) {
        Write-Host "未找到任何 bin\\Release（可能尚未建置過）"
        return
    }

    foreach ($dir in $targets) {
        try {
            Write-Host "刪除: $($dir.FullName)"
            Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction Stop
        }
        catch {
            throw "刪除失敗: $($dir.FullName)`n$($_.Exception.Message)"
        }
    }
}

# 先清除 bin\Release
if ($CleanBinRelease) {
    Remove-BinReleaseFolders -root $solutionDir
}


Write-Host "=== 開始 NuGet Restore ==="
Push-Location $solutionDir
try {
    & "$msbuildPath" $solutionPath `
        /t:Restore `
        /m `
        /v:m

    $restoreExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($restoreExitCode -ne 0) {
    throw "MSBuild Restore 失敗 (ExitCode: $restoreExitCode)"
}

Write-Host "=== 開始建置專案 (Release | Any CPU) ==="
Write-Host "=== Phase 1: Clean (Release | Any CPU) ==="
Push-Location $solutionDir
try {
    & "$msbuildPath" $solutionPath `
        "/t:Clean" `
        "/p:Configuration=Release" `
        "/p:Platform=Any CPU" `
        /m `
        /v:m

    $cleanExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($cleanExitCode -ne 0) {
    throw "MSBuild Clean 失敗 (ExitCode: $cleanExitCode)"
}

Write-Host "=== Phase 2: Build (Release | Any CPU) ==="
Push-Location $solutionDir
try {
    & "$msbuildPath" $solutionPath `
        "/t:Build" `
        "/p:Configuration=Release" `
        "/p:Platform=Any CPU" `
        "/p:BuildType=IDE" `
        "/p:DeterministicSourcePaths=false" `
        /m `
        /v:m

    $buildExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($buildExitCode -ne 0) {
    throw "MSBuild Build 失敗 (ExitCode: $buildExitCode)"
}

Write-Host "=== 建置完成 ==="
exit 0
