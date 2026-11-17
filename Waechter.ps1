# Waechter - Left 4 Dead 2: official Valve servers only
# WAECHTER-APP
# Requires the Steam launch option:  -netconport 2121
param([switch]$Tray, [string]$Join = "")
$StartInTray = [bool]$Tray
$JoinArg = [string]$Join
$AppVersion = "1.1.0"
$UpdateRepo = "voenji/waechter"   # GitHub "user/repo" that hosts version.txt and Waechter.ps1 (empty = no updates)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http
[System.Windows.Forms.Application]::EnableVisualStyles()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Port      = 2121
$Relay     = "https://ntfy.sh"
$Here      = Split-Path -Parent $MyInvocation.MyCommand.Path
$Blacklist = Join-Path $Here "blacklist.txt"
$LogFile   = Join-Path $Here "waechter_log.txt"
$IconFile  = Join-Path $Here "waechter.ico"
$Settings  = Join-Path $Here "settings.json"
if (-not (Test-Path $Blacklist)) { New-Item -ItemType File -Path $Blacklist | Out-Null }
$PendingFile = Join-Path $Here "pending.txt"

# only one Waechter at a time - a second start hands its request to the running one
$createdNew = $false
try { $script:mutex = [System.Threading.Mutex]::new($true, "Local\WaechterL4D2App", [ref]$createdNew) } catch { $createdNew = $true }
if (-not $createdNew) {
    $req = "show"
    if ($JoinArg -match '([A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4})') { $req = "join " + $matches[1].ToUpper() }
    try { Set-Content -Path $PendingFile -Value $req } catch { }
    exit
}

# ---------------- updater: fetch a newer version from GitHub, then restart ----------------
$script:updateNote = ""
if ($UpdateRepo) {
    try {
        Add-Type -AssemblyName System.Net.Http
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $uc = New-Object System.Net.Http.HttpClient
        $uc.Timeout = [TimeSpan]::FromSeconds(6)
        $base = "https://raw.githubusercontent.com/$UpdateRepo/main"
        $nc = "?t=" + [DateTime]::UtcNow.Ticks
        $remote = ($uc.GetStringAsync("$base/version.txt$nc").Result).Trim()
        if ($remote -match '^\d+(\.\d+){1,3}$' -and ([version]$remote -gt [version]$AppVersion)) {
            $updCode = $uc.GetStringAsync("$base/Waechter.ps1$nc").Result
            $updCode = $updCode.TrimStart([char]0xFEFF)
            if ($updCode -match '# WAECHTER-APP' -and $updCode.Length -gt 20000) {
                $self = Join-Path $Here "Waechter.ps1"
                Copy-Item $self (Join-Path $Here "Waechter_previous.ps1") -Force
                [System.IO.File]::WriteAllText($self, $updCode, (New-Object System.Text.UTF8Encoding($true)))
                try { $script:mutex.ReleaseMutex(); $script:mutex.Dispose() } catch { }
                $updArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$self`"")
                if ($StartInTray) { $updArgs += "-Tray" }
                if ($JoinArg) { $updArgs += @("-Join", "`"$JoinArg`"") }
                Start-Process "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $updArgs -WindowStyle Hidden
                exit
            }
        }
    } catch { $script:updateNote = "Could not check for updates" }
}

# (re)create the desktop shortcut the official Windows way
try {
    $DeskLnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "Waechter.lnk"
    $shDesk = New-Object -ComObject WScript.Shell
    $lnkDesk = $shDesk.CreateShortcut($DeskLnk)
    $lnkDesk.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $lnkDesk.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Here\Waechter.ps1`""
    $lnkDesk.WorkingDirectory = $Here
    $lnkDesk.WindowStyle = 7
    $lnkDesk.IconLocation = "$Here\waechter_door.ico,0"
    $lnkDesk.Description = "Waechter - L4D2 official Valve servers only"
    $lnkDesk.Save()
} catch { }

# register waechter:// links (current user only, no admin needed)
try {
    $cmd = "`"$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Here\Waechter.ps1`" -Join `"%1`""
    $rk = "HKCU:\Software\Classes\waechter"
    New-Item -Path "$rk\shell\open\command" -Force | Out-Null
    Set-ItemProperty -Path $rk -Name "(default)" -Value "URL:Waechter Protocol"
    Set-ItemProperty -Path $rk -Name "URL Protocol" -Value ""
    Set-ItemProperty -Path "$rk\shell\open\command" -Name "(default)" -Value $cmd
} catch { }

# ---------------- colours ----------------
function C($r, $g, $b, $a = 255) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
$cBg      = C 30 31 34      # matte dark grey
$cCard    = C 40 42 46
$cInput   = C 52 54 59
$cText      = C 229 231 235
$cMuted   = C 148 153 163
$cGlassA  = C 34 64 120     # glass gradient top
$cGlassB  = C 15 28 58      # glass gradient bottom
$cGlassLn = C 96 145 225
$cAccent  = C 59 130 246
$cGreen   = C 74 222 128
$cRed     = C 248 113 113
$cYellow  = C 250 204 21

$fMain  = New-Object System.Drawing.Font("Segoe UI", 10)
$fSmall = New-Object System.Drawing.Font("Segoe UI", 9)
$fHead  = New-Object System.Drawing.Font("Segoe UI Semibold", 11)
$fTitle = New-Object System.Drawing.Font("Segoe UI Semibold", 20)
$fStat  = New-Object System.Drawing.Font("Segoe UI Semibold", 14)
$fDot   = New-Object System.Drawing.Font("Segoe UI", 22)
$fMono  = New-Object System.Drawing.Font("Consolas", 9)
$fCode  = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)

# ---------------- settings ----------------
$cfg = @{ id = ""; name = ""; party = ""; host = $false; sound = $true; overlay = $false; ox = -1; oy = -1; vol = 70; recent = @() }
if (Test-Path $Settings) {
    try { $j = Get-Content $Settings -Raw | ConvertFrom-Json; foreach ($k in @('id','name','party','host','sound','overlay','ox','oy','vol','recent')) { if ($j.$k -ne $null) { $cfg[$k] = $j.$k } } } catch { }
}
if (-not $cfg.id) { $cfg.id = ([guid]::NewGuid().ToString("N")).Substring(0, 12) }
function Add-Recent($code) {
    $list = @(@($cfg.recent) | Where-Object { $_ -and $_ -ne $code })
    $cfg.recent = @(@($code) + $list | Select-Object -First 6)
}
function Save-Settings { ($cfg | ConvertTo-Json) | Set-Content -Path $Settings -Encoding UTF8 }

function Get-SteamName {
    try {
        $n = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "LastGameNameUsed" -ErrorAction Stop).LastGameNameUsed
        if ($n) { return $n }
    } catch { }
    return $null
}
$steamName = Get-SteamName
if (-not $cfg.name) { $cfg.name = if ($steamName) { $steamName } else { $env:USERNAME } }
Save-Settings

# ---------------- global hotkeys ----------------
$script:hk = $null
try {
    Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class WaechterHotkeys : NativeWindow {
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, uint mod, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    public Queue<int> Hits = new Queue<int>();
    private List<int> ids = new List<int>();
    public WaechterHotkeys() { CreateHandle(new CreateParams()); }
    public bool Add(int id, uint mod, uint vk) { bool ok = RegisterHotKey(Handle, id, mod, vk); if (ok) ids.Add(id); return ok; }
    protected override void WndProc(ref Message m) { if (m.Msg == 0x0312) Hits.Enqueue(m.WParam.ToInt32()); base.WndProc(ref m); }
    public void Release() { foreach (int i in ids) UnregisterHotKey(Handle, i); ids.Clear(); DestroyHandle(); }
}
"@
    $script:hk = New-Object WaechterHotkeys
} catch { $script:hk = $null }

# ---------------- sounds ----------------
$SoundDir = Join-Path $Here "sounds"
$snd = @{}
function Get-ScaledWav([byte[]]$bytes, [double]$vol) {
    $out = [byte[]]$bytes.Clone()
    $pos = 12
    while ($pos + 8 -le $out.Length) {
        $id = [System.Text.Encoding]::ASCII.GetString($out, $pos, 4)
        $size = [BitConverter]::ToInt32($out, $pos + 4)
        if ($id -eq "data") {
            $len = [Math]::Min($size, $out.Length - $pos - 8) - ([Math]::Min($size, $out.Length - $pos - 8) % 2)
            $smp = New-Object int16[] ($len / 2)
            [Buffer]::BlockCopy($out, $pos + 8, $smp, 0, $len)
            for ($i = 0; $i -lt $smp.Length; $i++) { $smp[$i] = [int16]([Math]::Round($smp[$i] * $vol)) }
            [Buffer]::BlockCopy($smp, 0, $out, $pos + 8, $len)
            break
        }
        $pos += 8 + $size + ($size % 2)
    }
    return ,$out
}
function Load-Sounds {
    $vol = [Math]::Max(0, [Math]::Min(100, [int]$cfg.vol)) / 100.0
    foreach ($n in @('hover','click','official','kicked','party')) {
        $p = Join-Path $SoundDir "$n.wav"
        if (-not (Test-Path $p)) { continue }
        try {
            $data = Get-ScaledWav ([System.IO.File]::ReadAllBytes($p)) $vol
            $sp = New-Object System.Media.SoundPlayer((New-Object System.IO.MemoryStream(,$data)))
            $sp.Load(); $snd[$n] = $sp
        } catch { }
    }
}
Load-Sounds
$script:lastEventSound = [DateTime]::MinValue
$script:memberSnd = @{}  # cache
$PersonColors = @((C 253 186 116), (C 134 239 172), (C 249 168 212), (C 196 181 253), (C 103 232 249), (C 253 224 71), (C 252 165 165), (C 165 243 252), (C 190 242 100))
function Get-Seed($id) { $seed = 0; foreach ($ch in ([string]$id).ToCharArray()) { $seed = ($seed * 31 + [int]$ch) % 100003 }; return $seed }
function Get-PersonColor($id) { return $PersonColors[(Get-Seed $id) % $PersonColors.Count] }
function New-BlipWav([int]$seed) {
    $sr = 44100
    $f1 = 520 + ($seed % 9) * 70
    $notes = @(@($f1, 0.07), @(($f1 * 1.5), 0.13))
    $vol = [Math]::Max(0, [Math]::Min(100, [int]$cfg.vol)) / 100.0
    $samples = New-Object System.Collections.Generic.List[int16]
    foreach ($nt in $notes) {
        $n = [int]($sr * $nt[1])
        for ($i = 0; $i -lt $n; $i++) {
            $t = $i / $sr
            $env = [Math]::Exp(-$t / 0.05) * [Math]::Min(1.0, $t / 0.003)
            $v = 0.30 * $vol * $env * ([Math]::Sin(2 * [Math]::PI * $nt[0] * $t) + 0.25 * [Math]::Sin(4 * [Math]::PI * $nt[0] * $t))
            $samples.Add([int16]([Math]::Round([Math]::Max(-1.0, [Math]::Min(1.0, $v)) * 32000)))
        }
    }
    $dataLen = $samples.Count * 2
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF")); $bw.Write([int](36 + $dataLen))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVEfmt ")); $bw.Write([int]16)
    $bw.Write([int16]1); $bw.Write([int16]1); $bw.Write([int]$sr); $bw.Write([int]($sr * 2)); $bw.Write([int16]2); $bw.Write([int16]16)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data")); $bw.Write([int]$dataLen)
    foreach ($x in $samples) { $bw.Write($x) }
    $bw.Flush(); $ms.Position = 0
    return $ms
}
function Play-Member($id) {
    if ($script:replay) { return }
    if (-not $cfg.sound -or [int]$cfg.vol -le 0) { return }
    try {
        if (-not $script:memberSnd.ContainsKey($id)) {
            $sp = New-Object System.Media.SoundPlayer((New-BlipWav (Get-Seed $id))); $sp.Load()
            $script:memberSnd[$id] = $sp
        }
        $script:lastEventSound = Get-Date
        $script:memberSnd[$id].Play()
    } catch { }
}
function Play($n) {
    if ($script:replay) { return }
    if (-not $cfg.sound -or [int]$cfg.vol -le 0 -or -not $snd.ContainsKey($n)) { return }
    $isUi = ($n -eq 'hover' -or $n -eq 'click')
    if ($isUi -and ((Get-Date) - $script:lastEventSound).TotalMilliseconds -lt 1500) { return }   # don't cut event sounds
    if (-not $isUi) { $script:lastEventSound = Get-Date }
    try { $snd[$n].Play() } catch { }
}

# ---------------- UI helpers ----------------
function Set-Round($ctrl, $r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $w = $ctrl.Width; $h = $ctrl.Height; $d = $r * 2
    $p.AddArc(0, 0, $d, $d, 180, 90); $p.AddArc($w - $d, 0, $d, $d, 270, 90)
    $p.AddArc($w - $d, $h - $d, $d, $d, 0, 90); $p.AddArc(0, $h - $d, $d, $d, 90, 90); $p.CloseFigure()
    $ctrl.Region = New-Object System.Drawing.Region($p)
}
function New-Glass($x, $y, $w, $h) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = New-Object System.Drawing.Point($x, $y); $p.Size = New-Object System.Drawing.Size($w, $h)
    $p.BackColor = $cGlassB
    $p.Add_Paint({
        param($s, $e)
        $r = New-Object System.Drawing.Rectangle(0, 0, $s.Width, $s.Height)
        $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($r, $cGlassA, $cGlassB, 90)
        $e.Graphics.FillRectangle($br, $r)
        $hl = New-Object System.Drawing.SolidBrush((C 255 255 255 18))
        $e.Graphics.FillRectangle($hl, 0, 0, $s.Width, [int]($s.Height * 0.42))
        $pen = New-Object System.Drawing.Pen((C 120 165 240 160), 2)
        $e.Graphics.DrawLine($pen, 14, 1, $s.Width - 14, 1)
    })
    Set-Round $p 14
    return $p
}
function New-Card($x, $y, $w, $h) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = New-Object System.Drawing.Point($x, $y); $p.Size = New-Object System.Drawing.Size($w, $h)
    $p.BackColor = $cCard
    Set-Round $p 14
    return $p
}
function New-Label($text, $x, $y, $w, $h, $font, $color) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, $h)
    $l.Font = $font; $l.ForeColor = $color; $l.BackColor = [System.Drawing.Color]::Transparent
    return $l
}
function New-Button($text, $x, $y, $w, $accent = $false) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($w, 32)
    $b.FlatStyle = "Flat"; $b.FlatAppearance.BorderSize = 0
    $b.BackColor = if ($accent) { $cAccent } else { $cInput }
    $b.ForeColor = $cText; $b.Font = $fSmall
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.Add_MouseEnter({ Play 'hover' })
    $b.Add_MouseDown({ Play 'click' })
    Set-Round $b 8
    return $b
}
function New-Input($x, $y, $w) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x, $y); $t.Size = New-Object System.Drawing.Size($w, 28)
    $t.BackColor = $cInput; $t.ForeColor = $cText; $t.BorderStyle = "FixedSingle"; $t.Font = $fMain
    return $t
}

# ---------------- window ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Waechter"
$form.ClientSize = New-Object System.Drawing.Size(900, 772)
$form.BackColor = $cBg; $form.ForeColor = $cText; $form.Font = $fMain
$form.FormBorderStyle = "FixedSingle"; $form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"; $form.Opacity = 0.97
if (Test-Path $IconFile) { $form.Icon = New-Object System.Drawing.Icon($IconFile) }

if (Test-Path $IconFile) {
    $pic = New-Object System.Windows.Forms.PictureBox
    $pic.Location = New-Object System.Drawing.Point(20, 16); $pic.Size = New-Object System.Drawing.Size(44, 44)
    $pic.SizeMode = "Zoom"; $LogoPng = Join-Path $Here "waechter_logo.png"; if (Test-Path $LogoPng) { $pic.Image = [System.Drawing.Image]::FromFile($LogoPng) }
    $form.Controls.Add($pic)
}
$form.Controls.Add((New-Label "WAECHTER" 72 12 300 38 $fTitle $cText))
$form.Controls.Add((New-Label "Left 4 Dead 2  -  official Valve servers only" 74 48 400 20 $fSmall $cMuted))
$lblSteam = New-Label "" 300 22 290 20 $fSmall $cMuted
$lblSteam.TextAlign = "MiddleRight"
$form.Controls.Add($lblSteam)
$chkActive = New-Object System.Windows.Forms.CheckBox
$chkActive.Text = "Active"; $chkActive.Checked = $true
$chkActive.Location = New-Object System.Drawing.Point(790, 20); $chkActive.Size = New-Object System.Drawing.Size(90, 24)
$chkActive.ForeColor = $cText
$form.Controls.Add($chkActive)
$chkSound = New-Object System.Windows.Forms.CheckBox
$chkSound.Text = "Sounds"; $chkSound.Checked = [bool]$cfg.sound
$chkSound.Location = New-Object System.Drawing.Point(700, 20); $chkSound.Size = New-Object System.Drawing.Size(85, 24)
$chkSound.ForeColor = $cText
$form.Controls.Add($chkSound)
$chkOverlay = New-Object System.Windows.Forms.CheckBox
$chkOverlay.Text = "Overlay"; $chkOverlay.Checked = [bool]$cfg.overlay
$chkOverlay.Location = New-Object System.Drawing.Point(605, 20); $chkOverlay.Size = New-Object System.Drawing.Size(90, 24)
$chkOverlay.ForeColor = $cText
$form.Controls.Add($chkOverlay)
$StartupLnk = Join-Path ([Environment]::GetFolderPath("Startup")) "Waechter.lnk"
$chkAuto = New-Object System.Windows.Forms.CheckBox
$chkAuto.Text = "Start with Windows"; $chkAuto.Checked = (Test-Path $StartupLnk)
$chkAuto.Size = New-Object System.Drawing.Size(160, 22)
$chkAuto.ForeColor = $cMuted; $chkAuto.Font = $fSmall
$form.Controls.Add((New-Label "Volume" 605 52 60 18 $fSmall $cMuted))
$trkVol = New-Object System.Windows.Forms.TrackBar
$trkVol.AutoSize = $false; $trkVol.Location = New-Object System.Drawing.Point(665, 48); $trkVol.Size = New-Object System.Drawing.Size(215, 26)
$trkVol.Minimum = 0; $trkVol.Maximum = 100; $trkVol.TickStyle = "None"; $trkVol.BackColor = $cBg
$trkVol.Value = [Math]::Max(0, [Math]::Min(100, [int]$cfg.vol))
$form.Controls.Add($trkVol)
foreach ($cb in @($chkActive, $chkSound, $chkOverlay, $chkAuto)) { $cb.Add_MouseEnter({ Play 'hover' }); $cb.Add_MouseDown({ Play 'click' }) }

# --- left column: status (glass) ---
$gStatus = New-Glass 20 80 420 110
$form.Controls.Add($gStatus)
$lblDot    = New-Label ([string][char]0x25CF) 14 26 40 44 $fDot $cYellow
$lblStatus = New-Label "Waiting for L4D2 ..." 58 22 350 28 $fStat $cText
$lblServer = New-Label "Launch option -netconport 2121 required" 60 56 232 44 $fSmall (C 191 210 240)
$lblTimer = New-Label "" 300 8 108 18 $fSmall (C 191 210 240)
$lblTimer.TextAlign = "MiddleRight"
$btnQueue = New-Button "QUEUE" 300 62 108 $true
$btnQueue.Size = New-Object System.Drawing.Size(108, 36); $btnQueue.Font = $fHead; Set-Round $btnQueue 8
$gStatus.Controls.AddRange(@($lblDot, $lblStatus, $lblServer, $lblTimer, $btnQueue))
$lblStats = New-Label "Checked 0   |   Official 0   |   Blocked 0" 22 196 420 20 $fSmall $cMuted
$form.Controls.Add($lblStats)

# --- left column: party (glass) ---
$gParty = New-Glass 20 224 420 376
$form.Controls.Add($gParty)
$gParty.Controls.Add((New-Label "PARTY" 16 12 200 22 $fHead $cText))
$lblPartyState = New-Label "Not in a party" 130 14 274 20 $fSmall (C 191 210 240)
$lblPartyState.TextAlign = "MiddleRight"
$gParty.Controls.Add($lblPartyState)

$gParty.Controls.Add((New-Label "Name" 16 44 60 20 $fSmall (C 191 210 240)))
$txtName = New-Input 16 64 250
$txtName.Text = $cfg.name
$gParty.Controls.Add($txtName)
$btnSteam = New-Button "Use Steam name" 274 62 130
$gParty.Controls.Add($btnSteam)

$btnCreate = New-Button "Create party" 16 104 130 $true
$txtCode   = New-Object System.Windows.Forms.ComboBox
$txtCode.Location = New-Object System.Drawing.Point(156, 106); $txtCode.Size = New-Object System.Drawing.Size(150, 28)
$txtCode.DropDownStyle = "DropDown"; $txtCode.FlatStyle = "Flat"
$txtCode.BackColor = $cInput; $txtCode.ForeColor = $cText; $txtCode.Font = $fMain
function Refresh-Recent {
    $txtCode.Items.Clear()
    foreach ($r in @($cfg.recent)) { if ($r) { [void]$txtCode.Items.Add([string]$r) } }
}
$btnJoin   = New-Button "Join" 314 104 90
$gParty.Controls.AddRange(@($btnCreate, $txtCode, $btnJoin))

$lblCodeT = New-Label "Party code" 16 146 100 20 $fSmall (C 191 210 240)
$lblCode  = New-Label "-" 16 166 150 26 $fCode $cText
$btnReady = New-Button "Ready" 168 162 76
$btnCopy  = New-Button "Invite" 250 162 70
$btnLeave = New-Button "Leave" 326 162 78
$gParty.Controls.AddRange(@($lblCodeT, $lblCode, $btnReady, $btnCopy, $btnLeave))

$lvParty = New-Object System.Windows.Forms.ListView
$lvParty.Location = New-Object System.Drawing.Point(16, 204); $lvParty.Size = New-Object System.Drawing.Size(388, 128)
$lvParty.View = "Details"; $lvParty.FullRowSelect = $true; $lvParty.HeaderStyle = "None"
$lvParty.BackColor = $cGlassB; $lvParty.ForeColor = $cText; $lvParty.BorderStyle = "None"; $lvParty.Font = $fSmall
[void]$lvParty.Columns.Add("Name", 135); [void]$lvParty.Columns.Add("Role", 45); [void]$lvParty.Columns.Add("Ready", 55); [void]$lvParty.Columns.Add("Status", 150)
$gParty.Controls.Add($lvParty)
$chkRoom = New-Object System.Windows.Forms.CheckBox
$chkRoom.Text = "Host: only stay on servers with room for the whole party"
$chkRoom.Checked = $true
$chkRoom.Location = New-Object System.Drawing.Point(16, 342); $chkRoom.Size = New-Object System.Drawing.Size(390, 24)
$chkRoom.ForeColor = (C 191 210 240); $chkRoom.BackColor = $cGlassB; $chkRoom.Font = $fSmall
$gParty.Controls.Add($chkRoom)

# --- right column: activity + blacklist (matte grey) ---
$cLog = New-Card 460 80 420 300
$form.Controls.Add($cLog)
$cLog.Controls.Add((New-Label "ACTIVITY" 16 12 200 22 $fHead $cText))
$chkAuto.Location = New-Object System.Drawing.Point(250, 11); $chkAuto.BackColor = $cCard
$cLog.Controls.Add($chkAuto)
$log = New-Object System.Windows.Forms.RichTextBox
$log.Location = New-Object System.Drawing.Point(16, 40); $log.Size = New-Object System.Drawing.Size(388, 246)
$log.BackColor = $cCard; $log.ForeColor = $cText; $log.Font = $fMono
$log.ReadOnly = $true; $log.BorderStyle = "None"; $log.ScrollBars = "Vertical"
$cLog.Controls.Add($log)

$cBlack = New-Card 460 392 420 208
$form.Controls.Add($cBlack)
$cBlack.Controls.Add((New-Label "BLACKLIST" 16 12 200 22 $fHead $cText))
$lstBlack = New-Object System.Windows.Forms.ListBox
$lstBlack.Location = New-Object System.Drawing.Point(16, 40); $lstBlack.Size = New-Object System.Drawing.Size(388, 112)
$lstBlack.BackColor = $cCard; $lstBlack.ForeColor = $cText; $lstBlack.Font = $fMono; $lstBlack.BorderStyle = "None"
$cBlack.Controls.Add($lstBlack)
$btnRemove = New-Button "Remove selected" 16 162 140
$btnClear  = New-Button "Clear all" 164 162 100
$btnFolder = New-Button "Open folder" 272 162 132
$cBlack.Controls.AddRange(@($btnRemove, $btnClear, $btnFolder))

# --- bottom: party chat (glass) ---
$gChat = New-Glass 20 612 860 144
$form.Controls.Add($gChat)
$gChat.Controls.Add((New-Label "PARTY CHAT" 16 10 200 22 $fHead $cText))
$chat = New-Object System.Windows.Forms.RichTextBox
$chat.Location = New-Object System.Drawing.Point(16, 36); $chat.Size = New-Object System.Drawing.Size(828, 62)
$chat.BackColor = $cGlassB; $chat.ForeColor = $cText; $chat.Font = $fSmall
$chat.ReadOnly = $true; $chat.BorderStyle = "None"; $chat.ScrollBars = "Vertical"
$fChat = New-Object System.Drawing.Font("Segoe UI", 9)
$fEmojiChat = New-Object System.Drawing.Font("Segoe UI Emoji", 9)
$chat.Font = $fChat
$gChat.Controls.Add($chat)
$txtChat = New-Input 16 106 300
$txtChat.MaxLength = 200
$btnCd = New-Button "Countdown" 322 104 80
$btnQ1 = New-Button "Queue now" 408 104 100
$btnQ2 = New-Button "2 min" 514 104 70
$btnQ3 = New-Button "brb" 590 104 66
$btnQ4 = New-Button "gg" 662 104 66
$btnSend = New-Button "Send" 744 104 100 $true
$gChat.Controls.AddRange(@($txtChat, $btnCd, $btnQ1, $btnQ2, $btnQ3, $btnQ4, $btnSend))
$Reacts = @([char]::ConvertFromUtf32(0x1F44D), [char]::ConvertFromUtf32(0x1F602), [char]::ConvertFromUtf32(0x1F525), [char]::ConvertFromUtf32(0x2757))
$fEmoji = New-Object System.Drawing.Font("Segoe UI Emoji", 11)
$rx = 640
$reactBtns = @()
foreach ($r in $Reacts) {
    $rb = New-Button $r $rx 6 46
    $rb.Size = New-Object System.Drawing.Size(46, 26); $rb.Font = $fEmoji; $rb.Tag = $r
    Set-Round $rb 8
    $gChat.Controls.Add($rb); $reactBtns += $rb; $rx += 52
}
$tips = New-Object System.Windows.Forms.ToolTip
$tips.SetToolTip($btnQ1, "Hotkey: Ctrl+Shift+1 (works in game)")
$tips.SetToolTip($btnQ2, "Hotkey: Ctrl+Shift+2")
$tips.SetToolTip($btnQ3, "Hotkey: Ctrl+Shift+3")
$tips.SetToolTip($btnQ4, "Hotkey: Ctrl+Shift+4")
$tips.SetToolTip($btnReady, "Hotkey: Ctrl+Shift+R")
$tips.SetToolTip($btnQueue, "Find a running official Valve versus game (2+ players, room for your party) and connect everyone - no lobby needed")
$tips.SetToolTip($btnCd, "10 second queue countdown for the whole party - Hotkey: Ctrl+Shift+5")

# ---------------- mini overlay ----------------
$script:ovText = "Waiting for L4D2 ..."; $script:ovColor = $cYellow; $script:partySummary = ""; $script:timerText = ""
$ov = New-Object System.Windows.Forms.Form
$ov.FormBorderStyle = "None"; $ov.ShowInTaskbar = $false; $ov.TopMost = $true
$ov.StartPosition = "Manual"; $ov.Size = New-Object System.Drawing.Size(270, 46)
$ov.BackColor = $cGlassB; $ov.Opacity = 0.88
$scr = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
if ($cfg.ox -lt 0) { $cfg.ox = $scr.Right - 290; $cfg.oy = $scr.Top + 20 }
$ov.Location = New-Object System.Drawing.Point([int]$cfg.ox, [int]$cfg.oy)
$ov.Add_Paint({
    param($s, $e)
    $r = New-Object System.Drawing.Rectangle(0, 0, $s.Width, $s.Height)
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($r, $cGlassA, $cGlassB, 90)
    $e.Graphics.FillRectangle($br, $r)
    $pen = New-Object System.Drawing.Pen((C 120 165 240 160), 2)
    $e.Graphics.DrawLine($pen, 10, 1, $s.Width - 10, 1)
})
$ovDot  = New-Label ([string][char]0x25CF) 8 6 30 34 (New-Object System.Drawing.Font("Segoe UI", 16)) $cYellow
$ovLabel = New-Label "" 38 5 228 20 $fHead $cText
$ovSub  = New-Label "" 39 25 228 16 $fSmall (C 191 210 240)
$ov.Controls.AddRange(@($ovDot, $ovLabel, $ovSub))
Set-Round $ov 12
$script:drag = $null
foreach ($ctl in @($ov, $ovDot, $ovLabel, $ovSub)) {
    $ctl.Add_MouseDown({ param($s, $e) if ($e.Button -eq "Left") { $script:drag = [System.Windows.Forms.Cursor]::Position; $script:dragStart = $ov.Location } })
    $ctl.Add_MouseMove({ param($s, $e)
        if ($script:drag) {
            $p = [System.Windows.Forms.Cursor]::Position
            $ov.Location = New-Object System.Drawing.Point(($script:dragStart.X + $p.X - $script:drag.X), ($script:dragStart.Y + $p.Y - $script:drag.Y))
        } })
    $ctl.Add_MouseUp({ $script:drag = $null; $cfg.ox = $ov.Location.X; $cfg.oy = $ov.Location.Y; Save-Settings })
    $ctl.Add_DoubleClick({ Show-Main })
}
function Update-Overlay {
    if (-not $ov) { return }
    $ovLabel.Text = $script:ovText; $ovDot.ForeColor = $script:ovColor
    $parts2 = @()
    if ($script:timerText) { $parts2 += $script:timerText }
    if ($script:partySummary) { $parts2 += $script:partySummary }
    if (-not $chkActive.Checked) { $parts2 += "paused" }
    $ovSub.Text = if ($parts2.Count) { $parts2 -join "  |  " } else { "Waechter" }
}

# ---------------- tray ----------------
$trayIcon = New-Object System.Windows.Forms.NotifyIcon
if (Test-Path $IconFile) { $trayIcon.Icon = New-Object System.Drawing.Icon($IconFile) } else { $trayIcon.Icon = [System.Drawing.SystemIcons]::Shield }
$trayIcon.Text = "Waechter"; $trayIcon.Visible = $true
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miShow  = $menu.Items.Add("Open Waechter")
$miReady = $menu.Items.Add("Ready / not ready")
$miOv    = $menu.Items.Add("Overlay on / off")
$miPause = $menu.Items.Add("Pause / resume")
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$miExit  = $menu.Items.Add("Exit")
$trayIcon.ContextMenuStrip = $menu
function Show-Main { $form.Show(); $form.WindowState = "Normal"; $form.Activate() }
$trayIcon.Add_DoubleClick({ Show-Main })
$miShow.Add_Click({ Show-Main })
$miReady.Add_Click({ if ($cfg.party) { Toggle-Ready } })
$miOv.Add_Click({ $chkOverlay.Checked = -not $chkOverlay.Checked })
$miPause.Add_Click({ $chkActive.Checked = -not $chkActive.Checked })
$miExit.Add_Click({ $script:reallyExit = $true; $form.Close() })

# ---------------- general helpers ----------------
function Write-Log($msg, $color) {
    $t = Get-Date -Format "HH:mm:ss"
    $log.SelectionStart = $log.TextLength; $log.SelectionLength = 0
    $log.SelectionColor = $cMuted; $log.AppendText("$t  ")
    $log.SelectionColor = $color; $log.AppendText("$msg`n")
    $log.ScrollToCaret()
    try { Add-Content -Path $LogFile -Value "[$t] $msg" } catch { }
}
function Set-Status($text, $sub, $color) {
    $lblStatus.Text = $text; $lblServer.Text = $sub; $lblDot.ForeColor = $color
    $script:ovText = $text; $script:ovColor = $color
    Update-Overlay
    try { $t = "Waechter - $text"; if ($t.Length -gt 63) { $t = $t.Substring(0, 63) }; $trayIcon.Text = $t } catch { }
}
function Notify($title, $text) {
    if ($script:replay) { return }
    if (-not $form.Visible -and $trayIcon) { try { $trayIcon.ShowBalloonTip(4000, $title, $text, [System.Windows.Forms.ToolTipIcon]::Info) } catch { } }
}
function Update-Stats { $lblStats.Text = "Checked $($script:checked)   |   Official $($script:official)   |   Blocked $($script:blocked)" }
function Get-BlackIps { @(Get-Content $Blacklist | ForEach-Object { ($_ -split '\s+')[0].Trim() } | Where-Object { $_ -ne "" }) }
function Refresh-Blacklist {
    $lstBlack.Items.Clear()
    Get-Content $Blacklist | Where-Object { $_.Trim() -ne "" } | ForEach-Object { [void]$lstBlack.Items.Add($_) }
}
function Is-Local($ip) { return ($ip -match '^(loopback|localhost|0\.0\.0\.0|127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)') }
function Update-SteamLabel {
    if ($steamName) { $lblSteam.Text = "Steam: $steamName" } else { $lblSteam.Text = "Steam: not detected" }
}

# ---------------- party (relay via ntfy.sh, no IPs are ever sent) ----------------
$http = New-Object System.Net.Http.HttpClient
$http.Timeout = [System.Threading.Timeout]::InfiniteTimeSpan
$script:replay      = $false
$script:members     = @{}        # id -> @{name;role;status;seen}
$script:myStatus    = "Game closed"
$script:closedSince = Get-Date
$script:myReady     = $false
$script:subTask     = $null; $script:subReader = $null; $script:lineTask = $null
$script:lastMsgId   = $null; $script:nextSub = [DateTime]::MinValue
$script:nextBeat    = [DateTime]::MinValue
$script:hostStatus  = $null

function Topic { return "waechter_" + ($cfg.party -replace '[^A-Z0-9]', '').ToLower() }
function New-Code {
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".ToCharArray()
    $r = New-Object System.Random
    $a = -join (1..4 | ForEach-Object { $chars[$r.Next($chars.Length)] })
    $b = -join (1..4 | ForEach-Object { $chars[$r.Next($chars.Length)] })
    $c = -join (1..4 | ForEach-Object { $chars[$r.Next($chars.Length)] })
    return "$a-$b-$c"
}
function Publish($type, $text = $null) {
    if (-not $cfg.party) { return }
    $msg = @{ v = 1; type = $type; text = $text; id = $cfg.id; name = $txtName.Text.Trim(); role = $(if ($cfg.host) { "host" } else { "member" }); status = $script:myStatus; ready = $script:myReady } | ConvertTo-Json -Compress
    try {
        $content = New-Object System.Net.Http.StringContent($msg, [System.Text.Encoding]::UTF8, "text/plain")
        [void]$http.PostAsync("$Relay/$(Topic)", $content)
    } catch { }
}
function Set-MyStatus($s) {
    if ($script:myStatus -ne $s) { $script:myStatus = $s; Publish "status" }
    Refresh-Party
}
function Stop-Sub {
    try { if ($script:subReader) { $script:subReader.Dispose() } } catch { }
    $script:subTask = $null; $script:subReader = $null; $script:lineTask = $null
}
function Start-Sub {
    Stop-Sub
    if (-not $cfg.party) { return }
    $since = if ($script:lastMsgId) { $script:lastMsgId } else { "10m" }
    try { $script:subTask = $http.GetStreamAsync("$Relay/$(Topic)/json?since=$since") } catch { $script:nextSub = (Get-Date).AddSeconds(10) }
}
function Refresh-Party {
    $lvParty.BeginUpdate(); $lvParty.Items.Clear()
    if ($cfg.party) {
        $me = New-Object System.Windows.Forms.ListViewItem(($txtName.Text.Trim() + "  (you)"))
        [void]$me.SubItems.Add($(if ($cfg.host) { "Host" } else { "" }))
        [void]$me.SubItems.Add($(if ($script:myReady) { "Ready" } else { "-" }))
        [void]$me.SubItems.Add($script:myStatus)
        $me.UseItemStyleForSubItems = $false; $me.Tag = $cfg.id
        $me.ForeColor = (Get-PersonColor $cfg.id)
        for ($si = 1; $si -lt $me.SubItems.Count; $si++) { $me.SubItems[$si].ForeColor = (Get-StatusColor $script:myStatus); $me.SubItems[$si].BackColor = $cGlassB }
        $me.SubItems[0].BackColor = $cGlassB
        [void]$lvParty.Items.Add($me)
        foreach ($k in @($script:members.Keys)) {
            $m = $script:members[$k]
            $it = New-Object System.Windows.Forms.ListViewItem($m.name)
            [void]$it.SubItems.Add($(if ($m.role -eq "host") { "Host" } else { "" }))
            [void]$it.SubItems.Add($(if ($m.ready) { "Ready" } else { "-" }))
            [void]$it.SubItems.Add($m.status)
            $it.UseItemStyleForSubItems = $false; $it.Tag = $k
            $it.ForeColor = (Get-PersonColor $k)
            for ($si = 1; $si -lt $it.SubItems.Count; $si++) { $it.SubItems[$si].ForeColor = (Get-StatusColor $m.status); $it.SubItems[$si].BackColor = $cGlassB }
            $it.SubItems[0].BackColor = $cGlassB
            [void]$lvParty.Items.Add($it)
        }
        $n = $script:members.Count + 1
        $rc = @($script:members.Values | Where-Object { $_.ready }).Count + $(if ($script:myReady) { 1 } else { 0 })
        $lblPartyState.Text = "$n member$(if ($n -ne 1) { 's' })  -  $rc/$n ready  -  " + $(if ($cfg.host) { "host" } else { "member" })
        $script:partySummary = "Party $rc/$n ready"
        $lblCode.Text = $cfg.party
    } else {
        $lblPartyState.Text = "Not in a party"; $lblCode.Text = "-"; $script:partySummary = ""
    }
    $lvParty.EndUpdate()
    $btnLeave.Enabled = [bool]$cfg.party; $btnCopy.Enabled = [bool]$cfg.party; $btnReady.Enabled = [bool]$cfg.party
    $btnReady.Text = if ($script:myReady) { "Not ready" } else { "Ready" }
    $btnReady.BackColor = if ($script:myReady) { (C 22 101 52) } else { $cInput }
    Update-Overlay
    $btnCreate.Enabled = -not $cfg.party; $btnJoin.Enabled = -not $cfg.party; $txtCode.Enabled = -not $cfg.party
}
function Get-StatusColor($s) {
    switch -Wildcard ($s) {
        "On official*" { return $cGreen }
        "Kicked*"      { return $cRed }
        "Checking*"    { return (C 147 197 253) }
        "Game closed*" { return $cMuted }
        "Offline*"     { return $cMuted }
        "AFK*"         { return $cMuted }
        default        { return $cText }
    }
}
function Add-Chat($who, $text, $color, $highlight = $false) {
    $t = Get-Date -Format "HH:mm"
    $chat.SelectionStart = $chat.TextLength; $chat.SelectionLength = 0
    $chat.SelectionBackColor = $(if ($highlight) { (C 113 63 18) } else { $cGlassB })
    $chat.SelectionColor = $cMuted; $chat.AppendText("$t  ")
    $chat.SelectionColor = $color; $chat.AppendText("$($who): ")
    $chat.SelectionColor = $(if ($highlight) { (C 254 240 138) } else { $cText })
    if ($text -match '[\uD800-\uDBFF]|[\u2600-\u27BF]') { $chat.SelectionFont = $fEmojiChat } else { $chat.SelectionFont = $fChat }
    $chat.AppendText("$text`n")
    $chat.SelectionFont = $fChat
    $chat.SelectionBackColor = $cGlassB
    $chat.ScrollToCaret()
}
function Send-Text($text) {
    $text = ([string]$text -replace "[`r`n`t]", " ").Trim()
    if (-not $text) { return $false }
    if (-not $cfg.party) { Add-Chat "Waechter" "Join or create a party first." $cMuted; return $false }
    if ($text.Length -gt 200) { $text = $text.Substring(0, 200) }
    Publish "chat" $text
    Add-Chat $txtName.Text.Trim() $text (Get-PersonColor $cfg.id)
    if ($text -eq "Queue now") { Start-Search }
    return $true
}
function Send-Chat { if (Send-Text $txtChat.Text) { $txtChat.Text = "" } }
function Handle-PartyMessage($raw) {
    try { $ev = $raw | ConvertFrom-Json } catch { return }
    if ($ev.event -ne "message") { return }
    $script:lastMsgId = $ev.id
    # messages older than 20 s are history (replayed after a restart): show them, but no sounds, popups or actions
    $old = $false
    try { $old = (([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) - [long]$ev.time) -gt 20 } catch { }
    $script:replay = $old
    try { $m = $ev.message | ConvertFrom-Json } catch { return }
    if (-not $m.id -or $m.id -eq $cfg.id) { return }
    $name = ([string]$m.name); if ($name.Length -gt 24) { $name = $name.Substring(0, 24) }
    if ($m.type -eq "countdown" -and -not $old) {
        Add-Chat $name "started a queue countdown" (Get-PersonColor $m.id)
        Start-Countdown ([int]("0" + ([string]$m.text -replace '[^0-9]', ''))) $name
    }
    if ($m.type -eq "react" -and $m.text) {
        $rt = [string]$m.text; if ($rt.Length -gt 4) { $rt = $rt.Substring(0, 4) }
        Add-Chat $name "reacted $rt" (Get-PersonColor $m.id)
        Play-Member $m.id
    }
    if ($m.type -eq "chat" -and $m.text) {
        $txt = [string]$m.text; if ($txt.Length -gt 200) { $txt = $txt.Substring(0, 200) }
        $myName = $txtName.Text.Trim()
        $mention = ($myName.Length -ge 3 -and $txt -match ("(?i)(^|[^a-z0-9])@?" + [regex]::Escape($myName) + "($|[^a-z0-9])"))
        Add-Chat $name $txt (Get-PersonColor $m.id) $mention
        if ($txt -eq "Queue now" -and $m.role -eq "host" -and -not $old) { Start-Search }
        if ($mention) {
            Play 'party'
            Write-Log "$name mentioned you" $cYellow
            if (-not $form.ContainsFocus -and -not $old) { try { $trayIcon.ShowBalloonTip(4000, "$name mentioned you", $txt, [System.Windows.Forms.ToolTipIcon]::Info) } catch { } }
        } else { Play-Member $m.id }
        if (-not $mention) { Notify "$name" $txt }
    }
    if ($m.type -eq "full" -and [string]$m.text -eq $cfg.id -and -not $old) {
        Write-Log "That party is full (max $PartyMax players)" $cRed
        [void][System.Windows.Forms.MessageBox]::Show("This party is full (max $PartyMax players).", "Waechter")
        Leave-Party
        return
    }
    if ($m.type -eq "go" -and $m.role -eq "host" -and -not $old -and -not $cfg.host) {
        $addr = Show-Addr $m.text
        if ($addr) {
            Add-Chat "Waechter" "$name found a game - joining automatically." $cMuted
            Write-Log "Host found a versus game - joining" $cGreen
            Play 'official'
            $script:q = @{ failed = @{}; found = @{}; ping = @{}; sentAt = @{}; scanning = $false; joining = $true; member = $true; target = $addr; joinDeadline = (Get-Date).AddSeconds(60) }
            Set-Status "Host found a game - joining ..." "Waechter connects you automatically" $cGreen
            Connect-To $addr
            if (-not $script:client) { $script:q.joinDeadline = (Get-Date).AddSeconds(120) }
        }
    }
    if ($m.type -eq "joinfail" -and $cfg.host -and -not $old) {
        Write-Log "$name could not join - searching a new game for everyone" $cYellow
        Add-Chat "Waechter" "$name could not join - searching a new game." $cMuted
        if (-not $script:q) { Start-Queue }
    }
    if ($m.type -eq "promote" -and [string]$m.text -eq $cfg.id -and -not $old) {
        $cfg.host = $true; Save-Settings
        Write-Log "$name made you the host" $cGreen
        Add-Chat "Waechter" "$name made you the party host." $cMuted
        Play 'party'
        Publish "status"
    }
    if ($m.type -eq "leave") {
        if ($script:members.ContainsKey($m.id)) { Write-Log "$name left the party" $cMuted; $script:members.Remove($m.id) }
        Refresh-Party; return
    }
    $isNew = -not $script:members.ContainsKey($m.id)
    if ($isNew -and $cfg.host -and $m.type -ne "leave" -and @($script:members.Keys).Count -ge ($PartyMax - 1)) {
        if (-not $old) { Publish "full" ([string]$m.id); Write-Log "$name tried to join - party is full (max $PartyMax)" $cYellow }
        return
    }
    $oldStatus = if ($isNew) { $null } else { $script:members[$m.id].status }
    $wasReady = if ($isNew) { $false } else { $script:members[$m.id].ready }
    $script:members[$m.id] = @{ name = $name; role = [string]$m.role; status = [string]$m.status; ready = [bool]$m.ready; seen = Get-Date }
    if (-not $isNew -and [bool]$m.ready -and -not $wasReady) { Write-Log "$name is ready" $cGreen; Play 'party' }
    if ($isNew) {
        Write-Log "$name joined the party" (C 147 197 253)
        Play 'party'
        if ($m.type -eq "hello") { Publish "status" }   # let newcomers see us
    }
    if ($m.role -eq "host" -and $oldStatus -ne $m.status -and -not $old) {
        if ($m.status -like "On official*") {
            Stop-Search $true
            Write-Log "Host found an official game - accept the host's lobby invite" $cGreen
            Notify "Host found an official game" "Accept the host's L4D2 lobby invite."
            Set-Status "Host is in an official game" "Accept the host's L4D2 lobby invite to join" $cGreen
            Play 'official'
        } elseif ($m.status -like "Kicked*") {
            Start-Search
            Write-Log "Host hit an unofficial server and was kicked - requeueing" $cYellow
            Set-Status "Host is requeueing" "Party stays together - wait for the next lobby" $cYellow
        }
    }
    Refresh-Party
    $script:replay = $false
}
function Join-Party($code, $asHost) {
    $cfg.party = $code; $cfg.host = $asHost; Add-Recent $code; Save-Settings; Refresh-Recent
    $script:members = @{}; $script:lastMsgId = $null
    Start-Sub
    Publish "hello"
    $script:nextBeat = (Get-Date).AddMinutes(2)
    Write-Log $(if ($asHost) { "Party created: $code" } else { "Joined party $code" }) (C 147 197 253)
    Refresh-Party
}
function Leave-Party {
    if (-not $cfg.party) { return }
    Publish "leave"
    Write-Log "You left the party" $cMuted
    Stop-Sub
    $cfg.party = ""; $cfg.host = $false; Save-Settings
    $script:members = @{}; $script:myReady = $false
    Refresh-Party
}
function Pump-Party {
    if (-not $cfg.party) { return }
    # subscription
    if (-not $script:subTask) {
        if ((Get-Date) -ge $script:nextSub) { Start-Sub }
    } elseif (-not $script:subReader) {
        if ($script:subTask.IsCompleted) {
            if ($script:subTask.IsFaulted -or $script:subTask.IsCanceled) {
                Stop-Sub; $script:nextSub = (Get-Date).AddSeconds(10)
            } else {
                $script:subReader = New-Object System.IO.StreamReader($script:subTask.Result)
                $script:lineTask = $script:subReader.ReadLineAsync()
            }
        }
    } else {
        $n = 0
        while ($script:lineTask -and $script:lineTask.IsCompleted -and $n -lt 20) {
            $n++
            if ($script:lineTask.IsFaulted -or $null -eq $script:lineTask.Result) {
                Stop-Sub; $script:nextSub = (Get-Date).AddSeconds(5); break
            }
            Handle-PartyMessage $script:lineTask.Result
            $script:replay = $false
            $script:lineTask = $script:subReader.ReadLineAsync()
        }
    }
    # heartbeat every 2 min, drop members silent for 5 min
    if ((Get-Date) -ge $script:nextBeat) {
        $script:nextBeat = (Get-Date).AddMinutes(2); Publish "status"
        $changed = $false
        foreach ($k in @($script:members.Keys)) {
            if (((Get-Date) - $script:members[$k].seen).TotalMinutes -gt 5) { $script:members.Remove($k); $changed = $true }
        }
        if ($changed) { Refresh-Party }
    }
}

# ---------------- search timer + session ----------------
$script:searchStart = $null
$script:searchTimes = New-Object System.Collections.ArrayList
$script:sessionStart = Get-Date
$script:roomKicks = 0
function Format-Span($ts) {
    if ($ts.TotalHours -ge 1) { return ("{0}:{1:00}:{2:00}" -f [int][Math]::Floor($ts.TotalHours), $ts.Minutes, $ts.Seconds) }
    return ("{0}:{1:00}" -f [int][Math]::Floor($ts.TotalMinutes), $ts.Seconds)
}
$script:cdEnd = $null; $script:cdLast = -1
function Start-Countdown($secs, $who) {
    $secs = [Math]::Max(3, [Math]::Min(30, [int]$secs))
    $script:cdEnd = (Get-Date).AddSeconds($secs); $script:cdLast = -1
    Write-Log "$who started a $secs s queue countdown" (C 147 197 253)
}
function Tick-Countdown {
    if (-not $script:cdEnd) { return }
    $left = [int][Math]::Ceiling(($script:cdEnd - (Get-Date)).TotalSeconds)
    if ($left -le 0) {
        $script:cdEnd = $null
        Write-Log "Countdown finished - queue now!" $cGreen
        Play 'official'
        if (-not $cfg.party -or $cfg.host) { if (-not $script:q) { Start-Queue } }
        else { Set-Status "Host is searching a game" "Waechter connects you automatically" $cGreen; Start-Search }
        return
    }
    if ($left -ne $script:cdLast) {
        $script:cdLast = $left
        Set-Status "Queue in $left ..." "Get ready - countdown from the party" (C 147 197 253)
        if ($left -le 3) { Play 'click' }
    }
}
function Start-Search { if (-not $script:searchStart) { $script:searchStart = Get-Date; Update-Timer } }
function Stop-Search($found) {
    if ($script:searchStart) {
        if ($found) { [void]$script:searchTimes.Add(((Get-Date) - $script:searchStart).TotalSeconds) }
        $script:searchStart = $null; Update-Timer
    }
}
function Update-Timer {
    if ($script:searchStart) {
        $t = "Searching " + (Format-Span ((Get-Date) - $script:searchStart))
        $lblTimer.Text = $t; $script:timerText = $t
    } else { $lblTimer.Text = ""; $script:timerText = "" }
    Update-Overlay
}
function Show-Summary {
    $dur = (Get-Date) - $script:sessionStart
    $avg = if ($script:searchTimes.Count -gt 0) { Format-Span ([TimeSpan]::FromSeconds((($script:searchTimes | Measure-Object -Average).Average))) } else { "-" }
    $line = "{0},{1},{2},{3},{4},{5}" -f (Get-Date -Format "yyyy-MM-dd HH:mm"), [int]$dur.TotalMinutes, $script:checked, $script:official, $script:blocked, $avg
    try {
        $csv = Join-Path $Here "sessions.csv"
        if (-not (Test-Path $csv)) { Set-Content -Path $csv -Value "date,minutes,checked,official,blocked,avg_search" }
        Add-Content -Path $csv -Value $line
    } catch { }
    if ($script:checked -eq 0) { return }
    $msg = "Session summary`n`n" +
           "Time:                 $(Format-Span $dur)`n" +
           "Servers checked:      $($script:checked)`n" +
           "Official games:       $($script:official)`n" +
           "Blocked / kicked:     $($script:blocked)`n" +
           "  - not enough room:  $($script:roomKicks)`n" +
           "Avg. search time:     $avg"
    [void][System.Windows.Forms.MessageBox]::Show($msg, "Waechter", "OK", "Information")
}

# ---------------- game watcher (netcon) ----------------
$script:checked = 0; $script:official = 0; $script:blocked = 0
$script:client = $null; $script:stream = $null; $script:pending = ""
$script:currentIp = $null; $script:hostname = $null; $script:checkAt = $null
$script:humans = $null; $script:maxPlayers = $null
$script:isChecked = $true; $script:statusSent = $false; $script:nextConnect = [DateTime]::MinValue
$buf = New-Object byte[] 65536

function Send-Cmd($cmd) { try { $b = [System.Text.Encoding]::ASCII.GetBytes("$cmd`n"); $script:stream.Write($b, 0, $b.Length) } catch { } }
function Drop-Connection {
    try { $script:client.Close() } catch { }
    $script:client = $null; $script:stream = $null; $script:pending = ""
    Set-Status "Waiting for L4D2 ..." "Launch option -netconport 2121 required" $cYellow
    Write-Log "Lost connection to L4D2 (game closed?)" $cYellow
    $script:closedSince = Get-Date
    Set-MyStatus "Game closed"
}
function Kick($reason, $logText) {
    $script:blocked++; Update-Stats
    if ($script:q -and $script:q.joining) { $script:q.joining = $false; if ($script:q.target) { $script:q.failed[$script:q.target] = 1; $script:badServers[$script:q.target] = 1 } }
    Send-Cmd "disconnect"
    Send-Cmd "echo [Waechter] $reason"
    Write-Log $logText $cRed
    Notify "Kicked from server" "Search again - your party stays together."
    Start-Search
    Play 'kicked'
    Set-MyStatus "Kicked - requeue"
}
function Handle-Line($line) {
    Handle-QueueLine $line
    if ($line -match 'Connected to\s+([0-9a-zA-Z\.\-]+)(:\d+)?') {
        $script:currentIp = $matches[1]; $script:hostname = $null; $script:humans = $null; $script:maxPlayers = $null
        $script:isChecked = $false; $script:statusSent = $false
        $script:checkAt = (Get-Date).AddSeconds(2)
        Set-Status "Checking server ..." "One moment" (C 147 197 253)
        if ($script:myReady) { $script:myReady = $false; Refresh-Party }
        if (-not (Is-Local $script:currentIp)) { Set-MyStatus "Checking server" }
        if ($chkActive.Checked -and -not (Is-Local $script:currentIp) -and ((Get-BlackIps) -contains $script:currentIp)) {
            $script:isChecked = $true
            Kick "Blacklisted server - disconnected. Search again." "BLOCKED  blacklisted server"
            Set-Status "Kicked (blacklisted server)" "Search again - your party stays together" $cRed
        }
    }
    if ($line -match 'BinkOpen.*background' -and $script:currentIp -and -not ($script:q -and $script:q.joining)) {
        # back in the main menu (left the server or got dropped)
        $script:currentIp = $null; $script:isChecked = $true
        Set-Status "Connected to L4D2" "In menu - press QUEUE to find a game" $cGreen
        Set-MyStatus "In menu"
    }
    if ($script:statusSent -and $line -match '^\s*hostname\s*:\s*(.+)$') { $script:hostname = $matches[1].Trim() }
    if ($script:statusSent -and $line -match '^\s*players\s*:\s*(\d+)\s+humans?.*\((\d+)\s+max\)') {
        $script:humans = [int]$matches[1]; $script:maxPlayers = [int]$matches[2]
    }
    if ($script:statusSent -and $line -match '^\s*udp/ip\s*:\s*([0-9\.]+)') {
        if (-not $script:currentIp -or (Is-Local $script:currentIp)) { $script:currentIp = $matches[1] }
    }
}
function Evaluate {
    $script:isChecked = $true
    $ip = $script:currentIp
    if (Is-Local $ip) {
        Set-Status "Local game" "Ignored" $cMuted
        Write-Log "Local game - ignored" $cMuted
        Set-MyStatus "In a local game"
        return
    }
    $script:checked++
    if ($script:hostname -and $script:hostname -match '^Valve Left ?4 ?Dead') {
        $script:official++; Update-Stats
        if ($cfg.party -and $cfg.host -and $chkRoom.Checked -and $chkActive.Checked -and $script:maxPlayers) {
            $need = @($script:members.Values | Where-Object { $_.status -notlike "On official*" -and $_.status -notlike "Checking*" -and $_.status -notlike "Offline*" -and $_.status -notlike "Game closed*" }).Count
            $free = $script:maxPlayers - $script:humans
            if ($need -gt 0 -and $free -lt $need) {
                $script:roomKicks++
                Kick "Not enough room for your party ($free free, $need needed). Search again." "NO ROOM  $free free, party needs $need"
                Set-Status "Not enough room - kicked" "$free free slot(s), your party needs $need - search again" $cYellow
                return
            }
        }
        Set-Status "Official Valve server" $script:hostname $cGreen
        Write-Log "OFFICIAL  $($script:hostname)" $cGreen
        Send-Cmd "echo [Waechter] Official Valve server - all good."
        Stop-Search $true
        Play 'official'
        Add-Learned $ip
        Queue-Joined
        Set-MyStatus "On official server"
        return
    }
    $name = if ($script:hostname) { $script:hostname } else { "(no name)" }
    if (-not $chkActive.Checked) {
        Update-Stats
        Set-Status "Unofficial server (Waechter paused)" $name $cYellow
        Write-Log "UNOFFICIAL (paused, not kicked)  $name" $cYellow
        Set-MyStatus "On unofficial server"
        return
    }
    if (-not ((Get-BlackIps) -contains $ip)) {
        Add-Content -Path $Blacklist -Value ("{0}    # {1}  ({2})" -f $ip, $name, (Get-Date -Format "yyyy-MM-dd HH:mm"))
        Refresh-Blacklist
    }
    Kick "Unofficial server - disconnected and blacklisted. Search again." "BLOCKED  $name"
    Set-Status "Unofficial server - kicked" "Search again - your party stays together" $cRed
}
function Pump-Game {
    if (-not $script:client) {
        if ((Get-Date) -lt $script:nextConnect) { return }
        $script:nextConnect = (Get-Date).AddSeconds(3)
        $c = New-Object System.Net.Sockets.TcpClient
        try {
            $ar = $c.BeginConnect("127.0.0.1", $Port, $null, $null)
            if ($ar.AsyncWaitHandle.WaitOne(200) -and $c.Connected) {
                $c.EndConnect($ar)
                $script:client = $c; $script:stream = $c.GetStream()
                Set-Status "Connected to L4D2" "Ready - press QUEUE to find a game" $cGreen
                Write-Log "Connected to L4D2" $cGreen
                Set-MyStatus "In menu"
                if ($script:pendingGo) {
                    if ((Get-Date) -lt $script:pendingGo.until) { Write-Log "Joining the queued game" $cGreen; Send-Cmd "connect $($script:pendingGo.key)" }
                    $script:pendingGo = $null
                }
            } else { $c.Close() }
        } catch { try { $c.Close() } catch { } }
        return
    }
    try {
        if ($script:client.Client.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead) -and $script:client.Client.Available -eq 0) { Drop-Connection; return }
        while ($script:stream.DataAvailable) {
            $n = $script:stream.Read($buf, 0, $buf.Length)
            if ($n -le 0) { break }
            $script:pending += [System.Text.Encoding]::UTF8.GetString($buf, 0, $n)
        }
    } catch { Drop-Connection; return }
    if ($script:pending.Contains("`n")) {
        $parts = $script:pending -split "`r?`n"
        $script:pending = $parts[-1]
        foreach ($line in $parts[0..($parts.Length - 2)]) { Handle-Line $line }
    }
    if (-not $script:isChecked -and -not $script:statusSent -and $script:checkAt -and (Get-Date) -ge $script:checkAt) {
        Send-Cmd "status"; $script:statusSent = $true; $script:checkAt = (Get-Date).AddSeconds(2)
    }
    if (-not $script:isChecked -and $script:statusSent -and ($script:hostname -or (Get-Date) -ge $script:checkAt.AddSeconds(4))) { Evaluate }
}

# ---------------- queue: find a running official versus game and connect everyone (no lobby, no API key) ----------------
$LearnedFile = Join-Path $Here "valve_servers.txt"
$PartyMax = 4
# addresses of Valve's official L4D2 machines (Valve's own data centers + the machines Valve rents)
$script:SeedSets = @(
    @{ ips = @("162.254.198.133", "162.254.198.134", "162.254.192.132", "162.254.192.133", "155.133.246.90", "155.133.246.91"); lo = 27015; hi = 27078 },
    @{ ips = @((185..191 | ForEach-Object { "65.109.72.$_" }) + (210..216 | ForEach-Object { "157.180.58.$_" }) + (165..182 | ForEach-Object { "89.222.108.$_" }) + (206..214 | ForEach-Object { "138.199.142.$_" })); lo = 27015; hi = 27115 }
)
$A2SReq = [byte[]](@(0xFF, 0xFF, 0xFF, 0xFF, 0x54) + [System.Text.Encoding]::ASCII.GetBytes("Source Engine Query") + @(0))
$script:q = $null; $script:udp = $null; $script:pendingGo = $null
$script:badServers = @{}     # servers we could not join this session

function Add-Learned($ip) {
    if (-not $ip -or $ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { return }
    foreach ($s in $script:SeedSets) { if ($s.ips -contains $ip) { return } }
    $have = @(); if (Test-Path $LearnedFile) { $have = @(Get-Content $LearnedFile | ForEach-Object { $_.Trim() }) }
    if ($have -notcontains $ip) { try { Add-Content -Path $LearnedFile -Value $ip } catch { } }
}
function Get-QueueTargets {
    $list = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    $sets = @($script:SeedSets)
    if (Test-Path $LearnedFile) {
        $l = @(Get-Content $LearnedFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' })
        if ($l.Count) { $sets += @{ ips = $l; lo = 27015; hi = 27115 } }
    }
    $black = @(Get-BlackIps)
    foreach ($s in $sets) {
        foreach ($ip in $s.ips) {
            if ($black -contains $ip) { continue }
            for ($p = $s.lo; $p -le $s.hi; $p++) { $k = "$($ip):$p"; if (-not $seen.ContainsKey($k)) { $seen[$k] = 1; $list.Add($k) } }
        }
    }
    return , $list
}
function Get-PartyKey {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("waechter|" + $cfg.party))
}
# the server address is sent scrambled with the party code and is never shown anywhere
function Hide-Addr($s) {
    $k = Get-PartyKey; $b = [System.Text.Encoding]::ASCII.GetBytes($s)
    for ($i = 0; $i -lt $b.Length; $i++) { $b[$i] = [byte]($b[$i] -bxor $k[$i % $k.Length]) }
    return [Convert]::ToBase64String($b)
}
function Show-Addr($t) {
    try {
        $k = Get-PartyKey; $b = [Convert]::FromBase64String([string]$t)
        for ($i = 0; $i -lt $b.Length; $i++) { $b[$i] = [byte]($b[$i] -bxor $k[$i % $k.Length]) }
        $s = [System.Text.Encoding]::ASCII.GetString($b)
        if ($s -match '^\d{1,3}(\.\d{1,3}){3}:\d{2,5}$') { return $s }
    } catch { }
    return $null
}
function Open-Udp {
    if ($script:udp) { return $true }
    try {
        $script:udp = New-Object System.Net.Sockets.UdpClient(0)
        try { [void]$script:udp.Client.IOControl([int]-1744830452, [byte[]](0, 0, 0, 0), $null) } catch { }   # ignore "port unreachable"
        return $true
    } catch { $script:udp = $null; return $false }
}
function Send-A2S($key, $extra) {
    $parts = $key.Split(':')
    $pkt = if ($extra) { [byte[]]($A2SReq + $extra) } else { $A2SReq }
    try { [void]$script:udp.Send($pkt, $pkt.Length, $parts[0], [int]$parts[1]) } catch { }
}
function Read-A2SInfo([byte[]]$d) {
    $i = 6; $r = @{}
    foreach ($f in @('name', 'map', 'folder', 'game')) {
        $j = [Array]::IndexOf($d, [byte]0, $i); if ($j -lt 0) { return $null }
        $r[$f] = [System.Text.Encoding]::UTF8.GetString($d, $i, $j - $i); $i = $j + 1
    }
    if ($i + 9 -gt $d.Length) { return $null }
    $i += 2
    $r.players = [int]$d[$i]; $r.max = [int]$d[$i + 1]; $r.bots = [int]$d[$i + 2]
    $i += 7
    $r.keywords = ""
    $j = [Array]::IndexOf($d, [byte]0, $i); if ($j -lt 0) { return $r }
    $i = $j + 1
    if ($i -lt $d.Length) {
        $edf = [int]$d[$i]; $i++
        if ($edf -band 0x80) { $i += 2 }
        if ($edf -band 0x10) { $i += 8 }
        if ($edf -band 0x40) { $i += 2; $j = [Array]::IndexOf($d, [byte]0, $i); if ($j -lt 0) { return $r }; $i = $j + 1 }
        if (($edf -band 0x20) -and $i -lt $d.Length) {
            $j = [Array]::IndexOf($d, [byte]0, $i)
            if ($j -gt $i) { $r.keywords = [System.Text.Encoding]::UTF8.GetString($d, $i, $j - $i) }
        }
    }
    return $r
}
function Pump-Udp {
    if (-not $script:udp) { return }
    $n = 0
    while ($n -lt 600) {
        try { if ($script:udp.Available -le 0) { break } } catch { break }
        $n++
        $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        try { $d = $script:udp.Receive([ref]$ep) } catch { continue }
        $qq = $script:q
        if (-not $qq -or -not $qq.scanning -or $d.Length -lt 6) { continue }
        $key = "$($ep.Address):$($ep.Port)"
        if (-not $qq.ping.ContainsKey($key) -and $qq.sentAt.ContainsKey($key)) { $qq.ping[$key] = [int]((Get-Date) - $qq.sentAt[$key]).TotalMilliseconds }
        if ($d[4] -eq 0x41 -and $d.Length -ge 9) { Send-A2S $key ([byte[]]$d[5..8]); continue }
        if ($d[4] -eq 0x49) { $info = Read-A2SInfo $d; if ($info) { $qq.found[$key] = $info } }
    }
}
function Get-PartySize {
    if (-not $cfg.party) { return 1 }
    return 1 + @($script:members.Values | Where-Object { $_.status -notlike "Offline*" }).Count
}
function Start-Queue {
    if ($cfg.party -and -not $cfg.host) {
        Write-Log "Only the party host can start the queue" $cYellow
        Add-Chat "Waechter" "Only the party host can start the queue." $cMuted
        return
    }
    if (-not (Open-Udp)) { Write-Log "Queue not possible - network blocked" $cRed; return }
    $script:q = @{ failed = @{}; found = @{}; ping = @{}; sentAt = @{}; scanning = $false; joining = $false; waitUntil = $null; member = $false; scans = 0 }
    $btnQueue.Text = "Cancel"; $btnQueue.BackColor = (C 127 29 29)
    $script:searchStart = $null; Start-Search
    $size = Get-PartySize
    Write-Log "QUEUE  looking for a running official versus game ($size player$(if ($size -ne 1) { 's' }))" (C 147 197 253)
    if ($cfg.party) { Publish "chat" "Queue started - searching an official versus game"; Add-Chat $txtName.Text.Trim() "Queue started - searching an official versus game" (Get-PersonColor $cfg.id) }
    Start-QueueScan
}
function Stop-Queue($msg) {
    $script:q = $null
    $btnQueue.Text = "QUEUE"; $btnQueue.BackColor = $cAccent
    Stop-Search $false
    if ($msg) { Write-Log $msg $cMuted }
}
function Start-QueueScan {
    $qq = $script:q; if (-not $qq) { return }
    $qq.targets = Get-QueueTargets; $qq.idx = 0
    $qq.found = @{}; $qq.ping = @{}; $qq.sentAt = @{}
    $qq.lastSend = Get-Date; $qq.scanning = $true; $qq.scans++
    Set-Status "Searching versus games ..." "Asking the official Valve servers" (C 147 197 253)
}
# exact ping: ask one port per machine at the same moment and time the first answer
function Measure-Pings($keys) {
    $res = @{}
    if (-not $script:udp -or -not $keys) { return $res }
    while ($script:udp.Available -gt 0) { $ep0 = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0); try { [void]$script:udp.Receive([ref]$ep0) } catch { break } }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($k in $keys) { Send-A2S $k $null }
    while ($sw.ElapsedMilliseconds -lt 800 -and $res.Count -lt @($keys).Count) {
        $av = 0; try { $av = $script:udp.Available } catch { break }
        if ($av -gt 0) {
            $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
            try { [void]$script:udp.Receive([ref]$ep); $ip = [string]$ep.Address; if (-not $res.ContainsKey($ip)) { $res[$ip] = [int]$sw.ElapsedMilliseconds } } catch { }
        } else { Start-Sleep -Milliseconds 1 }
    }
    return $res
}
function Pick-QueueServer {
    $qq = $script:q; if (-not $qq) { return }
    $size = Get-PartySize
    $cands = @(); $official = 0; $versus = 0
    foreach ($k in @($qq.found.Keys)) {
        $s = $qq.found[$k]
        if ($s.name -notmatch '^Valve Left ?4 ?Dead') { continue }
        $official++
        $tags = @(([string]$s.keywords -split ',') | ForEach-Object { $_.Trim().ToLower() })
        if ($tags -notcontains 'versus') { continue }
        $versus++
        $humans = [Math]::Max(0, $s.players - $s.bots)
        if ($humans -lt 2) { continue }                      # never join empty / nearly empty games
        if (($s.max - $humans) -lt $size) { continue }        # room for the whole party
        if ($qq.failed.ContainsKey($k) -or $script:badServers.ContainsKey($k)) { continue }
        $cands += [pscustomobject]@{ key = $k; ip = $k.Split(':')[0]; ping = 999; humans = $humans; max = $s.max; map = $s.map }
    }
    if ($cands.Count) {
        $probe = @(); $seenIp = @{}
        foreach ($c in $cands) { if (-not $seenIp.ContainsKey($c.ip)) { $seenIp[$c.ip] = 1; $probe += $c.key } }
        $pings = Measure-Pings $probe
        foreach ($c in $cands) { if ($pings.ContainsKey($c.ip)) { $c.ping = $pings[$c.ip] } }
        $near = @($cands | Where-Object { $_.ping -le 180 })
        if ($near.Count) { $cands = $near }
    }
    if (-not $cands.Count) {
        $qq.waitUntil = (Get-Date).AddSeconds(20)
        $why = if ($official -eq 0) { "No official server answered - check your internet" } else { "$official official servers, $versus in versus - none with players and room right now" }
        Set-Status "Searching versus games ..." "$why. Next try in 20 s" (C 147 197 253)
        if ($qq.scans -le 1 -or ($qq.scans % 5) -eq 0) { Write-Log "No fitting versus game yet ($official official, $versus versus) - still searching" $cMuted }
        return
    }
    $best = $cands | Sort-Object ping | Select-Object -First 1
    Go-Server $best
}
function Go-Server($s) {
    $qq = $script:q; if (-not $qq) { return }
    $qq.joining = $true; $qq.target = $s.key; $qq.joinDeadline = (Get-Date).AddSeconds(40)
    Write-Log "FOUND  versus game - $($s.humans)/$($s.max) players, $($s.ping) ms, $($s.map) - joining" $cGreen
    Set-Status "Game found - joining ..." "$($s.humans)/$($s.max) players  -  $($s.ping) ms  -  $($s.map)" $cGreen
    Play 'official'
    if ($cfg.party) { Publish "go" (Hide-Addr $s.key) }
    Connect-To $s.key
}
function Connect-To($key) {
    if ($script:q) { $script:q.connectAt = Get-Date }
    if ($script:client) { Send-Cmd "connect $key" }
    else {
        $script:pendingGo = @{ key = $key; until = (Get-Date).AddSeconds(90) }
        Write-Log "Start L4D2 - Waechter connects you as soon as the game is open" $cYellow
        Set-Status "Start L4D2 now" "Waechter connects you to the game automatically" $cYellow
    }
}
function Join-Failed($why) {
    $qq = $script:q; if (-not $qq -or -not $qq.joining) { return }
    $qq.joining = $false
    if ($qq.target) { $qq.failed[$qq.target] = 1; $script:badServers[$qq.target] = 1 }
    if ($qq.member) {
        Write-Log "Could not join the host's game ($why)" $cYellow
        Publish "joinfail" $why
        Stop-Queue $null
        Set-Status "Could not join the host's game" "The host searches a new game for everyone" $cYellow
        return
    }
    Write-Log "Could not join that game ($why) - trying the next one" $cYellow
    Pick-QueueServer
}
function Tick-Queue {
    if (-not $script:q -and -not $script:udp) { return }
    Pump-Udp
    $qq = $script:q; if (-not $qq) { return }
    if ($qq.scanning) {
        $now = Get-Date
        $end = [Math]::Min($qq.idx + 450, $qq.targets.Count)
        for ($k = $qq.idx; $k -lt $end; $k++) { $key = $qq.targets[$k]; $qq.sentAt[$key] = $now; Send-A2S $key $null }
        if ($end -gt $qq.idx) { $qq.lastSend = $now }
        $qq.idx = $end
        if ($qq.idx -ge $qq.targets.Count -and ($now - $qq.lastSend).TotalMilliseconds -ge 2500) { $qq.scanning = $false; Pick-QueueServer }
    } elseif ($qq.waitUntil -and (Get-Date) -ge $qq.waitUntil) {
        $qq.waitUntil = $null; Start-QueueScan
    }
    if ($qq.joining -and (Get-Date) -ge $qq.joinDeadline) { Join-Failed "no answer" }
}
function Queue-Joined {
    # called when the watcher confirms we are on an official server
    $qq = $script:q; if (-not $qq -or -not $qq.joining) { return }
    Write-Log "JOINED  official versus game" $cGreen
    $script:q = $null
    $btnQueue.Text = "QUEUE"; $btnQueue.BackColor = $cAccent
}
function Handle-QueueLine($line) {
    $qq = $script:q; if (-not $qq -or -not $qq.joining) { return }
    if ($line -match '(?i)unreserved|reservation') { return }
    if ($qq.connectAt -and ((Get-Date) - $qq.connectAt).TotalSeconds -lt 1.5) { return }
    if ($line -match '(?i)^\s*Disconnect:|server is full|connection rejected|lobby only|enforcing|#Valve_Reject|Connection failed') { Join-Failed "server refused" }
}

# ---------------- events ----------------
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 150
$timer.Add_Tick({ Pump-Game; Pump-Party; Tick-Queue })

$btnSteam.Add_Click({
    $script:steamName = Get-SteamName; Update-SteamLabel
    if ($script:steamName) { $txtName.Text = $script:steamName } else { [void][System.Windows.Forms.MessageBox]::Show("Steam name not found. Start Steam once and try again.", "Waechter") }
})
$txtName.Add_Leave({
    $cfg.name = $txtName.Text.Trim(); Save-Settings; Publish "status"; Refresh-Party
})
$btnCreate.Add_Click({ Join-Party (New-Code) $true })
$btnJoin.Add_Click({
    $code = $txtCode.Text.Trim().ToUpper()
    if ($code -notmatch '^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$') {
        [void][System.Windows.Forms.MessageBox]::Show("Enter a party code like ABCD-EFGH-JKLM.", "Waechter"); return
    }
    Join-Party $code $false
})
$btnCopy.Add_Click({
    if ($cfg.party) {
        $inv = "Join my Waechter party: waechter://join/$($cfg.party)  (or paste the code $($cfg.party) into Waechter)"
        [System.Windows.Forms.Clipboard]::SetText($inv)
        $script:lastOffered = $cfg.party
        Write-Log "Invite copied - paste it to your friend" $cMuted
    }
})
$btnLeave.Add_Click({ Leave-Party })
function Toggle-Ready {
    $script:myReady = -not $script:myReady
    Publish "status"
    Write-Log $(if ($script:myReady) { "You are ready" } else { "You are not ready" }) $(if ($script:myReady) { $cGreen } else { $cMuted })
    Refresh-Party
}
$btnReady.Add_Click({ Toggle-Ready })
$btnSend.Add_Click({ Send-Chat })
foreach ($rb in $reactBtns) {
    $rb.Add_Click({
        param($s, $e)
        if (-not $cfg.party) { Add-Chat "Waechter" "Join or create a party first." $cMuted; return }
        Publish "react" ([string]$s.Tag)
        Add-Chat $txtName.Text.Trim() ("reacted " + [string]$s.Tag) (Get-PersonColor $cfg.id)
    })
}
function Send-Countdown {
    if (-not $cfg.party) { Add-Chat "Waechter" "Join or create a party first." $cMuted; return }
    Publish "countdown" "10"
    Add-Chat $txtName.Text.Trim() "started a 10 s queue countdown" (Get-PersonColor $cfg.id)
    Start-Countdown 10 "You"
}
$btnCd.Add_Click({ Send-Countdown })
$btnQueue.Add_Click({ if ($script:q) { Stop-Queue "Queue cancelled"; Set-Status "Queue cancelled" "Press QUEUE to search again" $cMuted } else { Start-Queue } })
$btnQ1.Add_Click({ [void](Send-Text "Queue now") })
$btnQ2.Add_Click({ [void](Send-Text "2 min") })
$btnQ3.Add_Click({ [void](Send-Text "brb") })
$btnQ4.Add_Click({ [void](Send-Text "gg") })

# autostart with Windows (shortcut in the Startup folder, starts hidden in the tray)
$chkAuto.Add_CheckedChanged({
    try {
        if ($chkAuto.Checked) {
            $sh = New-Object -ComObject WScript.Shell
            $l = $sh.CreateShortcut($StartupLnk)
            $l.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
            $l.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Here\Waechter.ps1`" -Tray"
            $l.WorkingDirectory = $Here
            if (Test-Path $IconFile) { $l.IconLocation = "$IconFile,0" }
            $l.Save()
            Write-Log "Waechter will start with Windows (in the tray)" $cGreen
        } else {
            if (Test-Path $StartupLnk) { Remove-Item $StartupLnk -Force }
            Write-Log "Autostart off" $cMuted
        }
    } catch { Write-Log "Could not change autostart" $cRed }
})

function Offer-Join($code) {
    if ($cfg.party -eq $code) { Show-Main; return }
    $q = if ($cfg.party) { "Leave your current party and join $($code)?" } else { "Join party $($code)?" }
    if ([System.Windows.Forms.MessageBox]::Show($q, "Waechter", "YesNo", "Question") -eq "Yes") {
        if ($cfg.party) { Leave-Party }
        Join-Party $code $false
    }
}
$script:lastPendingCheck = Get-Date
$script:lastOffered = ""
$form.Add_Activated({
    try {
        if ([System.Windows.Forms.Clipboard]::ContainsText()) {
            $ct = [System.Windows.Forms.Clipboard]::GetText()
            if ($ct -match '([A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4})') {
                $code = $matches[1].ToUpper()
                if ($code -ne $script:lastOffered -and $code -ne $cfg.party) { $script:lastOffered = $code; Offer-Join $code }
            }
        }
    } catch { }
})

# host transfer (right-click a member)
$lvMenu = New-Object System.Windows.Forms.ContextMenuStrip
$miPromote = $lvMenu.Items.Add("Make host")
$lvParty.ContextMenuStrip = $lvMenu
$lvMenu.Add_Opening({
    param($s, $e)
    $sel = if ($lvParty.SelectedItems.Count) { $lvParty.SelectedItems[0] } else { $null }
    $miPromote.Enabled = [bool]($cfg.party -and $cfg.host -and $sel -and $sel.Tag -and $sel.Tag -ne $cfg.id)
})
$miPromote.Add_Click({
    if (-not $lvParty.SelectedItems.Count) { return }
    $sel = $lvParty.SelectedItems[0]
    if (-not $cfg.host -or -not $sel.Tag -or $sel.Tag -eq $cfg.id) { return }
    $target = [string]$sel.Tag
    Publish "promote" $target
    $cfg.host = $false; Save-Settings
    Publish "status"
    if ($script:members.ContainsKey($target)) { $script:members[$target].role = "host" }
    Write-Log "You made $($sel.Text) the host" $cMuted
    Refresh-Party
})

# volume
$trkVol.Add_MouseUp({ $cfg.vol = $trkVol.Value; Save-Settings; Load-Sounds; $script:memberSnd = @{}; Play 'click' })
$trkVol.Add_KeyUp({ $cfg.vol = $trkVol.Value; Save-Settings; Load-Sounds; $script:memberSnd = @{} })

# hotkeys: Ctrl+Shift+1..4 quick messages, Ctrl+Shift+R ready
$script:hkOk = $false
if ($script:hk) {
    $mods = [uint32](0x0002 -bor 0x0004 -bor 0x4000)
    $a = $script:hk.Add(1, $mods, 0x31); $b = $script:hk.Add(2, $mods, 0x32); $c3 = $script:hk.Add(3, $mods, 0x33)
    $d = $script:hk.Add(4, $mods, 0x34); $e5 = $script:hk.Add(5, $mods, 0x52); $f6 = $script:hk.Add(6, $mods, 0x35)
    $script:hkOk = ($a -and $b -and $c3 -and $d -and $e5 -and $f6)
}
$script:lastTimerUpdate = Get-Date
$timer2 = New-Object System.Windows.Forms.Timer
$timer2.Interval = 100
$timer2.Add_Tick({
    if ($script:hk) {
        while ($script:hk.Hits.Count -gt 0) {
            $id = $script:hk.Hits.Dequeue()
            switch ($id) {
                1 { [void](Send-Text "Queue now") }
                2 { [void](Send-Text "2 min") }
                3 { [void](Send-Text "brb") }
                4 { [void](Send-Text "gg") }
                5 { if ($cfg.party) { Toggle-Ready } }
                6 { Send-Countdown }
            }
            Play 'click'
        }
    }
    if ($script:myStatus -eq "Game closed" -and $script:closedSince -and ((Get-Date) - $script:closedSince).TotalMinutes -ge 5) {
        Set-MyStatus "AFK (game closed)"
    }
    if (((Get-Date) - $script:lastPendingCheck).TotalMilliseconds -ge 700) {
        $script:lastPendingCheck = Get-Date
        if (Test-Path $PendingFile) {
            $req = ""
            try { $req = (Get-Content $PendingFile -Raw).Trim(); Remove-Item $PendingFile -Force } catch { }
            if ($req -like "join *") { $jc = $req.Substring(5).Trim().ToUpper(); $script:lastOffered = $jc; Show-Main; Offer-Join $jc }
            elseif ($req -eq "show") { Show-Main }
        }
    }
    Tick-Countdown
    if ($script:searchStart -and ((Get-Date) - $script:lastTimerUpdate).TotalMilliseconds -ge 1000) {
        $script:lastTimerUpdate = Get-Date; Update-Timer
    }
})
$txtChat.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq "Enter") { $e.SuppressKeyPress = $true; Send-Chat } })
$chkOverlay.Add_CheckedChanged({
    $cfg.overlay = $chkOverlay.Checked; Save-Settings
    if ($chkOverlay.Checked) { $ov.Show(); Update-Overlay } else { $ov.Hide() }
})
$form.Add_Resize({
    if ($form.WindowState -eq "Minimized") {
        $form.Hide()
        if (-not $script:trayHint) { $script:trayHint = $true; try { $trayIcon.ShowBalloonTip(3000, "Waechter is still running", "Double-click the tray icon to open it again.", [System.Windows.Forms.ToolTipIcon]::Info) } catch { } }
    }
})
$btnRemove.Add_Click({
    $sel = $lstBlack.SelectedItem
    if ($sel) {
        Set-Content -Path $Blacklist -Value @(Get-Content $Blacklist | Where-Object { $_ -ne $sel })
        Refresh-Blacklist; Write-Log "Removed from blacklist" $cMuted
    }
})
$btnClear.Add_Click({
    if ([System.Windows.Forms.MessageBox]::Show("Clear the whole blacklist?", "Waechter", "YesNo", "Question") -eq "Yes") {
        Set-Content -Path $Blacklist -Value @(); Refresh-Blacklist; Write-Log "Blacklist cleared" $cMuted
    }
})
$btnFolder.Add_Click({ Start-Process explorer.exe $Here })
$chkSound.Add_CheckedChanged({ $cfg.sound = $chkSound.Checked; Save-Settings })
$chkActive.Add_CheckedChanged({
    Update-Overlay
    if ($chkActive.Checked) { Write-Log "Waechter active" $cGreen } else { Write-Log "Waechter paused - nothing gets kicked" $cYellow }
})
$form.Add_FormClosing({
    $timer.Stop(); $timer2.Stop()
    try { if ($script:hk) { $script:hk.Release() } } catch { }
    try { Show-Summary } catch { }
    try { $cfg.ox = $ov.Location.X; $cfg.oy = $ov.Location.Y; $ov.Close() } catch { }
    try { $trayIcon.Visible = $false; $trayIcon.Dispose() } catch { }
    if ($cfg.party) { $script:myStatus = "Offline"; Publish "status"; Start-Sleep -Milliseconds 400 }
    try { if ($script:client) { $script:client.Close() } } catch { }
    $cfg.name = $txtName.Text.Trim(); Save-Settings
})

# ---------------- start ----------------
Update-SteamLabel
Refresh-Recent
Refresh-Blacklist
Update-Stats
if ($cfg.party) { Join-Party $cfg.party ([bool]$cfg.host) } else { Refresh-Party }
Write-Log "Waechter v$AppVersion started" $cMuted
if ($script:updateNote) { Write-Log $script:updateNote $cMuted }
if ($chkOverlay.Checked) { $ov.Show(); Update-Overlay }
if ($script:hkOk) { Write-Log "Hotkeys: Ctrl+Shift+1-4 quick messages, +5 countdown, +R ready" $cMuted }
elseif ($script:hk) { Write-Log "Some hotkeys are used by another app and are not available" $cYellow }
else { Write-Log "Hotkeys not available on this PC" $cYellow }
$timer.Start(); $timer2.Start()
if (Test-Path $PendingFile) { try { Remove-Item $PendingFile -Force } catch { } }
$form.Add_Shown({
    if ($StartInTray) { $script:trayHint = $true; $form.Hide() }
    if ($JoinArg -match '([A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4})') { $jc = $matches[1].ToUpper(); $script:lastOffered = $jc; Offer-Join $jc }
})
[System.Windows.Forms.Application]::Run($form)
try { $script:mutex.ReleaseMutex(); $script:mutex.Dispose() } catch { }
