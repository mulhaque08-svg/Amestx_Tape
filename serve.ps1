$port = 8080
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $port)
$listener.Start()
Write-Host "SiteTap Pro Server running on ALL interfaces at http://10.0.0.250:$port and http://localhost:$port"

$root = Get-Location

while ($true) {
    try {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $writer = New-Object System.IO.StreamWriter($stream)
        
        $requestLine = $reader.ReadLine()
        if ($null -eq $requestLine) { $client.Close(); continue }
        
        $tokens = $requestLine.Split(" ")
        if ($tokens.Length -lt 2) { $client.Close(); continue }
        
        $path = $tokens[1]
        if ($path -eq "/" -or $path -eq "") { $path = "/index.html" }
        if ($path.Contains("?")) { $path = $path.Substring(0, $path.IndexOf("?")) }
        
        $localPath = Join-Path $root ($path.TrimStart('/'))
        
        if (Test-Path $localPath -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($localPath)
            
            $ext = [System.IO.Path]::GetExtension($localPath)
            $contentType = "application/octet-stream"
            switch ($ext) {
                ".html" { $contentType = "text/html; charset=utf-8" }
                ".css"  { $contentType = "text/css; charset=utf-8" }
                ".js"   { $contentType = "text/javascript; charset=utf-8" }
                ".json" { $contentType = "application/json" }
                ".png"  { $contentType = "image/png" }
                ".jpg"  { $contentType = "image/jpeg" }
            }
            
            $writer.WriteLine("HTTP/1.1 200 OK")
            $writer.WriteLine("Content-Type: $contentType")
            $writer.WriteLine("Content-Length: $($bytes.Length)")
            $writer.WriteLine("Connection: close")
            $writer.WriteLine()
            $writer.Flush()
            
            $stream.Write($bytes, 0, $bytes.Length)
        } else {
            $writer.WriteLine("HTTP/1.1 404 Not Found")
            $writer.WriteLine("Content-Length: 0")
            $writer.WriteLine("Connection: close")
            $writer.WriteLine()
            $writer.Flush()
        }
        
        $client.Close()
    } catch {
        # continue loop
    }
}
