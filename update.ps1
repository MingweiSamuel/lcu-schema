. .\format-json.ps1
. .\ignore-ssl-errors.ps1

$LEAGUE_DIR = "C:\Riot Games\League of Legends"
$LOCK_FILE = "$LEAGUE_DIR\lockfile"
$YAML_FILE = "$LEAGUE_DIR\Config\lcu-schema\system.yaml"
$RIOT_USERNAME = "riot"

Write-Output "Creating alternate system.yaml."
New-Item -Path "$LEAGUE_DIR\Config\lcu-schema\system.yaml" -Force | Out-Null
$systemYaml  = Get-Content "$LEAGUE_DIR\system.yaml"
$systemYaml  = $systemYaml[0..($systemYaml.count - 4)]
$systemYaml += ("enable_swagger: true")
$systemYaml | Out-File "$YAML_FILE" -Encoding ascii

Write-Output "Starting LeagueClient.exe."
& "$LEAGUE_DIR\LeagueClient.exe" "--system-yaml-override=$LEAGUE_DIR\Config\lcu-schema\system.yaml"

Write-Output "Waiting for lockfile."
$attempt = 10
while (!(Test-Path "$LOCK_FILE")) {
    Start-Sleep 1
    $attempt--
    if ($attempt -le 0) {
        Write-Output "Failed to find lockfile."
        Stop-Process -Name "LeagueClient"
        Exit
    }
}

$lockContent = Get-Content "$LOCK_FILE" -Raw
$lockContent = $lockContent.Split(':')
$port = $lockContent[2];
$pass = $lockContent[3];

$userpass = "${RIOT_USERNAME}:$pass"
$userpass = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userpass))
Write-Output "Lockfile parsed, userpass64: '$userpass'.".

Write-Output "Sending request for spec."
$attempt = 10
$success = $false
while (-not $success) {
  Start-Sleep 1
  try {
    $specResponse = Invoke-WebRequest "https://127.0.0.1:$port/swagger/v3/openapi.json" -Headers @{ 'Authorization' = "Basic $userpass" } -UseBasicParsing
    $helpResponse = Invoke-WebRequest "https://127.0.0.1:$port/help"                    -Headers @{ 'Authorization' = "Basic $userpass" } -UseBasicParsing
    $success = $true
  } catch {
    $attempt--
    if ($attempt -le 0) {
      Write-Output "Failed to connect to LCU with exception:"
      Write-Host $_
      Stop-Process -Name "LeagueClient"
      Remove-Item "$LOCK_FILE"
      Exit
    }
  }
}

Write-Output "Writing spec."
Stop-Process -Name "LeagueClient"
Remove-Item "$LOCK_FILE"

$specObject = $specResponse.Content | ConvertFrom-Json
[IO.File]::WriteAllLines("openapi.json", $($specObject | ConvertTo-Json -Depth 100 | Format-Json))
[IO.File]::WriteAllLines("openapi.min.json", $($specObject | ConvertTo-Json -Depth 100 -Compress))

$helpResponse.Content | ConvertFrom-Json | ConvertTo-Json -Depth 100 | Format-Json | Out-File "help.json" -Encoding UTF8

Write-Output "Success."
