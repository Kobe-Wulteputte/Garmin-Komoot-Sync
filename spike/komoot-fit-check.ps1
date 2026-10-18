# Step 1a: does Komoot's FIT download work with the unofficial login?
# Prompts for your Komoot login, lists your latest planned tours and downloads the newest as .fit and .gpx.
# Prints no password or token.

$ErrorActionPreference = 'Stop'
$api = 'https://api.komoot.de'

function Get-Basic([string]$user, [string]$pass) {
    'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${user}:${pass}"))
}

$email = Read-Host 'Komoot email'
$secure = Read-Host 'Komoot password' -AsSecureString
$password = [Net.NetworkCredential]::new('', $secure).Password

$account = Invoke-RestMethod "$api/v006/account/email/$email/" -Headers @{ Authorization = Get-Basic $email $password }
$username = $account.username
$auth = @{ Authorization = Get-Basic $username $account.password }
Write-Host "Login OK, username $username"

$toursUrl = "$api/v007/users/$username/tours/?type=tour_planned&sort_field=date&sort_direction=desc&limit=5&page=0"
$raw = Invoke-WebRequest $toursUrl -Headers $auth
$out = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force $out | Out-Null
# Komoot answers application/hal+json, which PowerShell hands back as bytes.
$json = [Text.Encoding]::UTF8.GetString($raw.RawContentStream.ToArray())
$json | Set-Content (Join-Path $out 'tours.json')
$tours = $json | ConvertFrom-Json
Write-Host "Tour list: $($raw.RawContentLength) bytes for $($tours._embedded.tours.Count) tours, $($tours.page.totalElements) planned in total"
$tours._embedded.tours | ForEach-Object { Write-Host "  $($_.id)  $($_.date)  $($_.name)" }

$first = $tours._embedded.tours | Select-Object -First 1
if (-not $first) {
    Write-Host "No tours found in the response. Raw JSON saved to $out\tours.json"
    return
}

foreach ($ext in 'fit', 'gpx') {
    $file = Join-Path $out "$($first.id).$ext"
    try {
        Invoke-WebRequest "$api/v007/tours/$($first.id).$ext" -Headers $auth -OutFile $file
        $bytes = [IO.File]::ReadAllBytes($file)
        $isFit = $bytes.Length -ge 12 -and [Text.Encoding]::ASCII.GetString($bytes, 8, 4) -eq '.FIT'
        Write-Host "$ext OK: $($bytes.Length) bytes, FIT header: $isFit -> $file"
    }
    catch {
        Write-Host "$ext FAILED: $($_.Exception.Message)"
    }
}
