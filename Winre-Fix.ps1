<#
.SYNOPSIS
    WinRE-Fix.ps1 - Windows Recovery Environment Partition Fix Tool
    WinRE-Fix.ps1 - Windows Kurtarma Ortamı Bölümü Düzeltme Aracı

.DESCRIPTION
    EN: Moves WinRE to a new partition at the end of the disk, allowing C: drive 
        expansion. Fixes KB5034441/KB5028997 Windows Update failures.
    TR: WinRE'yi diskin sonuna taşır, C: sürücüsünün genişlemesine izin verir.
        KB5034441/KB5028997 Windows Update hatalarını düzeltir.

.PARAMETER WhatIf
    EN: Simulate without making changes | TR: Değişiklik yapmadan simüle et

.PARAMETER Force
    EN: Skip confirmations | TR: Onayları atla

.PARAMETER Verbose
    EN: Show detailed output | TR: Detaylı çıktı göster

.EXAMPLE
    .\Winre-Fix.ps1 -WhatIf
    # Simulate the operation / İşlemi simüle et

.EXAMPLE
    .\Winre-Fix.ps1 -Force
    # Run without prompts / Onay sormadan çalıştır

.NOTES
    Author : tazxtazxedu
    GitHub : https://github.com/tazxtazxedu/WinRE-Fix
    License: MIT
    Requires: Administrator privileges, Windows 10/11, GPT disk
#>
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

# ============================================================
# BACKUP WARNING
# ============================================================
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║  ⚠️  WARNING: BACKUP YOUR DATA BEFORE PROCEEDING!  ⚠️             ║" -ForegroundColor Red
Write-Host "║                                                                    ║" -ForegroundColor Red
Write-Host "║  This script modifies disk partitions. Data loss may occur.       ║" -ForegroundColor Red
Write-Host "║  Make sure you have a full system backup before continuing.       ║" -ForegroundColor Red
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

if (-not $Force -and -not $WhatIf) {
    $backupConfirm = Read-Host "Have you backed up your data? Type 'YES' to continue"
    if ($backupConfirm -ne 'YES') {
        Write-Log "Operation cancelled. Please backup your data first." "WARN"
        exit 0
    }
    Write-Log "User confirmed backup. Proceeding..." "INFO"
}

# Yes pattern for prompts (English y/n)
$YesPattern = '^[yY]'

# ============================================================
# PRE-CHECK: Verify unallocated space exists on Disk 0
# ============================================================
$MinRequiredGB = 1.2
$MinRequired = $MinRequiredGB * 1GB

Write-Log "Checking for unallocated space on Disk 0 before starting..." "INFO"

if ($WhatIf) {
    Write-Log "WHATIF: simulating unallocated space check..." "INFO"
    $unallocatedBytes = 2GB  # Simulated for testing
    Write-Log "WHATIF: Simulated unallocated space: $([math]::Round($unallocatedBytes/1GB,2)) GB" "INFO"
} else {
    # Get disk total size and sum of all partitions
    $disk = Get-Disk -Number 0
    $diskSize = $disk.Size
    $partitions = Get-Partition -DiskNumber 0 -ErrorAction SilentlyContinue
    $usedSpace = ($partitions | Measure-Object -Property Size -Sum).Sum
    $unallocatedBytes = $diskSize - $usedSpace
    
    $diskSizeGB = [math]::Round($diskSize/1GB,2)
    $usedGB = [math]::Round($usedSpace/1GB,2)
    $unallocatedGB = [math]::Round($unallocatedBytes/1GB,2)
    
    Write-Log "Disk 0 layout:" "INFO"
    Write-Log "  Total disk size: $diskSizeGB GB" "INFO"
    Write-Log "  Used by partitions: $usedGB GB" "INFO"
    Write-Log "  Unallocated space: $unallocatedGB GB" "INFO"
}

# Check if there's any unallocated space
if ($unallocatedBytes -le 0) {
    Write-Log "ERROR: No unallocated space found on Disk 0." "ERROR"
    Write-Log "Cannot extend C: drive - there is no free space available." "ERROR"
    Write-Log "You may need to shrink an existing partition or delete the old Recovery partition first." "ERROR"
    exit 1
}

# Check if unallocated space is sufficient
if ($unallocatedBytes -lt $MinRequired) {
    $unallocatedGB = [math]::Round($unallocatedBytes/1GB,2)
    if (-not $Force) {
        Write-Log "WARNING: Unallocated space is only $unallocatedGB GB (minimum recommended: $MinRequiredGB GB)." "WARN"
        Write-Log "This may not be enough to create a proper Recovery partition." "WARN"
        Write-Log "Run with -Force to proceed anyway (not recommended)." "ERROR"
        exit 1
    } else {
        Write-Log "WARNING: Unallocated space ($unallocatedGB GB) is below recommended minimum ($MinRequiredGB GB)." "WARN"
        Write-Log "-Force supplied, proceeding anyway..." "WARN"
    }
} else {
    $unallocatedGB = [math]::Round($unallocatedBytes/1GB,2)
    Write-Log "OK: Sufficient unallocated space found ($unallocatedGB GB >= $MinRequiredGB GB)." "INFO"
}

# ============================================================
# 1. Find active WinRE partition
# ============================================================
$RecoveryGptType = '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'

if ($WhatIf) {
    Write-Log "WHATIF: simulating WinRE partition detection..." "INFO"
    $oldPartNum = 5
    $oldRecoverySize = 762MB
    Write-Log "WHATIF: Simulated old WinRE partition: $oldPartNum" "INFO"
} else {
    Write-Log "Checking current WinRE status with 'reagentc /info'..." "INFO"
    $info = reagentc /info
    Write-Log "reagentc /info output:" "INFO"
    $info | ForEach-Object { Write-Log "  $_" "INFO" }
    
    # Check if WinRE is enabled
    $reStatus = $info | Select-String -Pattern 'Windows RE status:\s*(Enabled|Disabled)' 
    if ($reStatus -and $reStatus.Matches[0].Groups[1].Value -eq 'Disabled') {
        Write-Log "ERROR: WinRE is already disabled. Nothing to move." "ERROR"
        Write-Log "Run 'reagentc /enable' first if you want to use this script." "ERROR"
        exit 1
    }
    
    # Find Recovery partition by scanning all partitions for correct GPT type
    Write-Log "Scanning Disk 0 for Recovery partition (GPT Type: $RecoveryGptType)..." "INFO"
    $allPartitions = Get-Partition -DiskNumber 0 -ErrorAction SilentlyContinue
    $recoveryPartitions = $allPartitions | Where-Object { $_.GptType -eq $RecoveryGptType }
    
    if (-not $recoveryPartitions -or $recoveryPartitions.Count -eq 0) {
        Write-Log "ERROR: No Recovery partition found on Disk 0." "ERROR"
        Write-Log "Could not find any partition with GPT Type: $RecoveryGptType" "ERROR"
        Write-Log "Available partitions:" "INFO"
        $allPartitions | ForEach-Object {
            $sizeGB = [math]::Round($_.Size/1GB,2)
            Write-Log "  Partition $($_.PartitionNumber): $sizeGB GB - Type: $($_.GptType)" "INFO"
        }
        exit 1
    }
    
    # If multiple recovery partitions, pick the last one (usually the active WinRE)
    if ($recoveryPartitions.Count -gt 1) {
        Write-Log "Found $($recoveryPartitions.Count) Recovery partitions. Using the last one." "INFO"
        $oldPart = $recoveryPartitions | Sort-Object PartitionNumber | Select-Object -Last 1
    } else {
        $oldPart = $recoveryPartitions
    }
    
    $oldPartNum = $oldPart.PartitionNumber
    $oldRecoverySize = $oldPart.Size
    $oldPartSizeMB = [math]::Round($oldRecoverySize/1MB,0)
    
    Write-Log "Found Recovery partition:" "INFO"
    Write-Log "  Partition Number: $oldPartNum" "INFO"
    Write-Log "  Size: $oldPartSizeMB MB" "INFO"
    Write-Log "  GPT Type: $($oldPart.GptType)" "INFO"
    
    # Sanity check: Recovery partition should not be > 10GB
    if ($oldRecoverySize -gt 10GB) {
        Write-Log "ERROR: Partition $oldPartNum is $([math]::Round($oldRecoverySize/1GB,2)) GB - too large for Recovery!" "ERROR"
        Write-Log "This is unexpected. Aborting for safety." "ERROR"
        exit 1
    }
    
    Write-Log "OK: Valid Recovery partition found (Partition $oldPartNum)." "INFO"
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

# 3. Delete old Recovery partition
Write-Log "Preparing to delete old Recovery partition $oldPartNum..." "INFO"
if ($WhatIf) {
    Write-Log "WHATIF: Old partition $oldPartNum will not be deleted." "INFO"
} elseif ($Force -or (Read-Host "Delete old Recovery partition ($oldPartNum)? (y/n)") -match $YesPattern) {
    Write-Log "Deleting old partition $oldPartNum..." "INFO"
    Remove-Partition -DiskNumber 0 -PartitionNumber $oldPartNum -Confirm:$false
    Write-Log "Old recovery partition deleted successfully." "INFO"
} else {
    Write-Log "Operation cancelled by user." "WARN"
    exit 0
}

# 4. Extend C: partition
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

# 5. Set GPT type and attributes (Recovery partition + hidden + no drive letter)
Write-Log "Setting partition type to Recovery and marking as hidden..." "INFO"
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
Write-Log "New recovery partition: $($newPart.PartitionNumber) → GPT type set + hidden" "INFO"

# 6. Enable WinRE
# reagentc /enable will automatically use C:\Windows\System32\Recovery\Winre.wim
# and configure it on the new Recovery partition
Write-Log "Enabling WinRE..." "INFO"
if ($WhatIf) {
    Write-Log "WHATIF: 'reagentc /enable' not executed." "INFO"
} else {
    # Verify Winre.wim exists before enabling
    $wimPath = "C:\Windows\System32\Recovery\Winre.wim"
    if (-not (Test-Path $wimPath)) {
        Write-Log "ERROR: Winre.wim not found at $wimPath" "ERROR"
        Write-Log "Cannot enable WinRE without the recovery image." "ERROR"
        exit 1
    }
    Write-Log "Winre.wim found at $wimPath" "INFO"
    
    Write-Log "Running 'reagentc /enable'..." "INFO"
    reagentc /enable
    if ($LASTEXITCODE -ne 0) { 
        Write-Log "ERROR: 'reagentc /enable' failed with exit code $LASTEXITCODE" "ERROR"
        exit 1 
    }
}
Write-Log "WinRE enabled successfully." "INFO"

# 7. Final status
Write-Log "`n=== OPERATION COMPLETE! ===" "INFO"
if ($WhatIf) {
    Write-Log "WHATIF: 'reagentc /info' simulated → Enabled, partition 99" "INFO"
} else {
    reagentc /info | ForEach-Object { Write-Log $_ "INFO" }
}
Write-Log "Log: $LogPath" "INFO"
Write-Host "Log file: $LogPath" -ForegroundColor Magenta