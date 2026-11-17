# Waechter - Left 4 Dead 2: official Valve servers only
# WAECHTER-APP
# Requires the Steam launch option:  -netconport 2121
param([switch]$Tray, [string]$Join = "")
$StartInTray = [bool]$Tray
$JoinArg = [string]$Join
$AppVersion = "1.3.1"
$UpdateRepo = "voenji/waechter"   # GitHub "user/repo" that hosts version.txt and Waechter.ps1 (empty = no updates)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http
[System.Windows.Forms.Application]::EnableVisualStyles()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Port      = 2121
$Relay     = "https://waechter-relay.l4d2compscene.workers.dev"
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
$cGlassA  = C 14 22 40      # dark blue panels (flat)
$cGlassB  = C 14 22 40
$cGlassLn = C 96 145 225
$cAccent  = C 29 70 180
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
$AllRegions = @("Europe", "North America", "South America", "Asia", "Oceania", "Other")
$cfg = @{ id = ""; name = ""; party = ""; host = $false; sound = $true; overlay = $false; ox = -1; oy = -1; vol = 70; recent = @();
          maxPing = 150; minPlayers = 2; regions = $AllRegions; pool = @() }
if (Test-Path $Settings) {
    try { $j = Get-Content $Settings -Raw | ConvertFrom-Json; foreach ($k in @('id','name','party','host','sound','overlay','ox','oy','vol','recent','maxPing','minPlayers','regions','pool')) { if ($j.$k -ne $null) { $cfg[$k] = $j.$k } } } catch { }
}
$cfg.regions = @($cfg.regions | ForEach-Object { [string]$_ }); $cfg.pool = @($cfg.pool | ForEach-Object { [string]$_ })
$cfg.maxPing = [Math]::Max(20, [Math]::Min(400, [int]$cfg.maxPing)); $cfg.minPlayers = [Math]::Max(1, [Math]::Min(7, [int]$cfg.minPlayers))
if (-not $cfg.id) { $cfg.id = ([guid]::NewGuid().ToString("N")).Substring(0, 12) }
function Add-Recent($code) {
    $list = @(@($cfg.recent) | Where-Object { $_ -and $_ -ne $code })
    $cfg.recent = @(@($code) + $list | Select-Object -First 6)
}
function Save-Settings { ($cfg | ConvertTo-Json -Depth 4) | Set-Content -Path $Settings -Encoding UTF8 }

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

# ---------------- map data (chapters) + images from the player's own L4D2 install ----------------
$Chapters = @(
    @("c1m1_hotel","Hotel","Dead Center"), @("c1m2_streets","Streets","Dead Center"), @("c1m3_mall","Mall","Dead Center"), @("c1m4_atrium","Atrium","Dead Center"),
    @("c2m1_highway","Highway","Dark Carnival"), @("c2m2_fairgrounds","Fairground","Dark Carnival"), @("c2m3_coaster","Coaster","Dark Carnival"), @("c2m4_barns","Barns","Dark Carnival"), @("c2m5_concert","Concert","Dark Carnival"),
    @("c3m1_plankcountry","Plank Country","Swamp Fever"), @("c3m2_swamp","Swamp","Swamp Fever"), @("c3m3_shantytown","Shanty Town","Swamp Fever"), @("c3m4_plantation","Plantation","Swamp Fever"),
    @("c4m1_milltown_a","Mill Town","Hard Rain"), @("c4m2_sugarmill_a","Sugar Mill","Hard Rain"), @("c4m3_sugarmill_b","Mill Escape","Hard Rain"), @("c4m4_milltown_b","Return to Town","Hard Rain"), @("c4m5_milltown_escape","Town Escape","Hard Rain"),
    @("c5m1_waterfront","Waterfront","The Parish"), @("c5m2_park","Park","The Parish"), @("c5m3_cemetery","Cemetery","The Parish"), @("c5m4_quarter","Quarter","The Parish"), @("c5m5_bridge","Bridge","The Parish"),
    @("c6m1_riverbank","Riverbank","The Passing"), @("c6m2_bedlam","Underground","The Passing"), @("c6m3_port","Port","The Passing"),
    @("c7m1_docks","Docks","The Sacrifice"), @("c7m2_barge","Barge","The Sacrifice"), @("c7m3_port","Port","The Sacrifice"),
    @("c8m1_apartment","Apartments","No Mercy"), @("c8m2_subway","Subway","No Mercy"), @("c8m3_sewers","Sewer","No Mercy"), @("c8m4_interior","Hospital","No Mercy"), @("c8m5_rooftop","Rooftop","No Mercy"),
    @("c9m1_alleys","Alleys","Crash Course"), @("c9m2_lots","Truck Depot","Crash Course"),
    @("c10m1_caves","Turnpike","Death Toll"), @("c10m2_drainage","Drains","Death Toll"), @("c10m3_ranchhouse","Church","Death Toll"), @("c10m4_mainstreet","Town","Death Toll"), @("c10m5_houseboat","Boathouse","Death Toll"),
    @("c11m1_greenhouse","Greenhouse","Dead Air"), @("c11m2_offices","Crane","Dead Air"), @("c11m3_garage","Construction Site","Dead Air"), @("c11m4_terminal","Terminal","Dead Air"), @("c11m5_runway","Runway","Dead Air"),
    @("c12m1_hilltop","Forest","Blood Harvest"), @("c12m2_traintunnel","Tunnel","Blood Harvest"), @("c12m3_bridge","Bridge","Blood Harvest"), @("c12m4_barn","Train Yard","Blood Harvest"), @("c12m5_cornfield","Farmhouse","Blood Harvest"),
    @("c13m1_alpinecreek","Alpine Creek","Cold Stream"), @("c13m2_southpinestream","South Pine Stream","Cold Stream"), @("c13m3_memorialbridge","Memorial Bridge","Cold Stream"), @("c13m4_cutthroatcreek","Cut-throat Creek","Cold Stream"),
    @("c14m1_junkyard","Junkyard","The Last Stand"), @("c14m2_lighthouse","Lighthouse","The Last Stand")
)
$ChapterInfo = @{}
foreach ($c in $Chapters) { $ChapterInfo[$c[0]] = @{ name = $c[1]; camp = $c[2] } }
$ImgAlias = @{ c7m1_docks = "l4d_river01_docks"; c7m2_barge = "l4d_river02_barge"; c7m3_port = "l4d_river03_port";
               c8m1_apartment = "l4d_hospital01_apartment"; c8m2_subway = "l4d_hospital02_subway"; c8m3_sewers = "l4d_hospital03_sewers";
               c8m4_interior = "l4d_hospital04_interior"; c8m5_rooftop = "l4d_hospital05_rooftop" }
function Get-MapLabel($map) {
    $m = ([string]$map).ToLower()
    if ($ChapterInfo.ContainsKey($m)) { return "$($ChapterInfo[$m].camp) - $($ChapterInfo[$m].name)" }
    return [string]$map
}
function Get-Region($name) {
    $n = [string]$name
    if ($n -match '(?i)Frankfurt|Falkenstein|Helsinki|EU |Europe|Spain|Madrid|Stockholm|Luxembourg|Vienna|Austria|Poland|Warsaw|Amsterdam|London|Paris|Germany|Sweden|Finland') { return "Europe" }
    if ($n -match '(?i)US |USA|Virginia|Sterling|Seattle|Washington|Chicago|Dallas|Atlanta|Los Angeles|Canada|America') { return "North America" }
    if ($n -match '(?i)Brazil|Sao Paulo|Chile|Peru|Argentina|South America') { return "South America" }
    if ($n -match '(?i)Hong Kong|Singapore|Japan|Tokyo|Korea|Seoul|India|Mumbai|Chennai|China|Asia|Dubai') { return "Asia" }
    if ($n -match '(?i)Australia|Sydney|Oceania|Guam') { return "Oceania" }
    return "Other"
}
function Get-RegionShort($name) {
    $n = [string]$name -replace '^Valve Left ?4 ?Dead ?2?\s*', '' -replace '\s*\(.*$', '' -replace '\s*Server$', ''
    if (-not $n) { $n = Get-Region $name }
    return $n.Trim()
}

$script:vpkReady = $false
try {
    Add-Type -IgnoreWarnings -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.IO; using System.Text; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class WaechterVpk {
    class Entry { public ushort Arch; public uint Off; public uint Len; public byte[] Pre; }
    class Dir { public string Path; public int Hdr; public uint Tree; public Dictionary<string, Entry> E = new Dictionary<string, Entry>(); }
    static List<Dir> dirs = new List<Dir>();
    static string ReadZ(BinaryReader r) { var b = new List<byte>(); byte c; while ((c = r.ReadByte()) != 0) b.Add(c); return Encoding.GetEncoding(28591).GetString(b.ToArray()); }
    public static int Open(string path, string prefix) {
        var d = new Dir(); d.Path = path;
        using (var f = File.OpenRead(path)) using (var r = new BinaryReader(f)) {
            uint sig = r.ReadUInt32(); uint ver = r.ReadUInt32(); d.Tree = r.ReadUInt32();
            if (sig != 0x55aa1234) return 0;
            if (ver == 2) { r.ReadBytes(16); d.Hdr = 28; } else d.Hdr = 12;
            while (true) { string ext = ReadZ(r); if (ext == "") break;
                while (true) { string dir = ReadZ(r); if (dir == "") break;
                    while (true) { string name = ReadZ(r); if (name == "") break;
                        r.ReadUInt32(); ushort pre = r.ReadUInt16(); ushort arch = r.ReadUInt16(); uint off = r.ReadUInt32(); uint len = r.ReadUInt32(); r.ReadUInt16();
                        byte[] pb = pre > 0 ? r.ReadBytes(pre) : new byte[0];
                        string full = ((dir.Trim() == "") ? "" : dir.Trim() + "/") + name + "." + ext;
                        full = full.ToLowerInvariant();
                        if (full.StartsWith(prefix) && !d.E.ContainsKey(full)) { var e = new Entry(); e.Arch = arch; e.Off = off; e.Len = len; e.Pre = pb; d.E[full] = e; }
                    } } } }
        dirs.Add(d); return d.E.Count;
    }
    public static byte[] Read(string key) {
        key = key.ToLowerInvariant();
        foreach (var d in dirs) { Entry e; if (!d.E.TryGetValue(key, out e)) continue;
            var ms = new MemoryStream(); ms.Write(e.Pre, 0, e.Pre.Length);
            if (e.Len > 0) {
                string ap = e.Arch == 0x7fff ? d.Path : d.Path.Substring(0, d.Path.Length - 7) + e.Arch.ToString("000") + ".vpk";
                long off = e.Arch == 0x7fff ? d.Hdr + d.Tree + e.Off : e.Off;
                using (var f = File.OpenRead(ap)) { f.Seek(off, SeekOrigin.Begin); var buf = new byte[e.Len]; int n = 0; while (n < buf.Length) { int k = f.Read(buf, n, buf.Length - n); if (k <= 0) break; n += k; } ms.Write(buf, 0, n); }
            }
            return ms.ToArray(); }
        return null;
    }
    static int MipBytes(int fmt, int w, int h) { w = Math.Max(1, w); h = Math.Max(1, h); int bw = Math.Max(1, (w + 3) / 4), bh = Math.Max(1, (h + 3) / 4);
        switch (fmt) { case 13: return bw * bh * 8; case 14: case 15: return bw * bh * 16; case 0: case 1: case 11: case 12: case 16: return w * h * 4; case 2: case 3: return w * h * 3; default: return -1; } }
    static void C565(int c, out int r, out int g, out int b) { r = ((c >> 11) & 31) * 255 / 31; g = ((c >> 5) & 63) * 255 / 63; b = (c & 31) * 255 / 31; }
    public static Bitmap DecodeVtf(byte[] d) {
        if (d == null || d.Length < 80 || d[0] != 'V' || d[1] != 'T' || d[2] != 'F') return null;
        int minor = BitConverter.ToInt32(d, 8), hs = BitConverter.ToInt32(d, 12);
        int w = BitConverter.ToUInt16(d, 16), h = BitConverter.ToUInt16(d, 18), frames = Math.Max(1, (int)BitConverter.ToUInt16(d, 24));
        int fmt = BitConverter.ToInt32(d, 52), mips = d[56], lfmt = BitConverter.ToInt32(d, 57), lw = d[61], lh = d[62];
        int hi = -1;
        if (minor >= 3) { int n = BitConverter.ToInt32(d, 68); for (int i = 0; i < n && 80 + i * 8 + 8 <= d.Length; i++) { int p = 80 + i * 8; if (d[p] == 0x30 && d[p + 1] == 0 && d[p + 2] == 0) { hi = BitConverter.ToInt32(d, p + 4); break; } } }
        if (hi < 0) { int ls = (lfmt < 0 || lw == 0) ? 0 : Math.Max(0, MipBytes(lfmt, lw, lh)); hi = hs + ls; }
        int top = MipBytes(fmt, w, h); if (top < 0) return null;
        int pos = hi; for (int m = mips - 1; m >= 1; m--) pos += MipBytes(fmt, w >> m, h >> m) * frames;
        if (pos + top > d.Length) pos = d.Length - top; if (pos < 0) return null;
        int[] px = new int[w * h];
        if (fmt == 13 || fmt == 14 || fmt == 15) {
            int bs = fmt == 13 ? 8 : 16, i = pos;
            for (int by = 0; by < h; by += 4) for (int bx = 0; bx < w; bx += 4) {
                int ci = fmt == 13 ? i : i + 8;
                int c0 = BitConverter.ToUInt16(d, ci), c1 = BitConverter.ToUInt16(d, ci + 2); uint bits = BitConverter.ToUInt32(d, ci + 4);
                int r0, g0, b0, r1, g1, b1; C565(c0, out r0, out g0, out b0); C565(c1, out r1, out g1, out b1);
                int[] cr = new int[4], cg = new int[4], cb = new int[4]; int[] ca = { 255, 255, 255, 255 };
                cr[0] = r0; cg[0] = g0; cb[0] = b0; cr[1] = r1; cg[1] = g1; cb[1] = b1;
                if (c0 > c1 || fmt != 13) { cr[2] = (2 * r0 + r1) / 3; cg[2] = (2 * g0 + g1) / 3; cb[2] = (2 * b0 + b1) / 3; cr[3] = (r0 + 2 * r1) / 3; cg[3] = (g0 + 2 * g1) / 3; cb[3] = (b0 + 2 * b1) / 3; }
                else { cr[2] = (r0 + r1) / 2; cg[2] = (g0 + g1) / 2; cb[2] = (b0 + b1) / 2; cr[3] = 0; cg[3] = 0; cb[3] = 0; ca[3] = 0; }
                for (int j = 0; j < 16; j++) { int x = bx + (j & 3), y = by + (j >> 2); if (x >= w || y >= h) continue;
                    int k = (int)((bits >> (2 * j)) & 3); px[y * w + x] = (255 << 24) | (cr[k] << 16) | (cg[k] << 8) | cb[k]; }
                i += bs; }
        } else {
            int bpp = (fmt == 2 || fmt == 3) ? 3 : 4;
            for (int p = 0; p < w * h; p++) { int o = pos + p * bpp; int r, g, b;
                if (fmt == 0 || fmt == 2) { r = d[o]; g = d[o + 1]; b = d[o + 2]; }
                else if (fmt == 1) { r = d[o + 3]; g = d[o + 2]; b = d[o + 1]; }
                else if (fmt == 11) { r = d[o + 1]; g = d[o + 2]; b = d[o + 3]; }
                else { b = d[o]; g = d[o + 1]; r = d[o + 2]; }
                px[p] = (255 << 24) | (r << 16) | (g << 8) | b; }
        }
        var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        var bd = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        Marshal.Copy(px, 0, bd.Scan0, px.Length); bmp.UnlockBits(bd);
        return bmp;
    }
}
"@
    $script:vpkReady = $true
} catch { $script:vpkReady = $false; $script:vpkError = $_.Exception.Message }

function Find-L4D2 {
    $cands = @()
    $cands += (Split-Path -Parent $Here)
    try {
        $sp = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction Stop).SteamPath
        if ($sp) {
            $cands += (Join-Path $sp "steamapps\common\Left 4 Dead 2")
            $lf = Join-Path $sp "steamapps\libraryfolders.vdf"
            if (Test-Path $lf) { foreach ($mm in [regex]::Matches((Get-Content $lf -Raw), '"path"\s+"([^"]+)"')) { $cands += (Join-Path ($mm.Groups[1].Value -replace '\\\\', '\') "steamapps\common\Left 4 Dead 2") } }
        }
    } catch { }
    $cands += "C:\Program Files (x86)\Steam\steamapps\common\Left 4 Dead 2"
    foreach ($c in $cands) { if ($c -and (Test-Path (Join-Path $c "left4dead2\pak01_dir.vpk"))) { return $c } }
    return $null
}
$MapCache = Join-Path $Here "mapcache"
$script:mapImages = @{}
function Load-MapImages {
    if (-not (Test-Path $MapCache)) { New-Item -ItemType Directory -Path $MapCache | Out-Null }
    $missing = @($Chapters | Where-Object { -not (Test-Path (Join-Path $MapCache "$($_[0]).png")) })
    if ($missing.Count -and $script:vpkReady) {
        $game = Find-L4D2
        if ($game) {
            foreach ($sub in @("update", "left4dead2_dlc3", "left4dead2_dlc2", "left4dead2_dlc1", "left4dead2")) {
                $vp = Join-Path $game "$sub\pak01_dir.vpk"
                if (Test-Path $vp) { try { [void][WaechterVpk]::Open($vp, "materials/vgui/maps/") } catch { } }
            }
            foreach ($c in $missing) {
                $id = $c[0]; $img = $null
                $names = @($id); if ($ImgAlias.ContainsKey($id)) { $names += $ImgAlias[$id] }; $names += ($id -replace 'm\d+_.*$', '')
                foreach ($nm in $names) {
                    try { $img = [WaechterVpk]::DecodeVtf([WaechterVpk]::Read("materials/vgui/maps/$nm.vtf")) } catch { $img = $null }
                    if ($img) { break }
                }
                if ($img) { try { $img.Save((Join-Path $MapCache "$id.png"), [System.Drawing.Imaging.ImageFormat]::Png) } catch { }; $img.Dispose() }
            }
        }
    }
    foreach ($c in $Chapters) {
        $f = Join-Path $MapCache "$($c[0]).png"
        if (Test-Path $f) { try { $ms = New-Object System.IO.MemoryStream(,[System.IO.File]::ReadAllBytes($f)); $script:mapImages[$c[0]] = [System.Drawing.Image]::FromStream($ms) } catch { } }
    }
}

# ---------------- window (sidebar + pages) ----------------
$cSide    = C 22 24 28
$cNavHot  = C 44 48 56
$cLine    = C 58 61 68
$fNav     = New-Object System.Drawing.Font("Segoe UI Semibold", 10.5)
$fPage    = New-Object System.Drawing.Font("Segoe UI Semibold", 18)
$fTile    = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$fCamp    = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
$fQueue   = New-Object System.Drawing.Font("Segoe UI Semibold", 13)

$form = New-Object System.Windows.Forms.Form
$form.Text = "Waechter"
$form.ClientSize = New-Object System.Drawing.Size(1080, 720)
$form.BackColor = $cBg; $form.ForeColor = $cText; $form.Font = $fMain
$form.FormBorderStyle = "FixedSingle"; $form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"
if (Test-Path $IconFile) { $form.Icon = New-Object System.Drawing.Icon($IconFile) }

# --- sidebar ---
$side = New-Object System.Windows.Forms.Panel
$side.Location = New-Object System.Drawing.Point(0, 0); $side.Size = New-Object System.Drawing.Size(220, 720)
$side.BackColor = $cSide
$side.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen($cLine, 1)
    $e.Graphics.DrawLine($pen, $s.Width - 1, 0, $s.Width - 1, $s.Height)
})
$form.Controls.Add($side)
$pic = New-Object System.Windows.Forms.PictureBox
$pic.Location = New-Object System.Drawing.Point(20, 22); $pic.Size = New-Object System.Drawing.Size(42, 42)
$pic.SizeMode = "Zoom"; $pic.BackColor = [System.Drawing.Color]::Transparent
$LogoPng = Join-Path $Here "waechter_logo.png"; if (Test-Path $LogoPng) { $pic.Image = [System.Drawing.Image]::FromFile($LogoPng) }
$side.Controls.Add($pic)
$side.Controls.Add((New-Label "WAECHTER" 70 20 150 28 (New-Object System.Drawing.Font("Segoe UI Semibold", 15)) $cText))
$side.Controls.Add((New-Label "L4D2  -  official only  -  v$AppVersion" 71 48 150 18 (New-Object System.Drawing.Font("Segoe UI", 7.5)) (C 160 180 215)))

$script:navButtons = @{}; $script:pages = @{}
$navY = 100
foreach ($nv in @(@("play", "Play", 0x25B6), @("servers", "Servers", 0x2630), @("party", "Party", 0x263A), @("activity", "Activity", 0x2261), @("settings", "Settings", 0x2699))) {
    $nb = New-Object System.Windows.Forms.Button
    $nb.Text = ([string][char]$nv[2]) + "   " + $nv[1]; $nb.Tag = $nv[0]
    $nb.Location = New-Object System.Drawing.Point(12, $navY); $nb.Size = New-Object System.Drawing.Size(196, 40)
    $nb.FlatStyle = "Flat"; $nb.FlatAppearance.BorderSize = 0; $nb.FlatAppearance.MouseOverBackColor = $cNavHot
    $nb.TextAlign = "MiddleLeft"; $nb.Padding = New-Object System.Windows.Forms.Padding(12, 0, 0, 0)
    $nb.BackColor = $cSide; $nb.ForeColor = (C 200 205 215); $nb.Font = $fNav
    $nb.Cursor = [System.Windows.Forms.Cursors]::Hand
    Set-Round $nb 8
    $nb.Add_MouseEnter({ Play 'hover' }); $nb.Add_MouseDown({ Play 'click' })
    $nb.Add_Click({ param($s, $e) Show-Page ([string]$s.Tag) })
    $side.Controls.Add($nb); $script:navButtons[$nv[0]] = $nb
    $navY += 46
}
# sidebar footer: live status
$side.Controls.Add((New-Label "STATUS" 22 560 100 16 (New-Object System.Drawing.Font("Segoe UI Semibold", 8)) $cMuted))
$lblSideDot = New-Label ([string][char]0x25CF) 18 576 24 26 (New-Object System.Drawing.Font("Segoe UI", 13)) $cYellow
$lblSideStatus = New-Label "Waiting for L4D2" 42 580 172 20 $fSmall $cText
$lblSideParty = New-Label "" 42 600 172 18 $fSmall $cMuted
$lblSteam = New-Label "" 22 680 190 18 (New-Object System.Drawing.Font("Segoe UI", 8)) $cMuted
$side.Controls.AddRange(@($lblSideDot, $lblSideStatus, $lblSideParty, $lblSteam))

function New-Page($key, $title) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = New-Object System.Drawing.Point(220, 0); $p.Size = New-Object System.Drawing.Size(860, 720)
    $p.BackColor = $cBg; $p.Visible = $false
    $p.Controls.Add((New-Label $title 28 18 500 36 $fPage $cText))
    $form.Controls.Add($p); $script:pages[$key] = $p
    return $p
}
function Set-DarkList($lv) {
    $lv.OwnerDraw = $true
    $lv.Add_DrawColumnHeader({
        param($s, $e)
        $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush((C 34 36 40))), $e.Bounds)
        $sf = New-Object System.Drawing.StringFormat; $sf.LineAlignment = "Center"
        $r = New-Object System.Drawing.RectangleF(($e.Bounds.X + 6), $e.Bounds.Y, ($e.Bounds.Width - 6), $e.Bounds.Height)
        $e.Graphics.DrawString($e.Header.Text, $fSmall, (New-Object System.Drawing.SolidBrush($cMuted)), $r, $sf)
    })
    $lv.Add_DrawItem({ param($s, $e) $e.DrawDefault = $true })
    $lv.Add_DrawSubItem({ param($s, $e) $e.DrawDefault = $true })
}
function Show-Page($key) {
    foreach ($k in @($script:pages.Keys)) { $script:pages[$k].Visible = ($k -eq $key) }
    foreach ($k in @($script:navButtons.Keys)) {
        $b = $script:navButtons[$k]
        if ($k -eq $key) { $b.BackColor = (C 24 52 120); $b.ForeColor = $cText } else { $b.BackColor = $cSide; $b.ForeColor = (C 200 205 215) }
    }
    $script:currentPage = $key
    if ($key -eq "servers" -and -not $script:lastScanAt -and -not ($script:scan -and -not $script:scan.done)) { [void](Start-Scan) }
}
function New-SliderRow($parent, $label, $x, $y, $min, $max, $val) {
    $parent.Controls.Add((New-Label $label $x $y 120 20 $fSmall (C 191 210 240)))
    $t = New-Object System.Windows.Forms.TrackBar
    $t.AutoSize = $false; $t.Location = New-Object System.Drawing.Point(($x + 118), ($y - 3)); $t.Size = New-Object System.Drawing.Size(190, 26)
    $t.Minimum = $min; $t.Maximum = $max; $t.TickStyle = "None"; $t.BackColor = $parent.BackColor
    $t.Value = [Math]::Max($min, [Math]::Min($max, [int]$val))
    $parent.Controls.Add($t)
    $v = New-Label "" ($x + 312) $y 70 20 $fHead $cText
    $parent.Controls.Add($v)
    return @($t, $v)
}

# ================= PLAY =================
$pgPlay = New-Page "play" "Play"
$gStatus = New-Glass 28 64 804 118
$pgPlay.Controls.Add($gStatus)
$lblDot    = New-Label ([string][char]0x25CF) 16 28 40 44 $fDot $cYellow
$lblStatus = New-Label "Waiting for L4D2 ..." 60 24 520 30 $fStat $cText
$lblServer = New-Label "Launch option -netconport 2121 required" 62 58 520 48 $fSmall (C 191 210 240)
$lblTimer  = New-Label "" 600 10 188 18 $fSmall (C 191 210 240)
$lblTimer.TextAlign = "MiddleRight"
$btnQueue = New-Button "QUEUE" 608 38 180 $true
$btnQueue.Size = New-Object System.Drawing.Size(180, 50); $btnQueue.Font = $fQueue; Set-Round $btnQueue 10
$gStatus.Controls.AddRange(@($lblDot, $lblStatus, $lblServer, $lblTimer, $btnQueue))
$lblStats = New-Label "Checked 0   |   Official 0   |   Blocked 0" 30 188 500 20 $fSmall $cMuted
$pgPlay.Controls.Add($lblStats)

$cFilter = New-Card 28 214 804 104
$pgPlay.Controls.Add($cFilter)
$cFilter.Controls.Add((New-Label "FILTERS" 16 10 200 20 $fHead $cText))
$rowPing = New-SliderRow $cFilter "Max ping" 16 42 2 40 ([int]($cfg.maxPing / 10))
$trkPing = $rowPing[0]; $lblPingVal = $rowPing[1]
$rowMin = New-SliderRow $cFilter "Min. players" 16 72 1 7 $cfg.minPlayers
$trkMin = $rowMin[0]; $lblMinVal = $rowMin[1]
$cFilter.Controls.Add((New-Label "Regions" 420 12 100 18 $fSmall (C 191 210 240)))
$script:regionChecks = @()
$rx2 = 420; $ry2 = 34; $ri = 0
foreach ($rg in $AllRegions) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $rg; $cb.Tag = $rg; $cb.Checked = (@($cfg.regions) -contains $rg)
    $cb.Location = New-Object System.Drawing.Point(($rx2 + ($ri % 3) * 125), ($ry2 + [Math]::Floor($ri / 3) * 28))
    $cb.Size = New-Object System.Drawing.Size(122, 24); $cb.ForeColor = $cText; $cb.BackColor = $cCard; $cb.Font = $fSmall
    $cFilter.Controls.Add($cb); $script:regionChecks += $cb; $ri++
}

$cPool = New-Card 28 328 804 376
$pgPlay.Controls.Add($cPool)
$cPool.Controls.Add((New-Label "MAP POOL" 16 12 100 22 $fHead $cText))
$lblPoolInfo = New-Label "" 130 14 250 20 $fSmall $cMuted
$cPool.Controls.Add($lblPoolInfo)
$cPool.Controls.Add((New-Label "Search" 384 13 50 20 $fSmall (C 191 210 240)))
$txtMapSearch = New-Input 436 9 184
$cPool.Controls.Add($txtMapSearch)
$btnPoolAll  = New-Button "All" 628 8 76
$btnPoolNone = New-Button "Clear" 710 8 78
$cPool.Controls.AddRange(@($btnPoolAll, $btnPoolNone))
$flowPool = New-Object System.Windows.Forms.FlowLayoutPanel
$flowPool.Location = New-Object System.Drawing.Point(12, 48); $flowPool.Size = New-Object System.Drawing.Size(784, 318)
$flowPool.AutoScroll = $true; $flowPool.BackColor = $cCard; $flowPool.WrapContents = $true
$cPool.Controls.Add($flowPool)

# ================= SERVERS =================
$pgServers = New-Page "servers" "Servers"
$pgServers.Controls.Add((New-Label "Official Valve servers only" 30 54 400 18 $fSmall $cMuted))
$btnRefresh = New-Button "Refresh" 28 80 110 $true
$chkSvVersus = New-Object System.Windows.Forms.CheckBox
$chkSvVersus.Text = "Versus only"; $chkSvVersus.Checked = $true
$chkSvVersus.Location = New-Object System.Drawing.Point(152, 86); $chkSvVersus.Size = New-Object System.Drawing.Size(110, 22); $chkSvVersus.ForeColor = $cText; $chkSvVersus.Font = $fSmall
$chkSvEmpty = New-Object System.Windows.Forms.CheckBox
$chkSvEmpty.Text = "Hide empty"; $chkSvEmpty.Checked = $true
$chkSvEmpty.Location = New-Object System.Drawing.Point(266, 86); $chkSvEmpty.Size = New-Object System.Drawing.Size(110, 22); $chkSvEmpty.ForeColor = $cText; $chkSvEmpty.Font = $fSmall
$lblSvMap = New-Label "Map" 382 88 34 20 $fSmall (C 191 210 240)
$cmbSvMap = New-Object System.Windows.Forms.ComboBox
$cmbSvMap.DropDownStyle = "DropDownList"; $cmbSvMap.FlatStyle = "Flat"; $cmbSvMap.MaxDropDownItems = 20
$cmbSvMap.Location = New-Object System.Drawing.Point(418, 84); $cmbSvMap.Size = New-Object System.Drawing.Size(200, 26)
$cmbSvMap.BackColor = $cInput; $cmbSvMap.ForeColor = $cText; $cmbSvMap.Font = $fSmall
$script:svMapKeys = @("")
[void]$cmbSvMap.Items.Add("All maps")
$lastC = ""
foreach ($c in $Chapters) {
    if ($c[2] -ne $lastC) { $lastC = $c[2]; [void]$cmbSvMap.Items.Add($c[2]); $script:svMapKeys += ("camp:" + $c[2]) }
    [void]$cmbSvMap.Items.Add("      " + $c[1]); $script:svMapKeys += $c[0]
}
$cmbSvMap.SelectedIndex = 0
$lblSvInfo = New-Label "Press Refresh to load the server list" 626 88 206 20 (New-Object System.Drawing.Font("Segoe UI", 8)) $cMuted
$lblSvInfo.TextAlign = "MiddleRight"
$pgServers.Controls.AddRange(@($btnRefresh, $chkSvVersus, $chkSvEmpty, $lblSvMap, $cmbSvMap, $lblSvInfo))
$lvServers = New-Object System.Windows.Forms.ListView
$lvServers.Location = New-Object System.Drawing.Point(28, 122); $lvServers.Size = New-Object System.Drawing.Size(540, 582)
$lvServers.View = "Details"; $lvServers.FullRowSelect = $true; $lvServers.MultiSelect = $false; $lvServers.HideSelection = $false
$lvServers.BackColor = $cCard; $lvServers.ForeColor = $cText; $lvServers.BorderStyle = "None"; $lvServers.Font = $fSmall
[void]$lvServers.Columns.Add("Server", 120); [void]$lvServers.Columns.Add("Map", 200); [void]$lvServers.Columns.Add("Mode", 70); [void]$lvServers.Columns.Add("Players", 66); [void]$lvServers.Columns.Add("Ping", -2)
$pgServers.Controls.Add($lvServers)
Set-DarkList $lvServers
$cSvSide = New-Card 580 122 252 582
$pgServers.Controls.Add($cSvSide)
$picSv = New-Object System.Windows.Forms.PictureBox
$picSv.Location = New-Object System.Drawing.Point(12, 12); $picSv.Size = New-Object System.Drawing.Size(228, 114); $picSv.SizeMode = "Zoom"; $picSv.BackColor = $cInput
$lblSvName = New-Label "Select a server" 12 132 228 22 $fHead $cText
$lblSvMeta = New-Label "" 12 156 228 54 $fSmall (C 191 210 240)
$btnSvJoin = New-Button "Join" 12 214 110 $true
$btnSvPing = New-Button "Ping test" 130 214 110
$cSvSide.Controls.AddRange(@($picSv, $lblSvName, $lblSvMeta, $btnSvJoin, $btnSvPing))
$cSvSide.Controls.Add((New-Label "PLAYERS" 12 258 120 20 $fHead $cText))
$btnSvPlayers = New-Button "Load" 160 254 80
$cSvSide.Controls.Add($btnSvPlayers)
$lvPlayers = New-Object System.Windows.Forms.ListView
$lvPlayers.Location = New-Object System.Drawing.Point(12, 290); $lvPlayers.Size = New-Object System.Drawing.Size(228, 280)
$lvPlayers.View = "Details"; $lvPlayers.FullRowSelect = $true; $lvPlayers.BackColor = $cCard; $lvPlayers.ForeColor = $cText; $lvPlayers.BorderStyle = "None"; $lvPlayers.Font = $fSmall
[void]$lvPlayers.Columns.Add("Name", 120); [void]$lvPlayers.Columns.Add("Score", 46); [void]$lvPlayers.Columns.Add("Time", -2)
$cSvSide.Controls.Add($lvPlayers)
Set-DarkList $lvPlayers

# ================= PARTY =================
$pgParty = New-Page "party" "Party"
$gParty = New-Glass 28 64 804 290
$pgParty.Controls.Add($gParty)
$gParty.Controls.Add((New-Label "YOUR PARTY" 16 12 200 22 $fHead $cText))
$lblPartyState = New-Label "Not in a party" 420 14 368 20 $fSmall (C 191 210 240)
$lblPartyState.TextAlign = "MiddleRight"
$gParty.Controls.Add($lblPartyState)
$gParty.Controls.Add((New-Label "Name" 16 44 60 20 $fSmall (C 191 210 240)))
$txtName = New-Input 16 64 228
$txtName.Text = $cfg.name
$gParty.Controls.Add($txtName)
$btnSteam = New-Button "Use Steam name" 252 62 130
$gParty.Controls.Add($btnSteam)
$btnCreate = New-Button "Create party" 16 106 130 $true
$txtCode   = New-Object System.Windows.Forms.ComboBox
$txtCode.Location = New-Object System.Drawing.Point(154, 108); $txtCode.Size = New-Object System.Drawing.Size(140, 28)
$txtCode.DropDownStyle = "DropDown"; $txtCode.FlatStyle = "Flat"
$txtCode.BackColor = $cInput; $txtCode.ForeColor = $cText; $txtCode.Font = $fMain
function Refresh-Recent {
    $txtCode.Items.Clear()
    foreach ($r in @($cfg.recent)) { if ($r) { [void]$txtCode.Items.Add([string]$r) } }
}
$btnJoin   = New-Button "Join" 302 106 80
$gParty.Controls.AddRange(@($btnCreate, $txtCode, $btnJoin))
$lblCodeT = New-Label "Party code" 16 152 100 20 $fSmall (C 191 210 240)
$lblCode  = New-Label "-" 16 172 170 26 $fCode $cText
$btnReady = New-Button "Ready" 16 210 116
$btnCopy  = New-Button "Invite" 140 210 116
$btnLeave = New-Button "Leave" 264 210 118
$gParty.Controls.AddRange(@($lblCodeT, $lblCode, $btnReady, $btnCopy, $btnLeave))
$gParty.Controls.Add((New-Label "Max. 4 players. The host presses QUEUE - everyone gets connected." 16 252 380 30 (New-Object System.Drawing.Font("Segoe UI", 8)) (C 160 180 215)))
$lvParty = New-Object System.Windows.Forms.ListView
$lvParty.Location = New-Object System.Drawing.Point(404, 44); $lvParty.Size = New-Object System.Drawing.Size(384, 230)
$lvParty.View = "Details"; $lvParty.FullRowSelect = $true; $lvParty.HeaderStyle = "None"
$lvParty.BackColor = $cGlassB; $lvParty.ForeColor = $cText; $lvParty.BorderStyle = "None"; $lvParty.Font = $fSmall
[void]$lvParty.Columns.Add("Name", 135); [void]$lvParty.Columns.Add("Role", 45); [void]$lvParty.Columns.Add("Ready", 55); [void]$lvParty.Columns.Add("Status", 140)
$gParty.Controls.Add($lvParty)

$gChat = New-Glass 28 366 804 338
$pgParty.Controls.Add($gChat)
$gChat.Controls.Add((New-Label "PARTY CHAT" 16 10 200 22 $fHead $cText))
$chat = New-Object System.Windows.Forms.RichTextBox
$chat.Location = New-Object System.Drawing.Point(16, 40); $chat.Size = New-Object System.Drawing.Size(772, 236)
$chat.BackColor = $cGlassB; $chat.ForeColor = $cText; $chat.Font = $fSmall
$chat.ReadOnly = $true; $chat.BorderStyle = "None"; $chat.ScrollBars = "Vertical"
$fChat = New-Object System.Drawing.Font("Segoe UI", 9)
$fEmojiChat = New-Object System.Drawing.Font("Segoe UI Emoji", 9)
$chat.Font = $fChat
$gChat.Controls.Add($chat)
$txtChat = New-Input 16 290 250
$txtChat.MaxLength = 200
$btnCd = New-Button "Countdown" 274 288 84
$btnQ1 = New-Button "Queue now" 364 288 90
$btnQ2 = New-Button "2 min" 460 288 64
$btnQ3 = New-Button "brb" 530 288 60
$btnQ4 = New-Button "gg" 596 288 60
$btnSend = New-Button "Send" 688 288 100 $true
$gChat.Controls.AddRange(@($txtChat, $btnCd, $btnQ1, $btnQ2, $btnQ3, $btnQ4, $btnSend))
$Reacts = @([char]::ConvertFromUtf32(0x1F44D), [char]::ConvertFromUtf32(0x1F602), [char]::ConvertFromUtf32(0x1F525), [char]::ConvertFromUtf32(0x2757))
$fEmoji = New-Object System.Drawing.Font("Segoe UI Emoji", 11)
$rx = 580
$reactBtns = @()
foreach ($r in $Reacts) {
    $rb = New-Button $r $rx 6 46
    $rb.Size = New-Object System.Drawing.Size(46, 26); $rb.Font = $fEmoji; $rb.Tag = $r
    Set-Round $rb 8
    $gChat.Controls.Add($rb); $reactBtns += $rb; $rx += 52
}

# ================= ACTIVITY =================
$pgAct = New-Page "activity" "Activity"
$cLog = New-Card 28 64 804 400
$pgAct.Controls.Add($cLog)
$cLog.Controls.Add((New-Label "LOG" 16 12 200 22 $fHead $cText))
$log = New-Object System.Windows.Forms.RichTextBox
$log.Location = New-Object System.Drawing.Point(16, 40); $log.Size = New-Object System.Drawing.Size(772, 348)
$log.BackColor = $cCard; $log.ForeColor = $cText; $log.Font = $fMono
$log.ReadOnly = $true; $log.BorderStyle = "None"; $log.ScrollBars = "Vertical"
$cLog.Controls.Add($log)
$cBlack = New-Card 28 476 804 228
$pgAct.Controls.Add($cBlack)
$cBlack.Controls.Add((New-Label "BLACKLIST" 16 12 200 22 $fHead $cText))
$lstBlack = New-Object System.Windows.Forms.ListBox
$lstBlack.Location = New-Object System.Drawing.Point(16, 40); $lstBlack.Size = New-Object System.Drawing.Size(772, 134)
$lstBlack.BackColor = $cCard; $lstBlack.ForeColor = $cText; $lstBlack.Font = $fMono; $lstBlack.BorderStyle = "None"
$cBlack.Controls.Add($lstBlack)
$btnRemove = New-Button "Remove selected" 16 184 150
$btnClear  = New-Button "Clear all" 174 184 110
$cBlack.Controls.AddRange(@($btnRemove, $btnClear))

# ================= SETTINGS =================
$pgSet = New-Page "settings" "Settings"
$cSet = New-Card 28 64 804 300
$pgSet.Controls.Add($cSet)
$cSet.Controls.Add((New-Label "GENERAL" 16 12 200 22 $fHead $cText))
function New-SetCheck($text, $y, $checked) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $text; $cb.Checked = [bool]$checked
    $cb.Location = New-Object System.Drawing.Point(16, $y); $cb.Size = New-Object System.Drawing.Size(560, 24)
    $cb.ForeColor = $cText; $cb.BackColor = $cCard
    $cSet.Controls.Add($cb)
    return $cb
}
$chkActive  = New-SetCheck "Protection active (kick + blacklist unofficial servers)" 44 $true
$chkRoom    = New-SetCheck "Host: only stay on servers with room for the whole party" 74 $true
$chkSound   = New-SetCheck "Sounds" 104 $cfg.sound
$chkOverlay = New-SetCheck "Overlay on top of the game (windowed / borderless)" 134 $cfg.overlay
$StartupLnk = Join-Path ([Environment]::GetFolderPath("Startup")) "Waechter.lnk"
$chkAuto    = New-SetCheck "Start with Windows (in the tray)" 164 (Test-Path $StartupLnk)
$cSet.Controls.Add((New-Label "Volume" 16 204 80 20 $fSmall (C 191 210 240)))
$trkVol = New-Object System.Windows.Forms.TrackBar
$trkVol.AutoSize = $false; $trkVol.Location = New-Object System.Drawing.Point(96, 200); $trkVol.Size = New-Object System.Drawing.Size(260, 26)
$trkVol.Minimum = 0; $trkVol.Maximum = 100; $trkVol.TickStyle = "None"; $trkVol.BackColor = $cCard
$trkVol.Value = [Math]::Max(0, [Math]::Min(100, [int]$cfg.vol))
$cSet.Controls.Add($trkVol)
$btnFolder = New-Button "Open Waechter folder" 16 248 180
$cSet.Controls.Add($btnFolder)
$cInfo = New-Card 28 376 804 200
$pgSet.Controls.Add($cInfo)
$cInfo.Controls.Add((New-Label "HOTKEYS AND INFO" 16 12 300 22 $fHead $cText))
$cInfo.Controls.Add((New-Label ("Ctrl+Shift+1-4   quick messages (Queue now, 2 min, brb, gg)`nCtrl+Shift+5   countdown (starts the queue at 0)`nCtrl+Shift+R   ready / not ready`n`nWaechter v$AppVersion  -  updates install automatically when Waechter starts.`nSteam launch option needed:  -netconport 2121") 16 44 770 140 $fSmall (C 191 210 240)))
foreach ($cb in @($chkActive, $chkSound, $chkOverlay, $chkAuto, $chkRoom)) { $cb.Add_MouseEnter({ Play 'hover' }); $cb.Add_MouseDown({ Play 'click' }) }

$tips = New-Object System.Windows.Forms.ToolTip
$tips.SetToolTip($btnQ1, "Hotkey: Ctrl+Shift+1 (works in game)")
$tips.SetToolTip($btnQ2, "Hotkey: Ctrl+Shift+2")
$tips.SetToolTip($btnQ3, "Hotkey: Ctrl+Shift+3")
$tips.SetToolTip($btnQ4, "Hotkey: Ctrl+Shift+4")
$tips.SetToolTip($btnReady, "Hotkey: Ctrl+Shift+R")
$tips.SetToolTip($btnCd, "10 second countdown - the queue starts at 0. Hotkey: Ctrl+Shift+5")

# ---- map pool tiles (CS2-style) ----
$script:poolTiles = @()
function Update-PoolInfo {
    $n = @($cfg.pool).Count
    $lblPoolInfo.Text = if ($n -eq 0) { "No chapter selected = any map" } else { "$n chapter$(if ($n -ne 1) { 's' }) selected" }
}
function Paint-Tile($t) {
    $on = (@($cfg.pool) -contains [string]$t.Tag)
    $t.BackColor = if ($on) { $cAccent } else { $cInput }
    $t.Controls[0].Padding = New-Object System.Windows.Forms.Padding(0)
    $t.Controls[1].ForeColor = if ($on) { $cText } else { (C 190 194 204) }
    $t.Controls[2].Visible = $on
}
function Toggle-Chapter($id) {
    $list = @($cfg.pool)
    if ($list -contains $id) { $cfg.pool = @($list | Where-Object { $_ -ne $id }) } else { $cfg.pool = @($list + $id) }
    Save-Settings; Update-PoolInfo
    foreach ($t in $script:poolTiles) { if ([string]$t.Tag -eq $id) { Paint-Tile $t } }
}
function Build-Pool {
    $flowPool.SuspendLayout()
    $lastCamp = ""
    foreach ($c in $Chapters) {
        if ($c[2] -ne $lastCamp) {
            $lastCamp = $c[2]
            $hdr = New-Label $c[2].ToUpper() 0 0 750 26 $fCamp (C 147 197 253)
            $hdr.Margin = New-Object System.Windows.Forms.Padding(4, 10, 4, 2); $hdr.Tag = "camp:" + $c[2]
            $flowPool.Controls.Add($hdr); $flowPool.SetFlowBreak($hdr, $true)
        }
        $t = New-Object System.Windows.Forms.Panel
        $t.Size = New-Object System.Drawing.Size(178, 116); $t.Margin = New-Object System.Windows.Forms.Padding(4)
        $t.Tag = $c[0]; $t.Cursor = [System.Windows.Forms.Cursors]::Hand
        $pb = New-Object System.Windows.Forms.PictureBox
        $pb.Location = New-Object System.Drawing.Point(3, 3); $pb.Size = New-Object System.Drawing.Size(172, 86); $pb.SizeMode = "Zoom"; $pb.BackColor = $cBg
        if ($script:mapImages.ContainsKey($c[0])) { $pb.Image = $script:mapImages[$c[0]] }
        $nm = New-Label $c[1] 6 92 140 20 $fTile $cText
        $ck = New-Label ([string][char]0x2714) 150 92 24 20 $fTile $cText
        $t.Controls.AddRange(@($pb, $nm, $ck))
        foreach ($ctl in @($t, $pb, $nm, $ck)) { $ctl.Tag = $c[0]; $ctl.Add_Click({ param($s, $e) Play 'click'; Toggle-Chapter ([string]$s.Tag) }) }
        $flowPool.Controls.Add($t); $script:poolTiles += $t
        Paint-Tile $t
    }
    $flowPool.ResumeLayout()
    Update-PoolInfo
}
function Filter-Pool {
    $q = $txtMapSearch.Text.Trim().ToLower()
    $flowPool.SuspendLayout()
    $visCamp = @{}
    foreach ($t in $script:poolTiles) {
        $id = [string]$t.Tag; $inf = $ChapterInfo[$id]
        $vis = (-not $q) -or $id.Contains($q) -or $inf.name.ToLower().Contains($q) -or $inf.camp.ToLower().Contains($q)
        $t.Visible = $vis
        if ($vis) { $visCamp[$inf.camp] = $true }
    }
    foreach ($ctl in $flowPool.Controls) { if ($ctl.Tag -is [string] -and $ctl.Tag.StartsWith("camp:")) { $ctl.Visible = $visCamp.ContainsKey($ctl.Tag.Substring(5)) } }
    $flowPool.ResumeLayout()
}
function Update-FilterLabels {
    $lblPingVal.Text = "$($trkPing.Value * 10) ms"
    $lblMinVal.Text = "$($trkMin.Value)"
}

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
    $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($cGlassB)), $r)
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
    $lblSideStatus.Text = $text; $lblSideDot.ForeColor = $color
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

# ---------------- party (own Cloudflare relay, no IPs are ever sent) ----------------
try { [Net.ServicePointManager]::DefaultConnectionLimit = 16 } catch { }
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
$script:lastStatusPub = [DateTime]::MinValue; $script:statusDirty = $false
$script:pubTasks = New-Object System.Collections.ArrayList; $script:quotaWarned = $false
function Publish($type, $text = $null, [switch]$Force) {
    if (-not $cfg.party) { return }
    # keep status updates rare (max one every 20 s)
    if ($type -eq "status" -and -not $Force) {
        if (((Get-Date) - $script:lastStatusPub).TotalSeconds -lt 20) { $script:statusDirty = $true; return }
    }
    if ($type -eq "status") { $script:lastStatusPub = Get-Date; $script:statusDirty = $false }
    $msg = @{ v = 1; type = $type; text = $text; id = $cfg.id; name = $txtName.Text.Trim(); role = $(if ($cfg.host) { "host" } else { "member" }); status = $script:myStatus; ready = $script:myReady } | ConvertTo-Json -Compress
    try {
        $content = New-Object System.Net.Http.StringContent($msg, [System.Text.Encoding]::UTF8, "text/plain")
        $pt = $http.PostAsync("$Relay/$(Topic)", $content)
        if ($script:pubTasks.Count -lt 50) { [void]$script:pubTasks.Add($pt) }
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
    # long poll: the relay answers as soon as there is a new message (or after 25 s with nothing)
    try { $script:subTask = $http.GetStringAsync("$Relay/$(Topic)/json?since=$since&wait=25") } catch { $script:nextSub = (Get-Date).AddSeconds(10) }
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
    $lblSideParty.Text = $script:partySummary
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
        if ($m.type -eq "hello") { Publish "status" -Force }   # let newcomers see us
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
    # subscription (long poll)
    if (-not $script:subTask) {
        if ((Get-Date) -ge $script:nextSub) { Start-Sub }
    } elseif ($script:subTask.IsCompleted) {
        $t = $script:subTask; $script:subTask = $null
        if ($t.IsFaulted -or $t.IsCanceled) {
            $script:nextSub = (Get-Date).AddSeconds(5)
        } else {
            foreach ($line in ($t.Result -split "`n")) {
                if ($line.Trim()) { Handle-PartyMessage $line; $script:replay = $false }
                if (-not $cfg.party) { break }
            }
            $script:nextSub = [DateTime]::MinValue
        }
    }
    # send a status that was held back by the 20 s limit
    if ($script:statusDirty -and ((Get-Date) - $script:lastStatusPub).TotalSeconds -ge 20) { Publish "status" }
    # check sent messages: 429 = the relay's daily limit for this internet connection is used up
    foreach ($pt in @($script:pubTasks)) {
        if ($pt.IsCompleted) {
            [void]$script:pubTasks.Remove($pt)
            try {
                if (-not $pt.IsFaulted -and [int]$pt.Result.StatusCode -eq 429 -and -not $script:quotaWarned) {
                    $script:quotaWarned = $true
                    Write-Log "Party relay limit reached for your internet - your party can't see you right now (resets within a day)" $cRed
                    Add-Chat "Waechter" "Your messages can't be sent right now (relay daily limit for your internet). The others can't see you until it resets." $cRed
                }
            } catch { }
        }
    }
    # heartbeat every 2 min (only while L4D2 is open or was open in the last 30 min), drop members silent for 10 min
    if ((Get-Date) -ge $script:nextBeat) {
        $script:nextBeat = (Get-Date).AddMinutes(2)
        $idle = ($script:myStatus -eq "Game closed" -and ((Get-Date) - $script:closedSince).TotalMinutes -gt 30)
        if (-not $idle) { Publish "status" -Force }
        $changed = $false
        foreach ($k in @($script:members.Keys)) {
            if (((Get-Date) - $script:members[$k].seen).TotalMinutes -gt 10) { $script:members.Remove($k); $changed = $true }
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
# L4D2 refuses a connect while you are still on a server - so always disconnect first, then connect
$script:joinTimer = New-Object System.Windows.Forms.Timer
$script:joinTimer.Interval = 1500
$script:joinKey = $null
$script:joinTimer.Add_Tick({ $script:joinTimer.Stop(); if ($script:joinKey) { Send-Cmd "connect $($script:joinKey)"; $script:joinKey = $null } })
function Join-Game($key) {
    Send-Cmd "disconnect"
    $script:joinKey = $key
    $script:joinTimer.Stop(); $script:joinTimer.Start()
}
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
                    if ((Get-Date) -lt $script:pendingGo.until) { Write-Log "Joining the queued game" $cGreen; Join-Game $script:pendingGo.key }
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
$script:scan = $null; $script:lastResults = @(); $script:lastScanAt = $null
function Pump-Udp {
    if (-not $script:udp) { return }
    $n = 0
    while ($n -lt 800) {
        try { if ($script:udp.Available -le 0) { break } } catch { break }
        $n++
        $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        try { $d = $script:udp.Receive([ref]$ep) } catch { continue }
        $sc = $script:scan
        if (-not $sc -or $sc.done -or $d.Length -lt 6) { continue }
        $key = "$($ep.Address):$($ep.Port)"
        if ($d[4] -eq 0x41 -and $d.Length -ge 9) { Send-A2S $key ([byte[]]$d[5..8]); continue }
        if ($d[4] -eq 0x49) { $info = Read-A2SInfo $d; if ($info) { $sc.found[$key] = $info } }
    }
}
function Start-Scan {
    if ($script:scan -and -not $script:scan.done) { return $true }
    if (-not (Open-Udp)) { Write-Log "Network blocked - cannot ask the servers" $cRed; return $false }
    $script:scan = @{ targets = (Get-QueueTargets); idx = 0; found = @{}; lastSend = (Get-Date); done = $false }
    $lblSvInfo.Text = "Asking the official Valve servers ..."
    return $true
}
function Tick-Scan {
    $sc = $script:scan; if (-not $sc -or $sc.done) { return }
    $now = Get-Date
    $end = [Math]::Min($sc.idx + 450, $sc.targets.Count)
    for ($k = $sc.idx; $k -lt $end; $k++) { Send-A2S $sc.targets[$k] $null }
    if ($end -gt $sc.idx) { $sc.lastSend = $now }
    $sc.idx = $end
    if ($sc.idx -ge $sc.targets.Count -and ($now - $sc.lastSend).TotalMilliseconds -ge 2500) { $sc.done = $true; Finish-Scan $sc }
}
# exact ping: one request per machine, all sent at the same moment, first answer timed
function Measure-Pings($keys) {
    $res = @{}
    if (-not $script:udp -or -not $keys) { return $res }
    while ($script:udp.Available -gt 0) { $ep0 = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0); try { [void]$script:udp.Receive([ref]$ep0) } catch { break } }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($k in $keys) { Send-A2S $k $null }
    while ($sw.ElapsedMilliseconds -lt 900 -and $res.Count -lt @($keys).Count) {
        $av = 0; try { $av = $script:udp.Available } catch { break }
        if ($av -gt 0) {
            $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
            try { [void]$script:udp.Receive([ref]$ep); $ip = [string]$ep.Address; if (-not $res.ContainsKey($ip)) { $res[$ip] = [int]$sw.ElapsedMilliseconds } } catch { }
        } else { Start-Sleep -Milliseconds 1 }
    }
    return $res
}
function Get-Mode($keywords) {
    $tags = @(([string]$keywords -split ',') | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -and $_ -notin @('empty', 'secure', 'insecure', 'full') })
    if ($tags -contains 'versus') { return 'versus' }
    if ($tags.Count) { return $tags[0] }
    return '-'
}
function Finish-Scan($sc) {
    $list = @()
    foreach ($k in @($sc.found.Keys)) {
        $s = $sc.found[$k]
        if ($s.name -notmatch '^Valve Left ?4 ?Dead') { continue }
        $humans = [Math]::Max(0, $s.players - $s.bots)
        $list += [pscustomobject]@{ key = $k; ip = $k.Split(':')[0]; name = $s.name; map = ([string]$s.map).ToLower(); humans = $humans; max = $s.max;
                                    mode = (Get-Mode $s.keywords); region = (Get-Region $s.name); ping = 999 }
    }
    $probe = @(); $seenIp = @{}
    foreach ($c in $list) { if (-not $seenIp.ContainsKey($c.ip)) { $seenIp[$c.ip] = 1; $probe += $c.key } }
    $pings = Measure-Pings $probe
    foreach ($c in $list) { if ($pings.ContainsKey($c.ip)) { $c.ping = $pings[$c.ip] } }
    $script:lastResults = $list; $script:lastScanAt = Get-Date
    Fill-Browser
    if ($script:q -and -not $script:q.joining -and -not $script:q.member) { Pick-QueueServer }
}
function Test-MyFilters($s, $size) {
    if ($s.humans -lt [int]$cfg.minPlayers) { return $false }
    if (($s.max - $s.humans) -lt $size) { return $false }
    if (@($cfg.regions) -notcontains $s.region) { return $false }
    if ($s.ping -gt [int]$cfg.maxPing) { return $false }
    if (@($cfg.pool).Count -and (@($cfg.pool) -notcontains $s.map)) { return $false }
    return $true
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
    if (@($cfg.regions).Count -eq 0) { Set-Status "No region selected" "Tick at least one region on the Play page" $cYellow; return }
    $script:q = @{ failed = @{}; joining = $false; waitUntil = $null; member = $false; scans = 0 }
    $btnQueue.Text = "Cancel"; $btnQueue.BackColor = (C 127 29 29)
    $script:searchStart = $null; Start-Search
    $size = Get-PartySize
    $poolTxt = if (@($cfg.pool).Count) { "$(@($cfg.pool).Count) chapters" } else { "any map" }
    Write-Log "QUEUE  versus, $size player$(if ($size -ne 1) { 's' }), max $($cfg.maxPing) ms, min $($cfg.minPlayers) players, $poolTxt" (C 147 197 253)
    if ($cfg.party) { Publish "chat" "Queue started - searching an official versus game"; Add-Chat $txtName.Text.Trim() "Queue started - searching an official versus game" (Get-PersonColor $cfg.id) }
    Set-Status "Searching versus games ..." "Asking the official Valve servers" (C 147 197 253)
    $script:q.scans++
    [void](Start-Scan)
}
function Stop-Queue($msg) {
    $script:q = $null; $script:pendingGo = $null
    $btnQueue.Text = "QUEUE"; $btnQueue.BackColor = $cAccent
    Stop-Search $false
    if ($msg) { Write-Log $msg $cMuted }
}
function Pick-QueueServer {
    $qq = $script:q; if (-not $qq) { return }
    $size = Get-PartySize
    $all = @($script:lastResults)
    $versus = @($all | Where-Object { $_.mode -eq 'versus' })
    $cands = @($versus | Where-Object { (Test-MyFilters $_ $size) -and -not $qq.failed.ContainsKey($_.key) -and -not $script:badServers.ContainsKey($_.key) })
    if (-not $cands.Count) {
        $qq.waitUntil = (Get-Date).AddSeconds(20)
        $why = if ($all.Count -eq 0) { "No official server answered - check your internet" } else { "$($all.Count) official, $($versus.Count) versus - none fits your filters right now" }
        Set-Status "Searching versus games ..." "$why. Next try in 20 s" (C 147 197 253)
        if ($qq.scans -le 1 -or ($qq.scans % 5) -eq 0) { Write-Log "No fitting game yet ($($all.Count) official, $($versus.Count) versus) - still searching" $cMuted }
        return
    }
    $best = $cands | Sort-Object ping | Select-Object -First 1
    Go-Server $best
}
function Go-Server($s) {
    $qq = $script:q; if (-not $qq) { return }
    $qq.joining = $true; $qq.target = $s.key; $qq.joinDeadline = (Get-Date).AddSeconds(40)
    $where = Get-RegionShort $s.name
    Write-Log "FOUND  $where - $(Get-MapLabel $s.map) - $($s.humans)/$($s.max) players, $($s.ping) ms - joining" $cGreen
    Set-Status "Game found - joining ..." "$where  -  $(Get-MapLabel $s.map)  -  $($s.humans)/$($s.max)  -  $($s.ping) ms" $cGreen
    Play 'official'
    if ($cfg.party) { Publish "go" (Hide-Addr $s.key) }
    Connect-To $s.key
}
function Connect-To($key) {
    if ($script:q) { $script:q.connectAt = Get-Date }
    if ($script:client) { Join-Game $key }
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
    Tick-Scan
    $qq = $script:q; if (-not $qq) { return }
    if ($qq.waitUntil -and (Get-Date) -ge $qq.waitUntil -and -not $qq.joining) {
        $qq.waitUntil = $null; $qq.scans++
        Set-Status "Searching versus games ..." "Asking the official Valve servers" (C 147 197 253)
        [void](Start-Scan)
    }
    if ($qq.joining -and (Get-Date) -ge $qq.joinDeadline) { Join-Failed "no answer" }
}
function Queue-Joined {
    $qq = $script:q; if (-not $qq -or -not $qq.joining) { return }
    Write-Log "JOINED  official versus game" $cGreen
    $script:q = $null
    $btnQueue.Text = "QUEUE"; $btnQueue.BackColor = $cAccent
}
function Handle-QueueLine($line) {
    $qq = $script:q; if (-not $qq -or -not $qq.joining) { return }
    if ($line -match '(?i)unreserved|reservation') { return }
    if ($qq.connectAt -and ((Get-Date) - $qq.connectAt).TotalSeconds -lt 3.5) { return }
    if ($line -match '(?i)^\s*Disconnect:|server is full|connection rejected|lobby only|enforcing|#Valve_Reject|Connection failed') { Join-Failed "server refused" }
}

# ---------------- in-app server browser ----------------
function Fill-Browser {
    $size = Get-PartySize
    $rows = @($script:lastResults)
    if ($chkSvVersus.Checked) { $rows = @($rows | Where-Object { $_.mode -eq 'versus' }) }
    if ($chkSvEmpty.Checked) { $rows = @($rows | Where-Object { $_.humans -gt 0 }) }
    $mk = if ($cmbSvMap.SelectedIndex -gt 0) { [string]$script:svMapKeys[$cmbSvMap.SelectedIndex] } else { "" }
    if ($mk -like "camp:*") { $cn = $mk.Substring(5); $rows = @($rows | Where-Object { $ChapterInfo.ContainsKey($_.map) -and $ChapterInfo[$_.map].camp -eq $cn }) }
    elseif ($mk) { $rows = @($rows | Where-Object { $_.map -eq $mk }) }
    $rows = @($rows | Sort-Object @{ Expression = { -$_.humans } }, ping)
    $sel = if ($lvServers.SelectedItems.Count) { [string]$lvServers.SelectedItems[0].Tag } else { "" }
    $lvServers.BeginUpdate(); $lvServers.Items.Clear()
    foreach ($s in $rows) {
        $it = New-Object System.Windows.Forms.ListViewItem((Get-RegionShort $s.name))
        [void]$it.SubItems.Add((Get-MapLabel $s.map))
        [void]$it.SubItems.Add($s.mode)
        [void]$it.SubItems.Add("$($s.humans)/$($s.max)")
        [void]$it.SubItems.Add($(if ($s.ping -ge 999) { "-" } else { "$($s.ping)" }))
        $it.Tag = $s.key
        $it.UseItemStyleForSubItems = $false
        $pc = if ($s.ping -le 60) { $cGreen } elseif ($s.ping -le 120) { $cYellow } else { $cRed }
        $it.SubItems[4].ForeColor = $pc
        if ($s.key -eq $sel) { $it.Selected = $true }
        [void]$lvServers.Items.Add($it)
    }
    $lvServers.EndUpdate()
    if ($script:lastScanAt) { $lblSvInfo.Text = "$($rows.Count) shown  -  $(@($script:lastResults).Count) official  -  $($script:lastScanAt.ToString('HH:mm'))" }
}
function Get-Result($key) { foreach ($s in $script:lastResults) { if ($s.key -eq $key) { return $s } }; return $null }
function Show-ServerDetails {
    $lvPlayers.Items.Clear()
    if (-not $lvServers.SelectedItems.Count) { $lblSvName.Text = "Select a server"; $lblSvMeta.Text = ""; $picSv.Image = $null; return }
    $s = Get-Result ([string]$lvServers.SelectedItems[0].Tag); if (-not $s) { return }
    $lblSvName.Text = Get-MapLabel $s.map
    $lblSvMeta.Text = "$(Get-RegionShort $s.name)  ($($s.region))`n$($s.mode)  -  $($s.humans)/$($s.max) players`nPing: $(if ($s.ping -ge 999) { '-' } else { "$($s.ping) ms" })"
    $picSv.Image = if ($script:mapImages.ContainsKey($s.map)) { $script:mapImages[$s.map] } else { $null }
}
function Get-A2SPlayers($key) {
    $out = @()
    if (-not (Open-Udp)) { return $out }
    while ($script:udp.Available -gt 0) { $ep0 = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0); try { [void]$script:udp.Receive([ref]$ep0) } catch { break } }
    $parts = $key.Split(':'); $chal = [byte[]](0xFF, 0xFF, 0xFF, 0xFF)
    for ($try = 0; $try -lt 3; $try++) {
        $pkt = [byte[]](@(0xFF, 0xFF, 0xFF, 0xFF, 0x55) + $chal)
        try { [void]$script:udp.Send($pkt, $pkt.Length, $parts[0], [int]$parts[1]) } catch { return $out }
        $sw = [System.Diagnostics.Stopwatch]::StartNew(); $d = $null
        while ($sw.ElapsedMilliseconds -lt 1200 -and -not $d) {
            if ($script:udp.Available -gt 0) {
                $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
                try { $x = $script:udp.Receive([ref]$ep); if ("$($ep.Address):$($ep.Port)" -eq $key -and $x.Length -ge 6 -and ($x[4] -eq 0x41 -or $x[4] -eq 0x44)) { $d = $x } } catch { }
            } else { Start-Sleep -Milliseconds 2 }
        }
        if (-not $d) { return $out }
        if ($d[4] -eq 0x41) { $chal = [byte[]]$d[5..8]; continue }
        $cnt = [int]$d[5]; $i = 6
        for ($p = 0; $p -lt $cnt -and $i -lt $d.Length; $p++) {
            $i++
            $j = [Array]::IndexOf($d, [byte]0, $i); if ($j -lt 0) { break }
            $nm = [System.Text.Encoding]::UTF8.GetString($d, $i, $j - $i); $i = $j + 1
            if ($i + 8 -gt $d.Length) { break }
            $score = [BitConverter]::ToInt32($d, $i); $dur = [BitConverter]::ToSingle($d, $i + 4); $i += 8
            $out += [pscustomobject]@{ name = $nm; score = $score; time = $dur }
        }
        return $out
    }
    return $out
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
$trkPing.Add_ValueChanged({ Update-FilterLabels })
$trkPing.Add_MouseUp({ $cfg.maxPing = $trkPing.Value * 10; Save-Settings })
$trkPing.Add_KeyUp({ $cfg.maxPing = $trkPing.Value * 10; Save-Settings })
$trkMin.Add_ValueChanged({ Update-FilterLabels })
$trkMin.Add_MouseUp({ $cfg.minPlayers = $trkMin.Value; Save-Settings })
$trkMin.Add_KeyUp({ $cfg.minPlayers = $trkMin.Value; Save-Settings })
foreach ($cb in $script:regionChecks) {
    $cb.Add_CheckedChanged({ $cfg.regions = @($script:regionChecks | Where-Object { $_.Checked } | ForEach-Object { [string]$_.Tag }); Save-Settings })
    $cb.Add_MouseDown({ Play 'click' })
}
$txtMapSearch.Add_TextChanged({ Filter-Pool })
$btnPoolAll.Add_Click({ $cfg.pool = @($Chapters | ForEach-Object { $_[0] }); Save-Settings; foreach ($t in $script:poolTiles) { Paint-Tile $t }; Update-PoolInfo })
$btnPoolNone.Add_Click({ $cfg.pool = @(); Save-Settings; foreach ($t in $script:poolTiles) { Paint-Tile $t }; Update-PoolInfo })
$btnRefresh.Add_Click({
    if ($script:scan -and -not $script:scan.done) { $lblSvInfo.Text = "Already searching ..."; return }
    [void](Start-Scan)
})
foreach ($cb in @($chkSvVersus, $chkSvEmpty)) { $cb.Add_CheckedChanged({ Fill-Browser }) }
$cmbSvMap.Add_SelectedIndexChanged({ Fill-Browser })
$lvServers.Add_SelectedIndexChanged({ Show-ServerDetails })
$lvServers.Add_DoubleClick({ $btnSvJoin.PerformClick() })
$btnSvJoin.Add_Click({
    if (-not $lvServers.SelectedItems.Count) { return }
    $s = Get-Result ([string]$lvServers.SelectedItems[0].Tag); if (-not $s) { return }
    if ($cfg.party -and -not $cfg.host) { Write-Log "In a party only the host picks the server" $cYellow; return }
    Write-Log "JOIN  $(Get-RegionShort $s.name) - $(Get-MapLabel $s.map)" (C 147 197 253)
    if ($cfg.party) { Publish "go" (Hide-Addr $s.key) }
    Connect-To $s.key
})
$btnSvPing.Add_Click({
    if (-not $lvServers.SelectedItems.Count) { return }
    if ($script:scan -and -not $script:scan.done) { return }
    $s = Get-Result ([string]$lvServers.SelectedItems[0].Tag); if (-not $s) { return }
    [void](Open-Udp)
    $pp = Measure-Pings @($s.key)
    if ($pp.ContainsKey($s.ip)) { foreach ($x in $script:lastResults) { if ($x.ip -eq $s.ip) { $x.ping = $pp[$s.ip] } } } else { $s.ping = 999 }
    Fill-Browser; Show-ServerDetails
})
$btnSvPlayers.Add_Click({
    if (-not $lvServers.SelectedItems.Count) { return }
    if ($script:scan -and -not $script:scan.done) { return }
    $key = [string]$lvServers.SelectedItems[0].Tag
    $lvPlayers.Items.Clear()
    $pl = @()
    try { $pl = @(Get-A2SPlayers $key) } catch { Write-Log "Player list error: $($_.Exception.Message)" $cRed }
    foreach ($p in ($pl | Sort-Object score -Descending)) {
        $it = New-Object System.Windows.Forms.ListViewItem([string]$p.name)
        [void]$it.SubItems.Add([string]$p.score)
        $mins = [int]([double]$p.time / 60)
        [void]$it.SubItems.Add($(if ($mins -ge 60) { "{0}h {1}m" -f [int][Math]::Floor($mins / 60), ($mins % 60) } else { "$mins min" }))
        [void]$lvPlayers.Items.Add($it)
    }
    if (-not $pl.Count) { [void]$lvPlayers.Items.Add((New-Object System.Windows.Forms.ListViewItem("(no players or no answer)"))) }
})
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
    if ($cfg.party) { $script:myStatus = "Offline"; Publish "status" -Force; Start-Sleep -Milliseconds 400 }
    try { if ($script:client) { $script:client.Close() } } catch { }
    $cfg.name = $txtName.Text.Trim(); Save-Settings
})

# ---------------- start ----------------
Update-SteamLabel
try { Load-MapImages } catch { }
Build-Pool
Update-FilterLabels
Show-Page "play"
Refresh-Recent
Refresh-Blacklist
Update-Stats
if ($cfg.party) { Join-Party $cfg.party ([bool]$cfg.host) } else { Refresh-Party }
Write-Log "Waechter v$AppVersion started" $cMuted
if ($script:updateNote) { Write-Log $script:updateNote $cMuted }
if (-not $script:vpkReady) { Write-Log "Map pictures unavailable: $($script:vpkError)" $cYellow }
elseif ($script:mapImages.Count -lt $Chapters.Count) { Write-Log "Map pictures: $($script:mapImages.Count)/$($Chapters.Count) found (is L4D2 installed?)" $cYellow }
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
