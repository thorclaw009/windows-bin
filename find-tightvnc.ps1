param(
    [string]$Network = "192.168.1.0",
    [int]$port = 5900
)

$results = 1..255 | ForEach-Object -Parallel {
    $ip = $using:Network -replace "\.0$", ".$_"
    #Write-Host "IP Addr: $ip"

    $status = "Offline"
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($ip, $using:port)
        if ($tcpClient.Connected) {
            $tcpClient.Close()
            $status = "TightVNC ($using:port)"
        }
    } catch {
        if (Test-Connection -ComputerName $ip -Count 1 -Quiet) {
            $status = "Online"
        }
    }
    [PSCustomObject]@{
        IP     = $ip
        Status = $status
    }
} -ThrottleLimit 128

# Display results in a nice table

$results | Where-Object { $_.Status.startsWith("TightVNC ") -or $_.Status -eq "Online"} | Sort-Object IP | Format-Table -AutoSize
#$results | Sort-Object IP | Format-Table -AutoSize
