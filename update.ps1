$LEAGUE_DIR = "C:\Riot Games\League of Legends"
$LOCK_FILE = "$LEAGUE_DIR\lockfile"
$YAML_FILE = "$LEAGUE_DIR\Config\lcu-schema\system.yaml"
$RIOT_USERNAME = "riot"

New-Item -Path "$LEAGUE_DIR\Config\lcu-schema\system.yaml" -Force | Out-Null
$systemYaml  = Get-Content "$LEAGUE_DIR\system.yaml"
$systemYaml  = $systemYaml[0..($systemYaml.count - 4)]
$systemYaml += ("enable_swagger: true")
$systemYaml | Out-File "$YAML_FILE" -Encoding ascii

& "$LEAGUE_DIR\LeagueClient.exe" "--system-yaml-override=$LEAGUE_DIR\Config\lcu-schema\system.yaml"

$attempt = 10
while (!(Test-Path "$LOCK_FILE")) {
    Start-Sleep 1
    $attempt--
    if ($attempt -le 0) {
        Exit
    }
}

$lockContent = Get-Content "$LOCK_FILE" -Raw
$lockContent = $lockContent.Split(':')
$port = $lockContent[2];
$pass = $lockContent[3];

$userpass = "${RIOT_USERNAME}:$pass"
$userpass = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userpass))

Write-Output $userpass


# IGNORE SSL ERRORS.
add-type @"
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


$attempt = 20
$success = $false
while ($attempt -gt 0 -and -not $success) {
  Start-Sleep 1
  try {
    $response = Invoke-WebRequest "https://127.0.0.1:$port/swagger/v3/openapi.json" -Headers @{'Authorization' = "Basic $userpass" }
    $success = $true
  } catch {
    $attempt--
  }
}

Write-Output $response

$response.Content > openapi.json


Stop-Process -Name "LeagueClientUx"
Stop-Process -Name "LeagueClient"

Remove-Item "$LOCK_FILE"
