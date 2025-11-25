
param(
    [string]$VersionTag,
    [string]$FtpUser
)
$FtpPassword = $env:FTP_PASS
$env:FTP_PASS = $null   # 防止後續誤印

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8



if (-not $VersionTag)  {throw "必須指定 VersionTag" }
if (-not $FtpUser)     {  throw "必須指定 FTP 帳號"  }

. "$PSScriptRoot\Load-Env.ps1"

$releaseRoot = $env:Release_Link        # D:\POSAP_Release
$ftpBasePath = $env:ftp_Link            # /Test/02. 點餐通_併版2.0
$ftpHost     = "192.168.2.21"

$localVersionDir = Join-Path $releaseRoot $VersionTag
if (-not (Test-Path $localVersionDir)) {
    throw "找不到版本資料夾: $localVersionDir"
}

$updateFolder = Get-ChildItem -Path $localVersionDir -Directory -Filter "POSAP_Update*" |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

if (-not $updateFolder) {
    throw "在 $localVersionDir 找不到 POSAP_Update* 資料夾"
}

$localUpdatePath  = $updateFolder.FullName
$updateFolderName = $updateFolder.Name

Write-Host "預計上傳資料夾: $localUpdatePath"

$cred = New-Object System.Net.NetworkCredential($FtpUser, $FtpPassword)

function New-FtpRequest([string]$uri, [string]$method) {
    $req = [System.Net.FtpWebRequest]::Create($uri)
    $req.Credentials = $cred
    $req.Method      = $method
    $req.UseBinary   = $true
    $req.UsePassive  = $false   # 主動模式
    $req.KeepAlive   = $false
    return $req
}

function Ensure-FtpPath([string]$host1, [string]$path) {
    $trim = $path.Trim("/")
    if ([string]::IsNullOrEmpty($trim)) { return }

    $parts   = $trim.Split("/")
    $current = ""

    foreach ($p in $parts) {
        if (-not $p) { continue }
        $current = $current + "/" + $p
        $uri = "ftp://$host1$current"

        $req = New-FtpRequest -uri $uri -method ([System.Net.WebRequestMethods+Ftp]::MakeDirectory)
        try {
            $resp = $req.GetResponse()
            $resp.Close()
            Write-Host "建立 FTP 資料夾: $current"
        }
        catch [System.Net.WebException] {
            $resp   = $_.Exception.Response
            $status = $resp.StatusDescription
            $resp.Close()
            if ($status -notlike "*File exists*") {
                Write-Host "無法建立 FTP 資料夾 ($current): $status"
            } else {
                Write-Host "FTP 資料夾已存在: $current"
            }
        }
    }
}

function Upload-File([string]$localPath, [string]$ftpUri) {
    $bytes = [System.IO.File]::ReadAllBytes($localPath)
    $req = New-FtpRequest -uri $ftpUri -method ([System.Net.WebRequestMethods+Ftp]::UploadFile)
    $req.ContentLength = $bytes.Length

    $stream = $req.GetRequestStream()
    $stream.Write($bytes, 0, $bytes.Length)
    # 安全關閉資料流
        try { $stream.Close() } catch {}

        # 這段最容易出 425，靜默忽略
        try {
            $resp = $req.GetResponse()
            $resp.Close()
        }
        catch {
            # 不顯示，不拋出，不影響上傳
        }

    Write-Host "上傳檔案: $localPath -> $ftpUri"
}

function Upload-Directory([string]$localDir, [string]$host1, [string]$remoteBasePath) {
    $items = Get-ChildItem -Path $localDir -Recurse

    foreach ($item in $items) {
        $relativePath = $item.FullName.Substring($localDir.Length).TrimStart('\')
        $relativePathUnix = $relativePath -replace '\\', '/'
        $remotePath = "$remoteBasePath/$relativePathUnix"

        $remoteDirPath = Split-Path $remotePath -Parent
        $remoteDirPath = $remoteDirPath -replace '\\', '/'

        Ensure-FtpPath -host $host1 -path $remoteDirPath

        if (-not $item.PSIsContainer) {
            $uri = "ftp://$host1$remotePath"
            Upload-File -localPath $item.FullName -ftpUri $uri
        }
    }
}

$remoteVersionPath = "$ftpBasePath/$VersionTag"
$remoteUpdatePath  = "$remoteVersionPath/$updateFolderName"

Ensure-FtpPath -host $ftpHost -path $remoteUpdatePath

Write-Host "=== 開始上傳到 FTP: ftp://$ftpHost$remoteUpdatePath ==="
Upload-Directory -localDir $localUpdatePath -host $ftpHost -remoteBasePath $remoteUpdatePath

Write-Host "FTP 上傳完成。"
exit 0
