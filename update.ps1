#requires -PSEdition Core

# Config.
$OUT_DIR = 'out'
$RCS_OUT_DIR = Join-Path $OUT_DIR 'rcs'
$LCU_OUT_DIR = Join-Path $OUT_DIR 'lcu'

$LOGIN_FILE = 'lollogin.json'
$LOGIN = Get-Content $LOGIN_FILE | ConvertFrom-Json

$RCS_LOCKFILE = Join-Path $env:LOCALAPPDATA 'Riot Games\Riot Client\Config\lockfile'
$RCS_DIR = 'C:\Riot Games\Riot Client'
$RCS_EXE = Join-Path $RCS_DIR 'RiotClientServices.exe'
$RCS_ARGS = '--launch-product=league_of_legends', '--launch-patchline=live'

$LCU_DIR = 'C:\Riot Games\League of Legends'
$LCU_LOCKFILE = Join-Path $LCU_DIR 'lockfile'
$LCU_SYSTEMYAML = Join-Path $LCU_DIR 'system.yaml'
$LCU_EXE = Join-Path $LCU_DIR 'LeagueClient.exe'

$INSTALLER_EXE = '.\install.na.exe'
$INSTALLER_ARGS = '--skip-to-install'

$LOL_INSTALL_ID = 'league_of_legends.live'

If (Test-Path $env:RUNNER_TEMP) { # For GitHub Actions runners
    $INSTALLER_EXE = Join-Path $env:RUNNER_TEMP $INSTALLER_EXE
}

If (-Not (Test-Path $LOGIN_FILE)) {
    Throw "Login not found: $LOGIN_FILE."
}

function Stop-RiotProcesses {
    # Stop any existing processes.
    Stop-Process -Name 'RiotClientUx' -ErrorAction Ignore
    Stop-Process -Name 'LeagueClient' -ErrorAction Ignore
    Wait-Process -Name 'RiotClientUx' -ErrorAction Ignore
    Wait-Process -Name 'LeagueClient' -ErrorAction Ignore
    Remove-Item $RCS_LOCKFILE -Force -ErrorAction Ignore
    Remove-Item $LCU_LOCKFILE -Force -ErrorAction Ignore
    Start-Sleep 5 # Wait for processes to settle.
}

function Invoke-RiotRequest {
    Param (
        [Parameter(Mandatory=$true)]  [String]$lockfile,
        [Parameter(Mandatory=$true)]  [String]$path,
        [Parameter(Mandatory=$false)] [String]$method = 'GET',
        [Parameter(Mandatory=$false)] $body = $null,
        [Parameter(Mandatory=$false)] [Int]$attempts = 100
    )

    While ($True) {
        Try {
            $lockContent = Get-Content $lockfile -Raw
            $lockContent = $lockContent.Split(':')
            $port = $lockContent[2];
            $pass = $lockContent[3];

            $pass = ConvertTo-SecureString $pass -AsPlainText -Force
            $cred = New-Object -TypeName PSCredential -ArgumentList 'riot', $pass

            $uri = New-Object System.UriBuilder -ArgumentList 'https', '127.0.0.1', $port, $path | % Uri | % AbsoluteUri

            $result = Invoke-RestMethod $uri `
                -SkipCertificateCheck `
                -Method $method `
                -Authentication 'Basic' `
                -Credential $cred `
                -ContentType 'application/json' `
                -Body $($body | ConvertTo-Json)
            Return $result
        } Catch {
            $attempts--
            If ($attempts -le 0) {
                Write-Host "Failed to $method '$path'."
                Throw $_
            }
            Write-Host "Failed to $method '$path', retrying: $_"
            Start-Sleep 5
        }
    }
}

# Stop any existing processes.
Stop-RiotProcesses

# Create output folders.
New-Item -ItemType Directory -Force -Path $OUT_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $RCS_OUT_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $LCU_OUT_DIR | Out-Null

# Install League if not installed.
If (-Not (Test-Path $LCU_EXE)) {
    Write-Host 'Installing LoL.'

    $attempts = 5
    While ($True) {
        Try {
            Invoke-WebRequest 'https://lol.secure.dyn.riotcdn.net/channels/public/x/installer/current/live.na.exe' -OutFile $INSTALLER_EXE
            Break
        }
        Catch {
            $attempts--;
            If ($attempts -le 0) {
                Write-Host "Failed download LoL installer."
                Throw $_
            }
            Start-Sleep 5
        }
    }

    # Start the installer
    & $INSTALLER_EXE $INSTALLER_ARGS

    # RCS starts, but install of LoL hangs, possibly due to .NET Framework 3.5 missing.
    # So we restart it and then it works.
    Invoke-RiotRequest $RCS_LOCKFILE '/patch/v1/installs'
    Stop-RiotProcesses

    Write-Host 'Restarting RCS'
    & $RCS_EXE $RCS_ARGS
    Start-Sleep 5

    $attempts = 15
    While ($True) {
        $status = Invoke-RiotRequest $RCS_LOCKFILE "/patch/v1/installs/$LOL_INSTALL_ID/status"
        If ('up_to_date' -Eq $status.patch.state) {
            Break
        }
        Write-Host "Installing LoL: $($status.patch.progress.progress)%"

        If ($attempts -Le 0) {
            Throw 'Failed to install LoL.'
        }
        $attempts--
        Start-Sleep 20
    }
    Write-Host 'LoL installed successfully.'
    Start-Sleep 1
    Stop-RiotProcesses
}
Else {
    Write-Host 'LoL already installed.'
}

# Start RCS.
Write-Host 'Starting RCS (via LCU).'
& $LCU_EXE
Start-Sleep 5 # Wait for RCS to load so it doesn't overwrite system.yaml.

# Setup system.yaml.
$ENABLE_SWAGGER = 'enable_swagger: true';
If (Select-String -Path $LCU_SYSTEMYAML -Pattern $ENABLE_SWAGGER -SimpleMatch -Quiet) {
    Write-Host "System.yaml already has '$ENABLE_SWAGGER'."
}
Else {
    Write-Host "Updating system.yaml with '$ENABLE_SWAGGER'."
    $systemYaml = Get-Content $LCU_SYSTEMYAML
    $systemYaml += ($ENABLE_SWAGGER)
    $systemYaml | Out-File $LCU_SYSTEMYAML -Encoding ascii
}

Try {
    Start-Sleep 5

    # RCS files.
    Write-Host 'Getting RCS spec files.'
    Invoke-RiotRequest $RCS_LOCKFILE '/Help'                    | ConvertTo-Json -Depth 100 | Out-File -Encoding UTF8 "$RCS_OUT_DIR\help.json"
    Invoke-RiotRequest $RCS_LOCKFILE '/swagger/v3/openapi.json' | ConvertTo-Json -Depth 100 | Out-File -Encoding UTF8 "$RCS_OUT_DIR\openapi.json"
    Invoke-RiotRequest $RCS_LOCKFILE '/swagger/v2/swagger.json' | ConvertTo-Json -Depth 100 | Out-File -Encoding UTF8 "$RCS_OUT_DIR\swagger.json"

    # Login to RCS to start the LCU.
    Write-Host 'Logging into RCS, starts LCU.'
    Invoke-RiotRequest $RCS_LOCKFILE '/rso-auth/v1/authorization/gas' 'POST' $LOGIN | Out-Null

    # Wait for LCU to update itself.
    Start-Sleep 5
    Invoke-RiotRequest $LCU_LOCKFILE '/lol-patch/v1/products/league_of_legends/state' # Burn first request.
    Start-Sleep 10
    $attempts = 40
    While ($True) {
        $state = Invoke-RiotRequest $LCU_LOCKFILE '/lol-patch/v1/products/league_of_legends/state'
        Write-Host "LCU updating: $($state.action)" # Not that useful.
        If ('Idle' -Eq $state.action) {
            Break
        }

        If ($attempts -le 0) {
            Throw 'LCU failed to update.'
        }
        $attempts--
        Start-Sleep 20
    }
    Start-Sleep 5

    # LCU files.
    Write-Host 'Getting LCU queues, maps, catalog.'
    Invoke-RiotRequest $LCU_LOCKFILE '/lol-game-queues/v1/queues' | ConvertTo-Json -Depth 100 | Out-File -Encoding UTF8 "$LCU_OUT_DIR\queues.json"
    Invoke-RiotRequest $LCU_LOCKFILE '/lol-maps/v1/maps'          | ConvertTo-Json -Depth 100 | Out-File -Encoding UTF8 "$LCU_OUT_DIR\maps.json"
    Invoke-RiotRequest $LCU_LOCKFILE '/lol-store/v1/catalog'      | ConvertTo-Json -Depth 100 | Out-File -Encoding UTF8 "$LCU_OUT_DIR\catalog.json"

    Write-Host 'Getting LCU spec files.'
    # /Help is missing the `Content-Type: application/json` header when logged-in.
    Invoke-RiotRequest $LCU_LOCKFILE '/Help' | ConvertFrom-Json -AsHashTable | ConvertTo-Json -Depth 100 | Out-File -Encoding UTF8 "$LCU_OUT_DIR\help.json"
    Try {
        Invoke-RiotRequest $LCU_LOCKFILE '/swagger/v3/openapi.json' -Attempts 10 | ConvertTo-Json -Depth 100 | Out-File -Encoding UTF8 "$LCU_OUT_DIR\openapi.json"
    }
    Catch {
        $env:SOFT_FAIL = $_
        git checkout HEAD -- "$LCU_OUT_DIR\openapi.json"
    }
    Try {
        Invoke-RiotRequest $LCU_LOCKFILE '/swagger/v2/swagger.json' -Attempts 10 | ConvertTo-Json -Depth 100 | Out-File -Encoding UTF8 "$LCU_OUT_DIR\swagger.json"
    }
    Catch {
        $env:SOFT_FAIL = $_
        git checkout HEAD -- "$LCU_OUT_DIR\swagger.json"
    }
} Finally {
    Stop-RiotProcesses
}

Write-Host 'Success!'
