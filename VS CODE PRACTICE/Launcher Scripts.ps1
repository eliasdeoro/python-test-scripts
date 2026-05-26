# =====================================================================
# Workspace Launcher  -  Dual-monitor setup
# ---------------------------------------------------------------------
# Layout:
#   Left monitor   :  Claude Code  (centered, ~75% of screen)
#   Right monitor  :  VS Code (left half)  +  Git Bash (right half)
#
# How to run:
#   Right-click the file -> "Run with PowerShell"
#   OR from a terminal:
#     powershell -ExecutionPolicy Bypass -File .\workspace.ps1
# =====================================================================


# =====================  EDIT THESE FOR YOUR SETUP  ===================

# --- Monitor geometry ---
# In Windows, the PRIMARY monitor starts at (0,0).
# If your left monitor sits to the LEFT of your primary, its X is NEGATIVE.
# Adjust widths/heights to match your actual resolutions.
$LeftMonWidth   = 1200
$LeftMonHeight  = 1920
$LeftMonX       = -1200          # = -(width of left monitor) if it's directly left of primary
$LeftMonY       = 0

$RightMonWidth  = 2560           # this is your PRIMARY (right) monitor
$RightMonHeight = 1440
$RightMonX      = 0
$RightMonY      = 0

# --- App paths / commands ---
# Claude Code: launched in Windows Terminal. Change the command if you
# normally start Claude Code from Git Bash, WSL, cmd, etc.
$WindowsTerminal = "wt.exe"
$ClaudeCommand   = "powershell -NoExit -Command claude"

$GitBashPath = "C:\Program Files\Git\git-bash.exe"
$VSCodePath  = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"

# --- Sizing ---
$ClaudeCoveragePct = 0.78        # ~78% of the left monitor
# =====================================================================


# ---- Win32 API for moving windows ----
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@

# Wait until a process exposes a real main window, then return its handle.
function Wait-MainWindow {
    param([System.Diagnostics.Process]$Process, [int]$TimeoutSec = 20)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try { $Process.Refresh() } catch { return [IntPtr]::Zero }
        if ($Process.HasExited) { break }
        if ($Process.MainWindowHandle -ne [IntPtr]::Zero) {
            return $Process.MainWindowHandle
        }
        Start-Sleep -Milliseconds 250
    }
    return [IntPtr]::Zero
}

# Fallback: find the newest top-level visible window whose title contains $Match.
function Find-WindowByTitle {
    param([string]$Match, [int]$TimeoutSec = 15)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $found = [IntPtr]::Zero
        $cb = [Win32+EnumWindowsProc]{
            param($h, $l)
            if ([Win32]::IsWindowVisible($h)) {
                $sb = New-Object System.Text.StringBuilder 512
                [Win32]::GetWindowText($h, $sb, $sb.Capacity) | Out-Null
                if ($sb.ToString() -like "*$Match*") {
                    $script:found = $h
                    return $false
                }
            }
            return $true
        }
        [Win32]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
        if ($script:found -ne [IntPtr]::Zero) { return $script:found }
        Start-Sleep -Milliseconds 300
    }
    return [IntPtr]::Zero
}

function Move-To {
    param([IntPtr]$Handle, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Label)
    if ($Handle -eq [IntPtr]::Zero) {
        Write-Host "  [warn] Could not get window handle for $Label" -ForegroundColor Yellow
        return
    }
    [Win32]::ShowWindow($Handle, 9) | Out-Null  # SW_RESTORE (un-maximize first)
    Start-Sleep -Milliseconds 250
    [Win32]::MoveWindow($Handle, $X, $Y, $W, $H, $true) | Out-Null
    Write-Host "  [ok]   Positioned $Label at ($X, $Y)  ${W}x${H}" -ForegroundColor Green
}


# =================  1. Claude Code on LEFT monitor  ==================
Write-Host "Launching Claude Code..."
$claudeW = [int]($LeftMonWidth  * $ClaudeCoveragePct)
$claudeH = [int]($LeftMonHeight * $ClaudeCoveragePct)
$claudeX = $LeftMonX + [int](($LeftMonWidth  - $claudeW) / 2)
$claudeY = $LeftMonY + [int](($LeftMonHeight - $claudeH) / 2)

# wt.exe spawns a host process; the visible window may belong to a different
# pid, so fall back to finding it by title.
Start-Process -FilePath $WindowsTerminal -ArgumentList $ClaudeCommand | Out-Null
$h = Find-WindowByTitle "Terminal" 15
Move-To $h $claudeX $claudeY $claudeW $claudeH "Claude Code"


# ==============  2. VS Code on LEFT HALF of right monitor  ============
Write-Host "Launching VS Code..."
$vsW = [int]($RightMonWidth / 2)
$vsH = $RightMonHeight
$vsX = $RightMonX
$vsY = $RightMonY

$p = Start-Process -FilePath $VSCodePath -ArgumentList "--new-window" -PassThru
$h = Wait-MainWindow $p 20
if ($h -eq [IntPtr]::Zero) { $h = Find-WindowByTitle "Visual Studio Code" 10 }
Move-To $h $vsX $vsY $vsW $vsH "VS Code"


# ==============  3. Git Bash on RIGHT HALF of right monitor  ==========
Write-Host "Launching Git Bash..."
$gbW = [int]($RightMonWidth / 8)
$gbH = $RightMonHeight
$gbX = $RightMonX + [int]($RightMonWidth / 8)
$gbY = $RightMonY

$p = Start-Process -FilePath $GitBashPath -PassThru
$h = Wait-MainWindow $p 15
if ($h -eq [IntPtr]::Zero) { $h = Find-WindowByTitle "MINGW" 10 }
Move-To $h $gbX $gbY $gbW $gbH "Git Bash"


Write-Host "`nWorkspace ready." -ForegroundColor Cyan