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
$start.Environment['LIGHTCRAFT_GPU_BACKEND'] = 'glow'
$start.Environment['LIGHTCRAFT_GPU'] = '0'
$start.Environment['LIGHTCRAFT_NO_PREFS'] = '1'
$process = [System.Diagnostics.Process]::Start($start)
if ($null -eq $process) { throw 'Windows did not start the photo editor process.' }

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
    $bitmap = [System.Drawing.Bitmap]::new($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
        $bitmap.Save((Join-Path $directory 'native-editor.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
    $status['capture'] = 'captured'
    $status['window_width'] = $width
    $status['window_height'] = $height
    $status | ConvertTo-Json | Set-Content -LiteralPath $statusPath
}
finally {
    if (!$process.HasExited) { $process.Kill() }
    $process.Dispose()
}
