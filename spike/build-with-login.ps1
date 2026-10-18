# One-off device build with your Komoot login built in, for sideloaded tests (sideloaded apps get no settings from Garmin Connect Mobile).
# The login only lives in the output .PRG: the temporary source file is deleted after the build.

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sdk = Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg" -Raw
$secretDir = Join-Path $root 'source-local'
$outDir = Join-Path $env:USERPROFILE 'Desktop\edge-sync'

function ConvertTo-MonkeyString([string]$value) {
    '"' + $value.Replace('\', '\\').Replace('"', '\"') + '"'
}

$email = Read-Host 'Komoot email'
$secure = Read-Host 'Komoot password' -AsSecureString
$password = [Net.NetworkCredential]::new('', $secure).Password

# The compiler writes intermediate files (mir/, gen/) next to the output, including the login; build in a temp folder and keep only the PRG.
$buildDir = Join-Path $env:TEMP 'komoot-edge-sync-login-build'
New-Item -ItemType Directory -Force $secretDir, $outDir, $buildDir | Out-Null
try {
    @"
(:local_login)
function localCredentials() {
    return [$(ConvertTo-MonkeyString $email), $(ConvertTo-MonkeyString $password)];
}
"@ | Set-Content (Join-Path $secretDir 'LocalCredentials.mc')

    $built = Join-Path $buildDir 'KOMOOT-EDGE-SYNC.PRG'
    java -jar (Join-Path $sdk.Trim() 'bin\monkeybrains.jar') `
        -f "$root\monkey.jungle;$root\local-login.jungle" -d edge830 -o $built -y "$root\developer_key" -r
    if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }
    $prg = Join-Path $outDir 'KOMOOT-EDGE-SYNC.PRG'
    Copy-Item $built $prg -Force
    Write-Host "Built $prg - copy it to Garmin\Apps on the Edge."
}
finally {
    Remove-Item $secretDir, $buildDir, "$root\bin\mir\source-local" -Recurse -Force -ErrorAction SilentlyContinue
}
