$logPath = "C:\Users\HP\.gemini\antigravity\brain\d1aab8f5-8e8f-4fb5-8486-488d41865a3a\.system_generated\logs\overview.txt"
$content = Get-Content $logPath -Raw

$blocks = $content -split "File Path: ``file:///d:/xmechat/lib/screens/chat/private_chat_screen.dart``"
$recovered = $false

for ($i = $blocks.Count - 1; $i -ge 0; $i--) {
    $b = $blocks[$i]
    if ($b -match "Total Lines: 905") {
        $lines = $b -split "`n"
        $codeLines = @()
        $capture = $false
        foreach ($line in $lines) {
            $line = $line.TrimEnd("`r")
            if ($line -match "The following code has been modified") {
                $capture = $true
                continue
            }
            if ($capture) {
                if ($line -match "The above content" -or $line -match "```") {
                    break
                }
                if ($line -match "^(\d+):\s(.*)$") {
                    $codeLines += $Matches[2]
                } elseif ($line -match "^(\d+):$") {
                    $codeLines += ""
                }
            }
        }
        
        if ($codeLines.Count -gt 0) {
            $codeLines | Out-File -FilePath "recovered.dart" -Encoding utf8
            Write-Host "Recovered $($codeLines.Count) lines!"
            $recovered = $true
            break
        }
    }
}
if (-not $recovered) { Write-Host "Not found" }
