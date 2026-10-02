# System Information Script
# Save as systeminfo.ps1 and run in PowerShell

Write-Host "=== System Information ===" -ForegroundColor Cyan

# CPU Info
$cpu = Get-CimInstance Win32_Processor
Write-Host "`nCPU:" $cpu.Name
Write-Host "Cores:" $cpu.NumberOfCores " | Logical Processors:" $cpu.NumberOfLogicalProcessors

# RAM Info
$ram = Get-CimInstance Win32_ComputerSystem
$ramTotalGB = [math]::Round($ram.TotalPhysicalMemory / 1GB, 2)
Write-Host "`nRAM: $ramTotalGB GB"

# GPU Info
$gpu = Get-CimInstance Win32_VideoController
foreach ($g in $gpu) {
    $vramGB = [math]::Round($g.AdapterRAM / 1GB, 2)
    Write-Host "`nGPU:" $g.Name
    Write-Host "VRAM:" $vramGB "GB"
}

# Disk Info
$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
Write-Host "`n=== Disk Usage ==="
foreach ($d in $disks) {
    $sizeGB = [math]::Round($d.Size / 1GB, 2)
    $freeGB = [math]::Round($d.FreeSpace / 1GB, 2)
    $usedGB = $sizeGB - $freeGB
    $percentUsed = [math]::Round(($usedGB / $sizeGB) * 100, 2)
    Write-Host "$($d.DeviceID): $usedGB GB used / $sizeGB GB total ($percentUsed% full)"
}
