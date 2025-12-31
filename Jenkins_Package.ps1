param(
    [string]$VersionTag
)

# 設定輸出為 UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not $VersionTag) {
    throw "必須指定 VersionTag，例如 V5.26_Feature3"
}

. "$PSScriptRoot\Load-Env.ps1"

$releaseRoot = $env:Release_Link   # D:\POSAP_Release
$buildRoot   = $env:Build_Link     # C:\Users\...\POSAP_2.0 copy 2

if (-not (Test-Path $releaseRoot)) {
    New-Item -ItemType Directory -Path $releaseRoot | Out-Null
}

$versionDir = Join-Path $releaseRoot $VersionTag

if (-not (Test-Path $versionDir)) {
    New-Item -ItemType Directory -Path $versionDir | Out-Null
    Write-Host "已建立版本資料夾: $versionDir"
} else {
    Write-Host "版本資料夾已存在: $versionDir"
}

# 產生 POSAP_UpdateYYMMDD / POSAP_UpdateYYMMDD_1 / POSAP_UpdateYYMMDD_2 ...
$today          = Get-Date
$folderBaseName = "POSAP_Update" + $today.ToString("yyMMdd")
$targetDir      = Join-Path $versionDir $folderBaseName

$index = 0
while (Test-Path $targetDir) {
    $index++    
    $targetDir = Join-Path $versionDir ("{0}_{1}" -f $folderBaseName, $index)
}

New-Item -ItemType Directory -Path $targetDir | Out-Null
Write-Host "本次建置目標資料夾: $targetDir"

# 複製建置好的檔案
$buildOutput = Join-Path $buildRoot "POSAP\bin\Release"
if (-not (Test-Path $buildOutput)) {
    throw "建置輸出資料夾不存在: $buildOutput"
}

Write-Host "=== 複製建置輸出 ==="
Write-Host "來源: $buildOutput"
Write-Host "目的: $targetDir"

Copy-Item -Path (Join-Path $buildOutput "*") -Destination $targetDir -Recurse -Force

# 新增步驟：移除目標資料夾內的 Xml 資料夾（客戶不需要）
$xmlDir = Join-Path $targetDir "Xml"

if (Test-Path -LiteralPath $xmlDir) {
    Write-Host "偵測到不需要的資料夾，準備刪除: $xmlDir"
    Remove-Item -LiteralPath $xmlDir -Recurse -Force
    Write-Host "已刪除 Xml 資料夾"
}
else {
    Write-Host "未找到 Xml 資料夾，略過刪除"
}
# 壓縮成 POSAP.zip
Write-Host "=== 建立壓縮檔 POSAP.zip ==="

Add-Type -AssemblyName "System.IO.Compression.FileSystem"

$zipTemp  = Join-Path $versionDir "POSAP_temp.zip"
$zipFinal = Join-Path $targetDir "POSAP.zip"

if (Test-Path $zipTemp)  { Remove-Item $zipTemp  -Force }
if (Test-Path $zipFinal) { Remove-Item $zipFinal -Force }

[System.IO.Compression.ZipFile]::CreateFromDirectory($targetDir, $zipTemp)

Move-Item $zipTemp $zipFinal

Write-Host "已建立壓縮檔: $zipFinal"

# -------------------------------
# 新增步驟：刪除 targetDir 內所有內容，只保留 POSAP.zip
# -------------------------------

Get-ChildItem -Path $targetDir -Force | Where-Object {
    $_.Name -ne "POSAP.zip"
} | Remove-Item -Recurse -Force

Write-Host "已刪除資料夾內所有建置檔，只保留 POSAP.zip"

Write-Host "Package 完成。"
exit 0
