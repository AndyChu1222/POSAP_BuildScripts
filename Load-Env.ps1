param(
    [string]$EnvFilePath = (Join-Path $PSScriptRoot ".env")
)

# 讓主控台與輸出使用 UTF-8（Jenkins、CMD 都比較不會亂碼）
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path $EnvFilePath)) {
    throw "找不到 .env 檔案: $EnvFilePath"
}

Get-Content $EnvFilePath -Encoding UTF8 |
    Where-Object { $_ -and -not $_.TrimStart().StartsWith("#") } |
    ForEach-Object {
        $line = $_.Trim()
        if (-not $line) { return }
        $parts = $line -split '=', 2
        if ($parts.Length -eq 2) {
            $name  = $parts[0].Trim()
            $value = $parts[1].Trim()
            Write-Host "$name = $value"

            # 正確寫法
            [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }

Write-Host "已載入 .env：Build_Link=$($env:Build_Link), Release_Link=$($env:Release_Link), ftp_Link=$($env:ftp_Link)"