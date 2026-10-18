# Can the Komoot tour list be made smaller? Tries a few request variants for one page of 5 tours and prints the size
# per tour, and whether the fields the app needs are still there. Prints no password, token or tour data.

$ErrorActionPreference = 'Stop'
$api = 'https://api.komoot.de'
$needed = 'id', 'name', 'changed_at', 'distance', 'date', 'sport'

function Get-Basic([string]$user, [string]$pass) {
    'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${user}:${pass}"))
}

$email = Read-Host 'Komoot email'
$secure = Read-Host 'Komoot password' -AsSecureString
$password = [Net.NetworkCredential]::new('', $secure).Password

$account = Invoke-RestMethod "$api/v006/account/email/$email/" -Headers @{ Authorization = Get-Basic $email $password }
$username = $account.username
$auth = Get-Basic $username $account.password

$base = "$api/v007/users/$username/tours/?type=tour_planned&sort_field=date&sort_direction=desc&limit=5&page=0"
$fields = $needed -join ','
$variants = [ordered]@{
    'baseline'                    = @($base, 'application/hal+json')
    'Accept: application/json'    = @($base, 'application/json')
    "fields=$fields"              = @("$base&fields=$fields", 'application/hal+json')
    "_fields=$fields"             = @("$base&_fields=$fields", 'application/hal+json')
    "only=$fields"                = @("$base&only=$fields", 'application/hal+json')
    '_embedded= (empty)'          = @("$base&_embedded=", 'application/hal+json')
    'compact=true'                = @("$base&compact=true", 'application/hal+json')
    'format=compact'              = @("$base&format=compact", 'application/hal+json')
    'hl=en&status=private'        = @("$base&hl=en&status=private", 'application/hal+json')
}

foreach ($name in $variants.Keys) {
    $url, $accept = $variants[$name]
    try {
        $raw = Invoke-WebRequest $url -Headers @{ Authorization = $auth; Accept = $accept }
        $json = [Text.Encoding]::UTF8.GetString($raw.RawContentStream.ToArray())
        $data = $json | ConvertFrom-Json
        $tours = @($data._embedded.tours)
        if ($tours.Count -eq 0 -and $data -is [array]) { $tours = @($data) }
        $missing = @($needed | Where-Object { $tours.Count -gt 0 -and $null -eq $tours[0].$_ })
        $keys = if ($tours.Count -gt 0) { @($tours[0].PSObject.Properties.Name).Count } else { 0 }
        $perTour = if ($tours.Count -gt 0) { [int]($json.Length / $tours.Count) } else { 0 }
        $note = if ($missing.Count) { "missing: $($missing -join ',')" } else { 'all needed fields' }
        '{0,-45} {1,6} bytes  {2} tours  {3,5} bytes/tour  {4,2} keys/tour  {5}' -f $name, $json.Length, $tours.Count, $perTour, $keys, $note
    }
    catch {
        '{0,-45} FAILED: {1}' -f $name, $_.Exception.Message
    }
}
