param(
    [string]$Network = "192.168.1.0",
    [int]$port = 5900
)

# Batch jobs in groups of 32
$jobs = @()
for ($i = 1; $i -le 255; $i++) {
    $ip = $Network -replace "\.0$", ".$i"

    $jobs += Start-Job -ScriptBlock {
        param($ip, $port)
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.Connect($ip, $port)
            if ($tcpClient.Connected) {
                $tcpClient.Close()
                "$ip is online"
            }
        } catch {
            # Do nothing if offline
        }
    } -ArgumentList $ip, $port

    # Process results in batches of 32
    if ($jobs.Count -ge 32) {
        $results = $jobs | Wait-Job | Receive-Job
        $results | ForEach-Object { Write-Host $_ }
        $jobs | Remove-Job
        $jobs = @()
    }
}

# Process any remaining jobs
if ($jobs.Count -gt 0) {
    $results = $jobs | Wait-Job | Receive-Job
    $results | ForEach-Object { Write-Host $_ }
    $jobs | Remove-Job
}
