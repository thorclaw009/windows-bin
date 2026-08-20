param(
    [string]$RootDir = ".",
    [int]$Port = 3031
)



# or run the following command in an elevated PowerShell prompt to allow the URL reservation for the current user:
# netsh http add urlacl url=http://+:3031/ user=jbamg

# Punch through firewall
# netsh http delete urlacl url=http://+:3031/
# netsh http add urlacl url=http://+:3031/ user=jbamg
# netsh advfirewall firewall add rule name="EPUB Server" dir=in action=allow protocol=TCP localport=3031


# Check if running as Administrator
# $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
# $principal = New-Object Security.Principal.WindowsPrincipal($identity)

# if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
#     Write-Host "Restarting script as Administrator..."

#     # Build argument list safely
#     $escapedArgs = $args | ForEach-Object { '"{0}"' -f $_ }
#     $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" " + ($escapedArgs -join ' ')

#     # Relaunch elevated
#     Start-Process -FilePath "pwsh.exe" -Verb RunAs -ArgumentList $argList

#     # Terminate current non-admin instance
#     exit
# }


# Ensure absolute path
$RootDir = (Resolve-Path $RootDir).Path

Write-Host "Starting EPUB server..."
Write-Host "Root directory: $RootDir"
Write-Host "Port: $Port"

# Create HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$Port/")
$listener.Start()

Write-Host "Server running at http://+:$Port/"
Write-Host "Serving files from: $RootDir"

function Get-EpubFiles {
    Get-ChildItem -Path $RootDir -Recurse -Filter *.epub | Select-Object FullName, Name
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        try {
            Write-Host "Handling request: $($request.HttpMethod) $($request.Url.AbsolutePath)"

            if ($request.Url.AbsolutePath -eq "/") {
                $files = Get-EpubFiles
                $html = "<html><body><h1>EPUB Files</h1><ul>"
                foreach ($file in $files) {
                    $relative = [System.IO.Path]::GetRelativePath($RootDir, $file.FullName)
                    $encoded = [System.Web.HttpUtility]::UrlEncode($relative)
                    $html += "<li><a href='/download?path=$encoded'>$($file.Name)</a></li>"
                }
                $html += "</ul></body></html>"

                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                $response.ContentType = "text/html"
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            elseif ($request.Url.AbsolutePath -eq "/download") {
                $path = $request.QueryString["path"]
                $filePath = Join-Path $RootDir $path

                if (Test-Path $filePath -PathType Leaf) {
                    $bytes = [System.IO.File]::ReadAllBytes($filePath)
                    $response.ContentType = "application/epub+zip"
                    $response.AddHeader("Content-Disposition", "attachment; filename=$(Split-Path $filePath -Leaf)")
                    $response.OutputStream.Write($bytes, 0, $bytes.Length)
                }
                else {
                    $msg = "File not found"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($msg)
                    $response.StatusCode = 404
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
        }
        catch {
            $msg = "Internal server error"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($msg)
            $response.StatusCode = 500
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        }
        finally {
            $response.OutputStream.Close()
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
    Write-Host "Server stopped."
}
