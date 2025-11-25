param(
    [string]$VersionTag  # 目前沒用到，但保留參數讓呼叫方式一致
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

Write-Host "=== 開始 NuGet Restore ==="
Push-Location $solutionDir
try {
    & "$msbuildPath" $solutionPath `
        /t:Restore `
        /p:Configuration=Release `
        "/p:Platform=Any CPU" `
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
Push-Location $solutionDir
try {
    & "$msbuildPath" $solutionPath `
        /t:Build `
        /p:Configuration=Release `
        "/p:Platform=Any CPU" `
        /m `
        /v:m

    $buildExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($buildExitCode -ne 0) {
    throw "MSBuild 建置失敗 (ExitCode: $buildExitCode)"
}

Write-Host "=== 建置完成 ==="
exit 0
