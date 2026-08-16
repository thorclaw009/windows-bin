param(
    [string]$RootDir = ".",
    [string]$HostName = "127.0.0.1",
    [int]$Port = 3031
)

Write-Host "Starting EPUB server..."
Write-Host "Root directory: $RootDir"
Write-Host "Host: $HostName"
Write-Host "Port: $Port"

# Ensure absolute path
$RootDir = (Resolve-Path $RootDir).Path

# Create HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://$HostName`:$Port/")
$listener.Start()

Write-Host "Server running at http://$HostName`:$Port/"
Write-Host "Serving files from: $RootDir"

function Get-EpubFiles {
    Get-ChildItem -Path $RootDir -Recurse -Filter *.epub | Select-Object FullName, Name
}

while ($true) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    Write-Host "Received request: ${context} ${response} $($request.HttpMethod) $($request.Url.AbsolutePath)"
    if ($request -eq $null) {
        Write-Host "Response is null. Skipping request."
        continue
    }

    try {
        Write-Host "Handling request: $($request.HttpMethod) $($request.Url.AbsolutePath)"
        if ($request.Url.AbsolutePath -eq "/") {
            # List EPUB files
            $files = Get-EpubFiles
            Write-Host "Found $($files.Count) EPUB files ${files}."
            $html = "<html><head><title>EPUB Server</title></head><body><h1>EPUB Files</h1><ul>"

            foreach ($file in $files) {
                $relative = [System.IO.Path]::GetRelativePath((Get-Location).Path, $file.FullName)
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
            $filePath = Join-Path (Get-Location).Path $path

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
