# FORMAT JSON
# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
# https://github.com/PowerShell/PowerShell/issues/2736
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
    $indent = 0;
    ($json -Split "`n" | ForEach-Object {
        if ($_ -match '[\}\]]\s*,?\s*$') {
            # This line ends with ] or }, decrement the indentation level
            $indent--
        }
        $line = ('  ' * $indent) + $($_.TrimStart() -replace '":  (["{[])', '": $1' -replace ':  ', ': ')
        if ($_ -match '[\{\[]\s*$') {
            # This line ends with [ or {, increment the indentation level
            $indent++
        }
        $line
    }) -Join "`n"
}

# IGNORE SSL ERRORS.
Add-Type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


# LCU SCRIPT
$LEAGUE_DIR = 'C:\Riot Games\League of Legends'
$LOCK_FILE = "$LEAGUE_DIR\lockfile"
$YAML_FILE = "$LEAGUE_DIR\Config\lcu-schema\system.yaml"
$RIOT_USERNAME = 'riot'

# RIOT GAMES USER ACCOUNT
$LOGIN_FILE = 'userpass.json'

Write-Output 'Creating alternate system.yaml.'
New-Item -Path "$LEAGUE_DIR\Config\lcu-schema\system.yaml" -Force | Out-Null
$systemYaml  = Get-Content "$LEAGUE_DIR\system.yaml"
$systemYaml  = $systemYaml[0..($systemYaml.count - 4)]
$systemYaml += ('enable_swagger: true')
$systemYaml | Out-File $YAML_FILE -Encoding ascii

Write-Output 'Starting LeagueClient.exe.'
& "$LEAGUE_DIR\LeagueClient.exe" "--system-yaml-override=$LEAGUE_DIR\Config\lcu-schema\system.yaml"

Write-Output 'Waiting for lockfile.'
$attempt = 10
while (!(Test-Path $LOCK_FILE)) {
    Start-Sleep 1
    $attempt--
    if ($attempt -le 0) {
        Write-Output 'Failed to find lockfile.'
        Stop-Process -Name 'LeagueClient'
        Exit
    }
}

$lockContent = Get-Content $LOCK_FILE -Raw
$lockContent = $lockContent.Split(':')
$port = $lockContent[2];
$pass = $lockContent[3];

$userpass = "${RIOT_USERNAME}:$pass"
$userpass = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userpass))
Write-Output "Lockfile parsed, port: '$port', userpass64: '$userpass'.".

function Invoke-LcuRequest {
    Param (
        [Parameter(Mandatory=$true)]  [String]$path,
        [Parameter(Mandatory=$false)] [String]$method = "GET",
        [Parameter(Mandatory=$false)] $body = $null
    )
    $attempt = 10
    $success = $false
    while (-not $success) {
        Start-Sleep 1
        try {
            $result = Invoke-RestMethod `
                -Uri "https://127.0.0.1:$port$path" `
                -Headers @{ 'Authorization' = "Basic $userpass" } `
                -ContentType 'application/json' `
                -Body $($body | ConvertTo-Json) `
                -Method $method `
                -UseBasicParsing
            $success = $true
            Return $result
        } catch {
            $attempt--
            if ($attempt -le 0) {
                Write-Error "Failed to connect to LCU:"
                Throw $_
            }
        }
    }
}

try {
    Write-Output 'Getting openapi.json.'
    $specResponse = Invoke-LcuRequest '/swagger/v3/openapi.json'
    $specResponse | ConvertTo-Json -Depth 100 | Format-Json | Out-File -Encoding UTF8 'spec.json'
    $specResponse | ConvertTo-Json -Depth 100 -Compress | Out-File -Encoding UTF8 'spec.min.json'

    Write-Output 'Getting help.'
    Invoke-LcuRequest '/help' | ConvertTo-Json -Depth 100 | Format-Json | Out-File -Encoding UTF8 'help.json'

    # Log-in and get queues.
    if (Test-Path $LOGIN_FILE) {
        Write-Output "$LOGIN_FILE found, attempting to log-in."
        $login = Get-Content $LOGIN_FILE | ConvertFrom-Json
        Invoke-LcuRequest '/lol-login/v1/session' 'POST' $login
        Write-Output 'Logged in.'

        Write-Output 'Getting queues.'
        Invoke-LcuRequest '/lol-game-queues/v1/queues' |
            ConvertTo-Json -Depth 100 | Format-Json | Out-File -Encoding UTF8 'queues.json'

        Write-Output 'Getting maps.'
        Invoke-LcuRequest '/lol-maps/v1/maps' |
            ConvertTo-Json -Depth 100 | Format-Json | Out-File -Encoding UTF8 'maps.json'

        Write-Output 'Getting store-catalog.'
        Invoke-LcuRequest '/lol-store/v1/catalog' |
            ConvertTo-Json -Depth 100 | Format-Json | Out-File -Encoding UTF8 'store-catalog.json'
    }
    else {
        Write-Error "$LOGIN_FILE not found, not getting data requiring log-in."
    }
} finally {
    # Stop-Process -Name "LeagueClient"
    Remove-Item "$LOCK_FILE"
}

Write-Output "Success."
