param(
    [string]$Network = "192.168.1.0",
    [int]$port = 5900
)

$localIps = Get-NetIPAddress -AddressFamily IPv4 | Select-Object -ExpandProperty IPAddress
Write-Host "Local IPs: $($localIps -join ', ')"

$timeoutMs = 100
$pingTimeoutMs = 100

$results = 1..255 | ForEach-Object -Parallel {
    $ip = $using:Network -replace "\.0$", ".$_"
    # Write-Host "IP Addr: $ip"

    $status = "Offline"

    if ($using:localIps -contains $ip) {
        $status = "Self ($using:port)"
    } else {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connectTask = $tcpClient.ConnectAsync($ip, $using:port)

            if (-not $connectTask.Wait($using:timeoutMs)) {
                $tcpClient.Close()
                throw "Connect timed out"
            }

            if ($tcpClient.Connected) {
                $tcpClient.Close()
                $status = "TightVNC ($using:port)"
            }
        } catch {
            try {
                $ping = New-Object System.Net.NetworkInformation.Ping
                $reply = $ping.Send($ip, $using:timeOutMs)
                if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                    $status = "Online"
                }
            } catch {
                $status = "Offline"
            }
        }
    }

    [PSCustomObject]@{
        IP     = $ip
        Status = $status
    }
} -ThrottleLimit 128

# Display results in a nice table
$results |
    Where-Object { $_.Status.StartsWith("TightVNC ") -or $_.Status -eq "Online" -or $_.Status.StartsWith("Self") } |
    Sort-Object IP |
    Format-Table -AutoSize
