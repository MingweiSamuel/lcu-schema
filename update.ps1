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

$OUT_DIR = 'out'

# Stop any existing processes.
Stop-Process -Name "LeagueClient" -ErrorAction Ignore
# Create out folder
New-Item -ItemType Directory -Force -Path $OUT_DIR | Out-Null


# LCU SCRIPT
$LEAGUE_DIR = 'C:\Riot Games\League of Legends'
$LOCK_FILE = "$LEAGUE_DIR\lockfile"
$YAML_FILE = "$LEAGUE_DIR\Config\lcu-schema\system.yaml"
$RIOT_USERNAME = 'riot'

# RIOT GAMES USER ACCOUNT
$LOLLOGIN_FILE = 'lollogin.json'

Write-Host 'Creating alternate system.yaml.'
New-Item -Path "$LEAGUE_DIR\Config\lcu-schema\system.yaml" -Force | Out-Null
$systemYaml  = Get-Content "$LEAGUE_DIR\system.yaml"
$systemYaml  = $systemYaml[0..($systemYaml.count - 4)]
$systemYaml += ('enable_swagger: true')
$systemYaml | Out-File $YAML_FILE -Encoding ascii

Write-Host 'Starting LeagueClient.exe.'
& "$LEAGUE_DIR\LeagueClient.exe" "--system-yaml-override=$LEAGUE_DIR\Config\lcu-schema\system.yaml"


function Invoke-LcuRequest {
    Param (
        [Parameter(Mandatory=$true)]  [String]$path,
        [Parameter(Mandatory=$false)] [String]$method = 'GET',
        [Parameter(Mandatory=$false)] $body = $null
    )

    Start-Sleep 1
    $attempt = 100
    While ($true) {
        Try {
            $lockContent = Get-Content $LOCK_FILE -Raw
            $lockContent = $lockContent.Split(':')
            $port = $lockContent[2];
            $pass = $lockContent[3];

            $userpass = "${RIOT_USERNAME}:$pass"
            $userpass = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userpass))
            Write-Host "Lockfile parsed, target ':$port$path', auth basic: '$userpass', left: $attempt."

            $result = Invoke-RestMethod `
                -Uri "https://127.0.0.1:$port$path" `
                -Headers @{ 'Authorization' = "Basic $userpass" } `
                -ContentType 'application/json' `
                -Body $($body | ConvertTo-Json) `
                -Method $method `
                -UseBasicParsing
            Return $result
        } Catch {
            $attempt--
            If ($attempt -le 0) {
                Write-Host 'Failed to get data from the LCU'
                Throw $_
            }
            Write-Host "Failed to get data, retrying: $_"
            Start-Sleep 5
        }
    }
}

Try {
    # Help behaves weird if you call it after logging in: returns a JSON-serialized string with duplicate keys.
    Write-Host 'Getting help.'
    Invoke-LcuRequest '/help' | ConvertTo-Json -Depth 100 | Format-Json | Out-File -Encoding UTF8 "$OUT_DIR\help.json"

    # If login info available, log-in first to ensure LCU is updated.
    If (Test-Path $LOLLOGIN_FILE) {
        Write-Host "$LOLLOGIN_FILE found, attempting to log-in."
        $login = Get-Content $LOLLOGIN_FILE | ConvertFrom-Json
        Invoke-LcuRequest '/lol-login/v1/session' 'POST' $login
        Write-Host 'Logged in.'

        Write-Host 'Getting queues.'
        Invoke-LcuRequest '/lol-game-queues/v1/queues' |
            ConvertTo-Json -Depth 100 | Format-Json | Out-File -Encoding UTF8 "$OUT_DIR\queues.json"

        Write-Host 'Getting maps.'
        Invoke-LcuRequest '/lol-maps/v1/maps' |
            ConvertTo-Json -Depth 100 | Format-Json | Out-File -Encoding UTF8 "$OUT_DIR\maps.json"

        Write-Host 'Getting store-catalog.'
        Invoke-LcuRequest '/lol-store/v1/catalog' |
            ConvertTo-Json -Depth 100 | Format-Json | Out-File -Encoding UTF8 "$OUT_DIR\store-catalog.json"
    }
    Else {
        Write-Host "$LOLLOGIN_FILE not found, not getting data requiring log-in."
    }

    Write-Host 'Getting spec.'
    $specResponse = Invoke-LcuRequest '/swagger/v3/openapi.json'
    $specResponse | ConvertTo-Json -Depth 100 | Format-Json | Out-File -Encoding UTF8 "$OUT_DIR\openapi.json"
    $specResponse | ConvertTo-Json -Depth 100 | Format-Json | Out-File -Encoding UTF8 "$OUT_DIR\spec.json"
    $specResponse | ConvertTo-Json -Depth 100 -Compress | Out-File -Encoding UTF8 "$OUT_DIR\spec.min.json"

    Invoke-LcuRequest '/swagger/v2/swagger.json' | ConvertTo-Json -Depth 100 | Format-Json |
        Out-File -Encoding UTF8 "$OUT_DIR\swagger.json"
} Finally {
    Stop-Process -Name 'LeagueClient'
    Remove-Item $LOCK_FILE
}

Write-Host 'Success.'
