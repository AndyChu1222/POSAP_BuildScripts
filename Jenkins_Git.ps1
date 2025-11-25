param(
    [string]$BranchName
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

. "$PSScriptRoot\Load-Env.ps1"

$repoPath = $env:Build_Link

if (-not (Test-Path $repoPath)) {
    throw "找不到專案資料夾：$repoPath"
}

Write-Host "=== Git 操作目錄 ==="
Write-Host $repoPath

Push-Location $repoPath

# 確保是 git repository
if (-not (Test-Path "$repoPath\.git")) {
    throw "$repoPath 不是 Git 專案資料夾!"
}

Write-Host "=== Git Safe Directory 調整 ==="
git config --global --add safe.directory "$repoPath"
Write-Host "=== Fetch 最新內容 ==="
git fetch --all

# 組合遠端分支名稱
$remoteBranch = "origin/Develop/$BranchName"
$localBranch  = "Develop/$BranchName"

Write-Host "=== 準備切換到分支 ==="
Write-Host "本地:  $localBranch"
Write-Host "遠端:  $remoteBranch"

# 判斷本地分支是否存在
$branchExists = git branch --list $localBranch

if ($branchExists) {
    Write-Host "=== 本地分支已存在，直接 checkout ==="
    git checkout $localBranch
} else {
    Write-Host "=== 本地分支不存在，從遠端建立新分支 ==="
    git checkout -b $localBranch $remoteBranch
}

if ($LASTEXITCODE -ne 0) {
    throw "Checkout 失敗：$localBranch"
}

Write-Host "=== Pull 最新版本 ==="
git pull origin $localBranch

if ($LASTEXITCODE -ne 0) {
    throw "Pull 失敗：$localBranch"
}

Pop-Location

Write-Host "=== Git 更新完成 ==="
exit 0
