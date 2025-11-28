# WinRE-Fix.ps1 - EN MÜKEMMEL HALİ
param(
    [switch]$WhatIf,
    [switch]$Force,
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Log directory and path (use C:\temp by request)
$LogDir = 'C:\temp'
$LogPath = Join-Path $LogDir 'WinRE-Fix-Log.txt'

# Simple English messages — inline usage below; no localization helper

# Verbose aktif et
if ($Verbose) { $VerbosePreference = 'Continue' }

# LOG FONKSİYONU
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$time [$Level] $Message" | Out-File -FilePath $LogPath -Append -Encoding UTF8
    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARN"  { Write-Host $Message -ForegroundColor Yellow }
        "INFO"  { Write-Host $Message -ForegroundColor Cyan }
        default { Write-Host $Message -ForegroundColor Green }
    }
    if ($Verbose) { Write-Verbose $Message }
}

# Ensure log directory exists and create initial entry
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    $createdMsg = "Log directory created: $LogDir"
    $createdMsg | Out-File -FilePath $LogPath -Append -Encoding UTF8
    Write-Host $createdMsg -ForegroundColor Cyan
}

# Yönetici kontrol
# Administrator check
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log 'ERROR: Script not run as Administrator!' "ERROR"
    exit 1
}


Write-Log '=== WinRE Move Process Started ===' "INFO"

# Yes pattern for prompts (English y/n)
$YesPattern = '^[yY]'

# 1. Find active WinRE partition
if ($WhatIf) {
    Write-Log "WHATIF: simulating 'reagentc /info'..." "INFO"
    $oldPartNum = 5
    Write-Log "Simulated old WinRE partition: $oldPartNum" "INFO"
} else {
    Write-Log "Checking current WinRE with 'reagentc /info'..." "INFO"
    $info = reagentc /info
    $match = $info | Select-String 'partition(\d+)'
    if (-not $match) { Write-Log "WinRE partition not found!" "ERROR"; exit 1 }
    $oldPartNum = [int]$match.Matches[0].Groups[1].Value
    Write-Log "Old WinRE partition: $oldPartNum" "INFO"
}

# 2. Disable WinRE
if ($WhatIf) {
    Write-Log "WHATIF: 'reagentc /disable' not executed." "INFO"
} else {
    Write-Log "Running 'reagentc /disable'..." "INFO"
    reagentc /disable | Out-Null
    if (-not (Test-Path "C:\Windows\System32\Recovery\Winre.wim")) {
        Write-Log "Winre.wim not created!" "ERROR"; exit 1
    }
}
Write-Log "WinRE disabled → Winre.wim preserved." "INFO"

    $oldPart = Get-Partition -DiskNumber 0 -PartitionNumber $oldPartNum -ErrorAction SilentlyContinue
    if ($oldPart -and $oldPart.GptType -eq '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}') {
    if ($WhatIf) {
        Write-Log "WHATIF: Old partition $oldPartNum will not be deleted." "INFO"
    } elseif ($Force -or (Read-Host "Delete old Recovery partition ($oldPartNum)? (y/n)") -match $YesPattern) {
        Write-Log "Deleting old partition..." "INFO"
        if (-not $WhatIf) { Remove-Partition -DiskNumber 0 -PartitionNumber $oldPartNum -Confirm:$false }
        Write-Log "Old recovery partition deleted." "INFO"
    } else {
        Write-Log "Operation cancelled." "WARN"; exit 0
    }
} else {
    Write-Log "Old partition is not WinRE type or not found. Skipping." "WARN"
}

# 4. Extend C: → Simulated data in WhatIf
if ($WhatIf) {
    Write-Log "WHATIF: simulating Get-PartitionSupportedSize..." "INFO"
    $cPart = Get-Partition -DriveLetter C
    $currentSize = $cPart.Size
    $simulatedMax = $currentSize + 30GB + 1GB  # +30GB free + 1GB recovery
    $maxSize = $simulatedMax
    $simGB = [math]::Round($maxSize/1GB,2)
    Write-Log "Simulated max size: $simGB GB" "INFO"
} else {
    $cPart = Get-Partition -DriveLetter C
    $supported = Get-PartitionSupportedSize -DriveLetter C
    $maxSize = $supported.SizeMax
}

if ($maxSize -le ($cPart.Size + 1GB)) {
    Write-Log "Not enough free space! Need at least 1 GB + buffer." "ERROR"; exit 1
}

$newCSize = $maxSize - 1GB
$extendGB = [math]::Round(($newCSize - $cPart.Size) / 1GB, 2)

Write-Log "C: will be extended: +$extendGB GB (1 GB reserved)" "INFO"
if ($WhatIf) {
    Write-Log "WHATIF: Resize-Partition not executed." "INFO"
} else {
    Resize-Partition -DriveLetter C -Size $newCSize
}
Write-Log "C: extended." "INFO"

if ($WhatIf) {
    $newPart = [PSCustomObject]@{ PartitionNumber = 99; AccessPaths = @('\\?\Volume{simulated-guid}\') }
    Write-Log "WHATIF: New-Partition simulated → Partition 99" "INFO"
} else {
    $newPart = New-Partition -DiskNumber 0 -UseMaximumSize
    Start-Sleep -Seconds 2
}
$accessPath = ($newPart.AccessPaths | Where-Object { $_ -like '\\?\Volume*' } | Select-Object -First 1)
if (-not $accessPath) { Write-Log "Access path could not be obtained!" "ERROR"; exit 1 }

if ($WhatIf) {
    Write-Log "WHATIF: format not executed." "INFO"
} else {
    cmd /c "format '$accessPath' /FS:NTFS /V:Recovery /Q /Y" | Out-Null
}
Write-Log "New partition formatted." "INFO"

if ($WhatIf) {
    Write-Log "WHATIF: Set-Partition and DiskPart not executed." "INFO"
} else {
    Set-Partition -DiskNumber 0 -PartitionNumber $newPart.PartitionNumber -GptType "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}"
    $diskpartScript = @"
select disk 0
select partition $($newPart.PartitionNumber)
gpt attributes=0x8000000000000001
exit
"@
    $diskpartScript | diskpart | Out-Null
}
Write-Log "New recovery partition: $($newPart.PartitionNumber) → no drive letter + hidden" "INFO"

# 6. Enable WinRE
Write-Log "Enabling WinRE..." "INFO"
if ($WhatIf) {
    Write-Log "WHATIF: 'reagentc /enable' not executed." "INFO"
} else {
    reagentc /enable
    if ($LASTEXITCODE -ne 0) { Write-Log "'reagentc /enable' failed!" "ERROR"; exit 1 }
}
Write-Log "WinRE enabled." "INFO"

# 7. Final status
Write-Log "`n=== OPERATION COMPLETE! ===" "INFO"
if ($WhatIf) {
    Write-Log "WHATIF: 'reagentc /info' simulated → Enabled, partition 99" "INFO"
} else {
    reagentc /info | ForEach-Object { Write-Log $_ "INFO" }
}
Write-Log "Log: $LogPath" "INFO"
Write-Host "Log file: $LogPath" -ForegroundColor Magenta