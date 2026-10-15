# Show-SystemInfo.ps1

Write-Host "=== System Information ===" -ForegroundColor Cyan

# ============================================================
# CPU
# ============================================================

$cpu = Get-CimInstance Win32_Processor

Write-Host "`nCPU:" $cpu.Name
Write-Host "Cores:" $cpu.NumberOfCores `
    "| Logical Processors:" $cpu.NumberOfLogicalProcessors

# ============================================================
# RAM
# ============================================================

$ram = Get-CimInstance Win32_ComputerSystem
$ramTotalGB = [Math]::Round($ram.TotalPhysicalMemory / 1GB, 2)

Write-Host "`nRAM:" $ramTotalGB "GB"

# ============================================================
# GPU
# ============================================================

$gpu = Get-CimInstance Win32_VideoController

foreach ($g in $gpu) {

    if ($g.AdapterRAM) {
        $vramGB = [Math]::Round($g.AdapterRAM / 1GB, 2)
    }
    else {
        $vramGB = "Unknown"
    }

    Write-Host "`nGPU:" $g.Name
    Write-Host "VRAM:" $vramGB "GB"
}

# ============================================================
# VOLUMES
# ============================================================

Write-Host "`n=== Mounted Volumes ===" -ForegroundColor Cyan

$volumes = Get-Volume |
Where-Object {
    $_.DriveLetter -and
    $_.DriveType -in @('Fixed', 'Removable')
} |
Sort-Object DriveLetter

foreach ($vol in $volumes) {

    $partition = Get-Partition `
        -DriveLetter $vol.DriveLetter `
        -ErrorAction SilentlyContinue

    $diskNumber = if ($partition) {
        $partition.DiskNumber
    }
    else {
        "Unknown"
    }

    $sizeGB = [Math]::Round($vol.Size / 1GB, 2)
    $freeGB = [Math]::Round($vol.SizeRemaining / 1GB, 2)
    $usedGB = [Math]::Round($sizeGB - $freeGB, 2)

    if ($sizeGB -gt 0) {
        $percentUsed = [Math]::Round(
            ($usedGB / $sizeGB) * 100, 2
        )
    }
    else {
        $percentUsed = 0
    }

   

    Write-Host ""
    Write-Host "Drive       : $($vol.DriveLetter):"
    Write-Host "Disk Number : $diskNumber"
    Write-Host "Label       : $($vol.FileSystemLabel)"
    Write-Host "Type        : $($vol.DriveType)"
    Write-Host "Filesystem  : $($vol.FileSystem)"
    Write-Host "Used        : " -NoNewLine
    $usageText = "Used        : $usedGB GB / $sizeGB GB ($percentUsed%)"

    if ($percentUsed -ge 90) {
        Write-Host $usageText -ForegroundColor Red
    }
    elseif ($percentUsed -ge 80) {
        Write-Host $usageText -ForegroundColor Yellow
    }
    else {
        Write-Host $usageText
    }
    Write-Host "Free        : $freeGB GB"
}

# =========================ISKS
# ============================================================

Write-Host "`n=== Physical Disks ===" -ForegroundColor Cyan

$physicalDisks = Get-PhysicalDisk |
Sort-Object DeviceId

foreach ($disk in $physicalDisks) {

    $sizeGB = [Math]::Round($disk.Size / 1GB, 2)

    Write-Host ""
    Write-Host "Disk Number : $($disk.DeviceId)"
    Write-Host "Model       : $($disk.FriendlyName)"
    Write-Host "Bus Type    : $($disk.BusType)"
    Write-Host "Media Type  : $($disk.MediaType)"
    Write-Host "Size        : $sizeGB GB"
    Write-Host "Health      : $($disk.HealthStatus)"
    Write-Host "Operational : $($disk.OperationalStatus)"
}

# ============================================================
# RELIABILITY / SMART DATA
# ============================================================

Write-Host "`n=== SMART / Reliability Data ===" -ForegroundColor Cyan

$physicalDisks = Get-PhysicalDisk

foreach ($disk in $physicalDisks) {

    Write-Host ""
    Write-Host "Device : $($disk.FriendlyName)"

    try {

        $rel = Get-StorageReliabilityCounter `
            -PhysicalDisk $disk `
            -ErrorAction Stop

        if ($null -ne $rel.Temperature) {
            Write-Host "Temperature        : $($rel.Temperature) C"
        }

        if ($null -ne $rel.PowerOnHours) {
            Write-Host "Power-On Hours     : $($rel.PowerOnHours)"
        }

        if ($null -ne $rel.Wear) {
            Write-Host "Wear Level         : $($rel.Wear)%"
        }

        if ($null -ne $rel.ReadErrorsTotal) {
            Write-Host "Read Errors Total  : $($rel.ReadErrorsTotal)"
        }

        if ($null -ne $rel.WriteErrorsTotal) {
            Write-Host "Write Errors Total : $($rel.WriteErrorsTotal)"
        }

        if ($null -ne $rel.StartStopCycleCount) {
            Write-Host "Start/Stop Cycles  : $($rel.StartStopCycleCount)"
        }

        if ($null -ne $rel.LoadUnloadCycleCount) {
            Write-Host "Load/Unload Cycles : $($rel.LoadUnloadCycleCount)"
        }

        if ($null -ne $rel.ReallocatedSectors) {
            Write-Host "Reallocated Sector : $($rel.ReallocatedSectors)"
        }

        if ($null -ne $rel.FlushLatencyMax) {
            Write-Host "Max Flush Latency  : $($rel.FlushLatencyMax)"
        }

    }
    catch {

        Write-Host "Reliability counters not available."
    }
}

# ============================================================
# DISK -> DRIVE MAPPING
# ============================================================

Write-Host "`n=== Disk to Volume Mapping ===" -ForegroundColor Cyan

Get-Partition |
Where-Object DriveLetter |
ForEach-Object {

    $disk = Get-Disk -Number $_.DiskNumber

    Write-Host (
        "Disk {0} -> {1}: ({2})" -f `
        $_.DiskNumber,
        $_.DriveLetter,
        $disk.FriendlyName
    )
}

Write-Host "`nDone." -ForegroundColor Green
