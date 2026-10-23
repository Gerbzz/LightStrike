param(
    [Parameter(Mandatory)][string]$Executable,
    [Parameter(Mandatory)][string]$Output
)

$ErrorActionPreference = 'Stop'
$binary = [System.IO.Path]::GetFullPath($Executable)
$directory = [System.IO.Path]::GetFullPath($Output)
New-Item -ItemType Directory -Force -Path $directory | Out-Null
if (!(Test-Path -LiteralPath $binary)) { throw 'The native editor must be built before desktop capture.' }

$start = [System.Diagnostics.ProcessStartInfo]::new($binary)
$start.ArgumentList.Add('--memory')
$start.ArgumentList.Add('--control')
$start.ArgumentList.Add('18940')
$start.UseShellExecute = $false
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
# Let the application's Windows renderer probe DX12, Vulkan and GL in order.
# The public Windows runner has no OpenGL 2.0 context for forced glow.
$start.Environment['LIGHTCRAFT_GPU'] = '0'
$start.Environment['LIGHTCRAFT_NO_PREFS'] = '1'
# Keep fallback warnings observable even if the runner inherited RUST_LOG.
$start.Environment['LIGHTCRAFT_LOG'] = 'info'
$process = [System.Diagnostics.Process]::Start($start)
if ($null -eq $process) { throw 'Windows did not start the photo editor process.' }
$stdout = $process.StandardOutput.ReadToEndAsync()
$stderr = $process.StandardError.ReadToEndAsync()

try {
    $handle = [IntPtr]::Zero
    for ($attempt = 0; $attempt -lt 45; $attempt++) {
        Start-Sleep -Seconds 1
        $process.Refresh()
        if ($process.HasExited) { throw "Editor exited during startup with code $($process.ExitCode)." }
        $handle = $process.MainWindowHandle
        if ($handle -ne [IntPtr]::Zero) { break }
    }
    $status = [ordered]@{
        platform = 'windows-2025'
        process_running = !$process.HasExited
        main_window_handle = $handle.ToInt64()
        render_settled = $false
        capture = 'unavailable'
    }
    $statusPath = Join-Path $directory 'native-status.json'
    if ($handle -eq [IntPtr]::Zero) {
        Write-Warning 'The hosted runner did not expose a desktop window; no native GUI screenshot is claimed.'
        $status | ConvertTo-Json | Set-Content -LiteralPath $statusPath
        return
    }

    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        $process.Refresh()
        if ($process.HasExited) { throw "Editor exited before the photo render settled: $($process.ExitCode)." }
        $client = $null
        try {
            $client = [System.Net.Sockets.TcpClient]::new()
            $client.ReceiveTimeout = 3000
            $client.SendTimeout = 3000
            $client.Connect('127.0.0.1', 18940)
            $stream = $client.GetStream()
            $request = [System.Text.Encoding]::UTF8.GetBytes('{"id":1,"method":"ui.inspect","params":{}}' + "`n")
            $stream.Write($request, 0, $request.Length)
            $reader = [System.IO.StreamReader]::new($stream)
            $response = $reader.ReadLine() | ConvertFrom-Json
            $loupe = $response.result.loupe
            if ($response.ok -and $loupe.source -eq 'render' -and $loupe.pending -eq $false -and !$loupe.failed) {
                $status['render_settled'] = $true
                break
            }
        }
        catch [System.Net.Sockets.SocketException] { }
        catch [System.IO.IOException] { }
        finally { if ($null -ne $client) { $client.Dispose() } }
        Start-Sleep -Seconds 1
    }
    $status | ConvertTo-Json | Set-Content -LiteralPath $statusPath
    if (!$status['render_settled']) { throw 'The native photo render did not settle through ui.inspect.' }

    Add-Type -AssemblyName System.Drawing
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LightStrikeWindowBounds {
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr handle, out Rect rectangle);
}
'@
    $rect = New-Object LightStrikeWindowBounds+Rect
    if (![LightStrikeWindowBounds]::GetWindowRect($handle, [ref]$rect)) { throw 'Could not read native editor bounds.' }
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -lt 400 -or $height -lt 300) { throw "Native editor window is unexpectedly small: ${width}x${height}." }
    $imagePath = Join-Path $directory 'native-editor.png'
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $client.ReceiveTimeout = 15000
        $client.SendTimeout = 3000
        $client.Connect('127.0.0.1', 18940)
        $stream = $client.GetStream()
        $request = @{ id = 2; method = 'ui.screenshot'; params = @{ path = $imagePath; headless = $false } } | ConvertTo-Json -Depth 4 -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($request + "`n")
        $stream.Write($bytes, 0, $bytes.Length)
        $reader = [System.IO.StreamReader]::new($stream)
        $reply = $reader.ReadLine() | ConvertFrom-Json
        $reply | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $directory 'native-screenshot-response.json')
        if ($reply.id -ne 2 -or $reply.ok -ne $true -or !(Test-Path -LiteralPath $imagePath)) { throw 'Native photo-editor screenshot request failed.' }
        if ($reply.result.width -lt 400 -or $reply.result.height -lt 300) { throw 'Native viewport screenshot is unexpectedly small.' }
    }
    finally { $client.Dispose() }
    $process.Refresh()
    if ($process.HasExited) { throw 'Photo editor exited before native screenshot acceptance.' }
    $status['capture'] = 'pending_native_validation'
    $status['window_width'] = $width
    $status['window_height'] = $height
    $status['native_width'] = $reply.result.width
    $status['native_height'] = $reply.result.height
    $status | ConvertTo-Json | Set-Content -LiteralPath $statusPath
}
finally {
    if (!$process.HasExited) { $process.Kill() }
    $process.WaitForExit()
    $outText = $stdout.GetAwaiter().GetResult()
    $errText = $stderr.GetAwaiter().GetResult()
    $outText | Set-Content -LiteralPath (Join-Path $directory 'native-stdout.txt')
    $errText | Set-Content -LiteralPath (Join-Path $directory 'native-stderr.txt')
    $process.Dispose()
}

# LightStrike can silently rasterize a shadow UI after its native compositor times out.
# The logger writes this warning synchronously to stderr before replying. Logs are fully
# drained after process teardown above; never accept that fallback as a native frame.
if (($outText + $errText) -match 'rendering headlessly') {
    if (Test-Path -LiteralPath $imagePath) { Remove-Item -LiteralPath $imagePath -Force }
    $status['capture'] = 'rejected_headless_fallback'
    $status | ConvertTo-Json | Set-Content -LiteralPath $statusPath
    throw 'ui.screenshot rendered headlessly; no native photo-editor screenshot is accepted.'
}
$status['capture'] = 'captured'
$status['capture_method'] = 'native_viewport_screenshot'
$status['headless_fallback_rejected'] = $true
$status | ConvertTo-Json | Set-Content -LiteralPath $statusPath
