# 设置Web服务器的根目录
$root = "$PSScriptRoot\logs"

# 启动Web服务器
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://*:8080/")
$listener.Start()
Write-Output "Listening on port 8080..."

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    $localPath = $root + $request.Url.LocalPath
    if (Test-Path $localPath) {
        if (Test-Path $localPath -PathType Container) {
            # 目录浏览
            $files = Get-ChildItem -Path $localPath
            $response.ContentType = "text/html"
            $response.OutputStream.Write([System.Text.Encoding]::UTF8.GetBytes("<html><body><ul>"))
            foreach ($file in $files) {
                $response.OutputStream.Write([System.Text.Encoding]::UTF8.GetBytes("<li><a href='/$($file.FullName.Substring($root.Length).Replace('\', '/'))'>$($file.Name)</a></li>"))
            }
            $response.OutputStream.Write([System.Text.Encoding]::UTF8.GetBytes("</ul></body></html>"))
        } else {
            # 文件内容查看
            $bytes = [System.IO.File]::ReadAllBytes($localPath)
            $response.ContentType = "text/plain"
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
    } else {
        $response.StatusCode = 404
        $response.StatusDescription = "Not Found"
    }
    $response.Close()
}
