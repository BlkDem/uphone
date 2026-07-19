$maksimResp = Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/v1/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"maksim@uphone.local","password":"password"}'
$mToken = $maksimResp.access_token
$mUserId = $maksimResp.user.id

$svetlanaResp = Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/v1/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"svetlana@uphone.local","password":"password"}'
$sToken = $svetlanaResp.access_token
$sUserId = $svetlanaResp.user.id

Write-Host "Maksim: $mUserId"
Write-Host "Svetlana: $sUserId"

# Connect ONLY Svetlana WS
$wsS = New-Object System.Net.WebSockets.ClientWebSocket
$wsS.ConnectAsync((New-Object System.Uri("ws://127.0.0.1:8080/ws?token=$sToken")), [System.Threading.CancellationToken]::None).Wait()
Write-Host "Svetlana WS: $($wsS.State)"

# Connect Maksim WS
$wsM = New-Object System.Net.WebSockets.ClientWebSocket
$wsM.ConnectAsync((New-Object System.Uri("ws://127.0.0.1:8080/ws?token=$mToken")), [System.Threading.CancellationToken]::None).Wait()
Write-Host "Maksim WS: $($wsM.State)"

# IMMEDIATELY send call-request
$callId = "call-ps-test-$(Get-Date -UFormat %s)"
$callRequest = '{"type":"call-request","call_id":"' + $callId + '","to_user":"' + $sUserId + '","payload":{"call_type":"video","chat_id":"test","from_name":"maksim"}}'
$sendBytes = [System.Text.Encoding]::UTF8.GetBytes($callRequest)
$wsM.SendAsync((New-Object System.ArraySegment[byte] -ArgumentList @(,$sendBytes)), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()
Write-Host "call-request sent!"

# IMMEDIATELY read from Svetlana
$found = $false
for ($i = 0; $i -lt 10; $i++) {
    $buf = New-Object byte[] 8192
    $cts = New-Object System.Threading.CancellationTokenSource([TimeSpan]::FromSeconds(3))
    try {
        $res = $wsS.ReceiveAsync((New-Object System.ArraySegment[byte] -ArgumentList @(,$buf)), $cts.Token).Result
        if ($res.Count -gt 0) {
            $msg = [System.Text.Encoding]::UTF8.GetString($buf, 0, $res.Count)
            Write-Host "recv[$i]: $msg"
            if ($msg -match "call-request") { $found = $true; break }
            if ($msg -match "user\.online") { continue }
        } else {
            Write-Host "recv[$i]: (empty type=$($res.MessageType))"
            break
        }
    } catch {
        Write-Host "recv[$i] timeout/error"
        break
    }
}

Write-Host $(if ($found) { "SUCCESS" } else { "FAILED" })

try { $wsM.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "", [System.Threading.CancellationToken]::None).Wait() } catch {}
try { $wsS.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "", [System.Threading.CancellationToken]::None).Wait() } catch {}
