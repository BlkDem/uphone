$svetlanaResp = Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/v1/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"svetlana@uphone.local","password":"password"}'
$sToken = $svetlanaResp.access_token
$maksimResp = Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/v1/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"maksim@uphone.local","password":"password"}'
$mToken = $maksimResp.access_token
Write-Host "Tokens OK"

$chatId = "bd0c80e9-ebc1-4315-afcf-8910b4adf767"

# Connect Svetlana WS
$ws = New-Object System.Net.WebSockets.ClientWebSocket
$uri = New-Object System.Uri("ws://127.0.0.1:8080/ws?token=$sToken")
$ws.ConnectAsync($uri, [System.Threading.CancellationToken]::None).Wait()
Write-Host "Svetlana WS: $($ws.State)"

# IMMEDIATELY send HTTP message as Maksim (no delay!)
Write-Host "Sending HTTP message NOW..."
$httpResp = Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/v1/chats/$chatId/messages" -Method POST -ContentType "application/json" -Body '{"content":"Test message from PS!"}' -Headers @{Authorization="Bearer $mToken"}
Write-Host "Sent msg ID: $($httpResp.id)"

# Read Svetlana WS - up to 10 attempts
$found = $false
for ($i = 0; $i -lt 10; $i++) {
    $buf = New-Object byte[] 8192
    $cts = New-Object System.Threading.CancellationTokenSource([TimeSpan]::FromSeconds(3))
    try {
        $res = $ws.ReceiveAsync((New-Object System.ArraySegment[byte] -ArgumentList @(,$buf)), $cts.Token).Result
        if ($res.Count -gt 0) {
            $msg = [System.Text.Encoding]::UTF8.GetString($buf, 0, $res.Count)
            Write-Host "recv[$i]: $msg"
            if ($msg -match "message\.new") {
                $found = $true
                break
            }
        } else {
            Write-Host "recv[$i]: (empty, type=$($res.MessageType))"
            if ($res.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                Write-Host "Connection CLOSED by remote"
                break
            }
        }
    } catch {
        Write-Host "recv[$i] error: $($_.Exception.InnerException.Message)"
        break
    }
}

Write-Host $(if ($found) { "SUCCESS" } else { "FAILED" })

try { $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "done", [System.Threading.CancellationToken]::None).Wait() } catch {}
