@echo off
setlocal
title OPTIMIZER SEB V1
color 0B
powershell.exe -NoProfile -Command "try{$h=$Host.UI.RawUI;$w=$h.WindowSize;$b=$h.BufferSize;$b.Height=5000;if($b.Width -lt 120){$b.Width=120};$h.BufferSize=$b;$w.Width=120;$w.Height=40;$h.WindowSize=$w}catch{}" >nul 2>&1
cls
echo.
echo  ==============================================================================================================
echo.
echo     ######    ########    ##########  ##########  ##      ##  ##########  ##########  ##########  ########
echo   ##      ##  ##      ##      ##          ##      ####  ####      ##            ##    ##          ##      ##
echo   ##      ##  ########        ##          ##      ##  ##  ##      ##          ##      ########    ########
echo   ##      ##  ##              ##          ##      ##      ##      ##        ##        ##          ##    ##
echo     ######    ##              ##      ##########  ##      ##  ##########  ##########  ##########  ##      ##
echo.
echo   ##      ##      ##
echo   ##      ##    ####
echo   ##      ##      ##
echo     ##  ##        ##
echo       ##        ######
echo.
echo  ==============================================================================================================
echo            Pemeriksaan jaringan, versi SEB, dan kesiapan komputer untuk Safe Exam Browser
echo  ==============================================================================================================
echo.

:: Cek hak Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Script belum berjalan sebagai Administrator.
    echo.
    choice /c YN /n /m "  Jalankan ulang sebagai Administrator? [Y/N]: "
    if errorlevel 2 (
        echo.
        echo  Dibatalkan oleh pengguna.
        pause
        exit /b
    )
    echo.
    echo  Meminta izin Administrator melalui UAC...
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo  [OK] Hak Administrator terdeteksi.
echo.
choice /c YN /n /m "  Mulai pemeriksaan OPTIMIZER SEB V1 sekarang? [Y/N]: "
if errorlevel 2 (
    echo.
    echo  Pemeriksaan dibatalkan.
    pause
    exit /b
)

echo.
echo  Memulai pemeriksaan...
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText('%~f0',[Text.Encoding]::UTF8); $i=$t.LastIndexOf('@@PS'+'_BEGIN@@'); Invoke-Expression $t.Substring($i+12)"
echo.
echo  Pemeriksaan selesai.
pause
endlocal
exit /b

# @@PS_BEGIN@@
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference    = "SilentlyContinue"
$Host.UI.RawUI.WindowTitle = "OPTIMIZER SEB V1"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
try { [Net.ServicePointManager]::SecurityProtocol = ([Net.ServicePointManager]::SecurityProtocol -bor 12288) } catch {}

# ===================== PENGATURAN (boleh diubah) =====================
$SEB_HOST       = "safeexambrowser.org"
$SEB_URL        = "https://safeexambrowser.org/"
$SEB_DOWNLOAD   = "https://safeexambrowser.org/download_en.html"
$SEB_API        = "https://api.github.com/repos/SafeExamBrowser/seb-win-refactoring/releases/latest"
$ELEARN_HOST    = "elearning.poltekkes-smg.ac.id"
$ELEARN_URL     = "https://elearning.poltekkes-smg.ac.id/"
$MIN_MBPS       = 2
$PING_COUNT     = 5
# =====================================================================

$global:rep = @()
$masalah    = @()
$peringatan = @()

function H($s){
  Write-Host ""
  Write-Host "================================================================" -ForegroundColor DarkCyan
  Write-Host " $s" -ForegroundColor Cyan
  Write-Host "================================================================" -ForegroundColor DarkCyan
}
function Row($status,$label,$text){
  $tag = switch($status){ "OK"{"[ OK ]"} "WARN"{"[ !  ]"} default{"[ XX ]"} }
  $col = switch($status){ "OK"{"Green"} "WARN"{"Yellow"} default{"Red"} }
  $line = ("{0} {1,-26}: {2}" -f $tag,$label,$text)
  Write-Host $line -ForegroundColor $col
  $global:rep += $line
}
function Get-Ver3($s){
  if("$s" -match '(\d+)\.(\d+)\.(\d+)'){ return [version]("{0}.{1}.{2}" -f $matches[1],$matches[2],$matches[3]) }
  return $null
}
function Test-Ping($target,$count){
  $p = New-Object System.Net.NetworkInformation.Ping
  $t = @()
  $resolved = $true
  try { $null = [System.Net.Dns]::GetHostAddresses($target) } catch { $resolved = $false }
  if($resolved){
    for($i=0;$i -lt $count;$i++){
      try { $r = $p.Send($target,2000); if($r.Status -eq "Success"){ $t += [int]$r.RoundtripTime } } catch {}
      Start-Sleep -Milliseconds 250
    }
  }
  $o = [pscustomobject]@{Target=$target;Resolved=$resolved;Sent=$count;Recv=$t.Count;Loss=100;Min=0;Max=0;Avg=0;OK=$false}
  if($t.Count -gt 0){
    $m = $t | Measure-Object -Minimum -Maximum -Average
    $o.Loss = [int](100*($count-$t.Count)/$count)
    $o.Min = [int]$m.Minimum; $o.Max = [int]$m.Maximum; $o.Avg = [int][math]::Round($m.Average)
    $o.OK = $true
  }
  return $o
}
function Show-Ping($nama,$r){
  if($r.OK){
    Write-Host ("  {0} ({1}): terkirim {2}, diterima {3}, loss {4}% | min {5} ms, maks {6} ms, rata-rata {7} ms" -f $nama,$r.Target,$r.Sent,$r.Recv,$r.Loss,$r.Min,$r.Max,$r.Avg) -ForegroundColor White
  } elseif(-not $r.Resolved){
    Write-Host ("  {0} ({1}): nama tidak dapat di-resolve (DNS bermasalah)" -f $nama,$r.Target) -ForegroundColor Red
  } else {
    Write-Host ("  {0} ({1}): tidak ada balasan ping (mungkin diblokir server)" -f $nama,$r.Target) -ForegroundColor Yellow
  }
}
function Rate-Latency($ms){
  if($ms -le 100){ return "BAIK" } elseif($ms -le 200){ return "CUKUP" } else { return "TINGGI / LAMBAT" }
}
function Test-Web($url){
  $res = [pscustomobject]@{OK=$false;Code=0;Ms=0;Err=""}
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    $req = [Net.HttpWebRequest]::Create($url)
    $req.Method = "GET"; $req.Timeout = 15000; $req.UserAgent = "Optimizer-SEB-V1"; $req.AllowAutoRedirect = $true
    $resp = $req.GetResponse(); $res.Code = [int]$resp.StatusCode; $resp.Close()
  } catch [Net.WebException] {
    if($_.Exception.Response){ $res.Code = [int]$_.Exception.Response.StatusCode } else { $res.Err = $_.Exception.Message }
  } catch { $res.Err = $_.Exception.Message }
  $sw.Stop(); $res.Ms = [int]$sw.ElapsedMilliseconds
  if($res.Code -gt 0 -and $res.Code -lt 500){ $res.OK = $true }
  return $res
}
function Get-ActiveIP {
  Get-NetIPConfiguration | Where-Object {$_.IPv4Address -and $_.NetAdapter.Status -eq "Up"}
}

Write-Host ""
Write-Host "  Script hanya menjalankan pemeriksaan jaringan, versi SEB, dan aplikasi remote." -ForegroundColor Gray
Write-Host "  Tidak mengambil/mengirim data pribadi dan tidak menghapus aplikasi." -ForegroundColor Gray

# ---------------------------------------------------------------
H "1. FLUSH DNS DAN IP RENEW"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$ipBefore = @(Get-ActiveIP | ForEach-Object { $_.IPv4Address.IPAddress })
$dnsOK = $null; $renewOK = $null
if($isAdmin){
  ipconfig /flushdns
  $dnsOK = ($LASTEXITCODE -eq 0)
  Write-Host "`nMelakukan IP Release dan Renew. Koneksi dapat terputus sementara..." -ForegroundColor Yellow
  ipconfig /release | Out-Null
  Start-Sleep 2
  ipconfig /renew
  $renewOK = ($LASTEXITCODE -eq 0)
  Write-Host "Menunggu koneksi pulih..." -ForegroundColor Yellow
  $tries = 0
  do { Start-Sleep 2; $tries++; $net = Test-Connection 8.8.8.8 -Count 1 -Quiet } until($net -or $tries -ge 15)
  if($dnsOK){ Write-Host "DNS: SUDAH DI-FLUSH" -ForegroundColor Green } else { Write-Host "DNS: GAGAL" -ForegroundColor Red }
} else {
  Write-Host "PowerShell BUKAN Administrator: Flush DNS dan IP Renew dilewati." -ForegroundColor Yellow
  Write-Host "Buka PowerShell dengan 'Run as administrator' untuk langkah ini." -ForegroundColor Yellow
}
$ipNow = @(Get-ActiveIP)
$ipAfter = @($ipNow | ForEach-Object { $_.IPv4Address.IPAddress })
if($isAdmin){
  if($renewOK -and $ipAfter.Count -gt 0){ Write-Host "IP RENEW: BERHASIL, IP TERBARU SUDAH DIPERBARUI" -ForegroundColor Green } else { Write-Host "IP RENEW: PERIKSA KONEKSI" -ForegroundColor Red }
}
Write-Host "`nIP aktif saat ini:"
$ipNow | ForEach-Object {
  Write-Host ("  {0} : {1} | Gateway: {2}" -f $_.NetAdapter.InterfaceAlias,($_.IPv4Address.IPAddress -join ","),($_.IPv4DefaultGateway.NextHop -join ",")) -ForegroundColor White
}
if($isAdmin -and $ipAfter.Count -gt 0 -and $ipBefore.Count -gt 0){
  if(($ipAfter -join ",") -eq ($ipBefore -join ",")){
    Write-Host "  (IP sama seperti sebelumnya - normal jika DHCP memberi alamat yang sama)" -ForegroundColor DarkGray
  } else {
    Write-Host ("  (IP sebelumnya: {0})" -f ($ipBefore -join ",")) -ForegroundColor DarkGray
  }
}
$ipText = if($ipAfter.Count -gt 0){ $ipAfter -join ", " } else { "tidak terdeteksi" }

# ---------------------------------------------------------------
H "2. DETEKSI APLIKASI REMOTE ACCESS (TIDAK BOLEH DIGUNAKAN)"
$patterns = @("TeamViewer","AnyDesk","RustDesk","UltraViewer","Supremo","Chrome Remote Desktop","Remote Utilities","TightVNC","RealVNC","TigerVNC","Radmin","AeroAdmin","DWService","Splashtop","LogMeIn","GoTo Resolve","ScreenConnect","ConnectWise Control","Zoho Assist","Parsec")
$roots = @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*","HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*")
$uninst = foreach($r in $roots){ Get-ItemProperty $r | Where-Object DisplayName }
$apps = @($uninst | Select-Object -ExpandProperty DisplayName)
$found = @()
foreach($p in $patterns){ $found += $apps | Where-Object {$_ -like "*$p*"} | ForEach-Object { "Aplikasi terpasang: $_" } }
$runtime = @(Get-Process | Select-Object -ExpandProperty ProcessName) + @(Get-Service | Select-Object -ExpandProperty Name)
foreach($p in @("TeamViewer","AnyDesk","RustDesk","UltraViewer","Supremo","vnc","Radmin","Splashtop","ScreenConnect","ConnectWise","ChromeRemote","remoting_host")){
  $found += $runtime | Where-Object {$_ -like "*$p*"} | ForEach-Object { "Proses/service aktif: $_" }
}
$found = @($found | Sort-Object -Unique)
if($found.Count -eq 0){
  Write-Host "TIDAK DITEMUKAN aplikasi remote yang dikenal." -ForegroundColor Green
} else {
  Write-Host "PERINGATAN! DITEMUKAN aplikasi/proses yang tidak boleh digunakan saat ujian:" -ForegroundColor Red
  $found | ForEach-Object { Write-Host "  [PERIKSA] $_" -ForegroundColor Red }
  Write-Host "Tutup/uninstall secara manual jika tidak diperlukan, lalu jalankan pemeriksaan ulang." -ForegroundColor Red
}
Write-Host "Catatan: deteksi berdasarkan nama aplikasi/proses/service, bukan jaminan 100%." -ForegroundColor DarkGray

# ---------------------------------------------------------------
H "3. VERSI SAFE EXAM BROWSER (SEB)"
$sebInst = @()
foreach($u in $uninst){
  if($u.DisplayName -like "*Safe Exam Browser*" -or $u.DisplayName -like "SafeExamBrowser*"){
    $sebInst += [pscustomobject]@{Name=$u.DisplayName;Ver=$u.DisplayVersion}
  }
}
if($sebInst.Count -eq 0){
  foreach($path in @("$env:ProgramFiles\SafeExamBrowser\Application\SafeExamBrowser.exe","${env:ProgramFiles(x86)}\SafeExamBrowser\Application\SafeExamBrowser.exe")){
    if(Test-Path $path){ $sebInst += [pscustomobject]@{Name="Safe Exam Browser";Ver=(Get-Item $path).VersionInfo.ProductVersion} }
  }
}
$sebStatus = "NA"; $sebText = ""
$sebCur = $null
if($sebInst.Count -gt 0){
  $sebCur = $sebInst | Sort-Object { Get-Ver3 $_.Ver } -Descending | Select-Object -First 1
  Write-Host ("SEB terpasang : {0} (versi {1})" -f $sebCur.Name,$sebCur.Ver) -ForegroundColor White
} else {
  Write-Host "SEB belum terdeteksi terpasang di komputer ini." -ForegroundColor Yellow
}
$latestTxt = $null; $latestVer = $null
try {
  $api = Invoke-RestMethod -Uri $SEB_API -Headers @{"User-Agent"="Optimizer-SEB-V1"} -TimeoutSec 15
  $latestTxt = "$($api.tag_name)" -replace '^[vV]',''
  $latestVer = Get-Ver3 $latestTxt
} catch {}
if($latestVer){ Write-Host ("SEB terbaru   : {0}" -f $latestTxt) -ForegroundColor White }
else { Write-Host "SEB terbaru   : tidak dapat dicek (internet/GitHub tidak dapat diakses)" -ForegroundColor Yellow }

if(-not $sebCur){
  $sebStatus = "NOTFOUND"; $sebText = "SEB tidak terdeteksi - install SEB dari $SEB_DOWNLOAD"
  $peringatan += "SEB belum terdeteksi. Unduh dan install dari $SEB_DOWNLOAD (atau sesuai arahan panitia)."
} elseif(-not $latestVer){
  $sebStatus = "UNKNOWN"; $sebText = "versi $($sebCur.Ver) (pengecekan versi terbaru gagal, cek manual di safeexambrowser.org)"
  $peringatan += "Versi terbaru SEB tidak dapat dicek. Silakan cek manual: $SEB_DOWNLOAD"
} else {
  $curVer = Get-Ver3 $sebCur.Ver
  if($curVer -and $curVer -ge $latestVer){
    $sebStatus = "OK"; $sebText = "versi $($sebCur.Ver) - SUDAH TERBARU"
    Write-Host "Versi SEB sudah yang terbaru." -ForegroundColor Green
  } else {
    $sebStatus = "OLD"; $sebText = "versi $($sebCur.Ver) BELUM TERBARU (terbaru: $latestTxt)"
    Write-Host "VERSI SEB BELUM TERBARU. Silakan CHECK UPDATE / unduh versi terbaru di:" -ForegroundColor Red
    Write-Host "  $SEB_DOWNLOAD" -ForegroundColor Red
    Write-Host "  (Jika panitia ujian mewajibkan versi tertentu, ikuti ketentuan panitia.)" -ForegroundColor Yellow
    $peringatan += "SEB belum versi terbaru (terpasang $($sebCur.Ver), terbaru $latestTxt). Mohon check update: $SEB_DOWNLOAD"
    $ans = Read-Host "`nBuka halaman unduh SEB sekarang? (Y/N)"
    if($ans -match '^[Yy]'){ Start-Process $SEB_DOWNLOAD }
  }
}

# ---------------------------------------------------------------
H "4. PING KE INTERNET, E-LEARNING, DAN SEB"
Write-Host "Ping DNS Google (8.8.8.8)..." -ForegroundColor White
$pg  = Test-Ping "8.8.8.8" $PING_COUNT
Show-Ping "DNS Google" $pg
Write-Host "`nPing google.com (uji resolusi DNS)..." -ForegroundColor White
$pgn = Test-Ping "google.com" $PING_COUNT
Show-Ping "Google.com" $pgn
Write-Host "`nPing e-learning..." -ForegroundColor White
$pel = Test-Ping $ELEARN_HOST $PING_COUNT
Show-Ping "E-learning" $pel
Write-Host "`nPing jaringan SEB (informasi saja, tidak mempengaruhi hasil)..." -ForegroundColor White
$psb = Test-Ping $SEB_HOST $PING_COUNT
Show-Ping "SEB" $psb

# ---------------------------------------------------------------
H "5. UJI AKSES SEB DAN E-LEARNING (HTTPS)"
Write-Host "Mengakses $SEB_URL ..." -ForegroundColor White
$wsb = Test-Web $SEB_URL
if($wsb.OK){ Write-Host ("  SEB: DAPAT DIAKSES (HTTP {0}, {1} ms)" -f $wsb.Code,$wsb.Ms) -ForegroundColor Green } else { Write-Host ("  SEB: GAGAL DIAKSES {0}" -f $wsb.Err) -ForegroundColor Red }
Write-Host "Mengakses $ELEARN_URL ..." -ForegroundColor White
$wel = Test-Web $ELEARN_URL
if($wel.OK){ Write-Host ("  E-learning: DAPAT DIAKSES (HTTP {0}, {1} ms)" -f $wel.Code,$wel.Ms) -ForegroundColor Green } else { Write-Host ("  E-learning: GAGAL DIAKSES {0}" -f $wel.Err) -ForegroundColor Red }

# ---------------------------------------------------------------
H "6. SPEED TEST"
$down = $null; $up = $null
try {
  Add-Type -AssemblyName System.Net.Http
  $client = [System.Net.Http.HttpClient]::new()
  $client.Timeout = [TimeSpan]::FromSeconds(90)
  $client.DefaultRequestHeaders.UserAgent.ParseAdd("Optimizer-SEB-V1")

  Write-Host "Mengukur download (maks. 12 detik)..." -ForegroundColor White
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $resp = $client.GetAsync("https://speed.cloudflare.com/__down?bytes=20000000",[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
  $resp.EnsureSuccessStatusCode() | Out-Null
  $stream = $resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
  $buf = New-Object byte[] 65536; [long]$total = 0
  while(($n = $stream.Read($buf,0,$buf.Length)) -gt 0){ $total += $n; if($sw.Elapsed.TotalSeconds -ge 12){ break } }
  $sw.Stop(); $stream.Dispose(); $resp.Dispose()
  $down = [math]::Round(($total*8/$sw.Elapsed.TotalSeconds/1000000),2)
  Write-Host "  DOWNLOAD: $down Mbps" -ForegroundColor Green

  Write-Host "Mengukur upload (3 MB)..." -ForegroundColor White
  $bytes = New-Object byte[] 3000000
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create(); $rng.GetBytes($bytes)
  $content = [System.Net.Http.ByteArrayContent]::new($bytes)
  $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/octet-stream")
  $sw.Restart()
  $ur = $client.PostAsync("https://speed.cloudflare.com/__up",$content).GetAwaiter().GetResult()
  $ur.EnsureSuccessStatusCode() | Out-Null
  $null = $ur.Content.ReadAsStringAsync().GetAwaiter().GetResult()
  $sw.Stop()
  $up = [math]::Round(($bytes.Length*8/$sw.Elapsed.TotalSeconds/1000000),2)
  Write-Host "  UPLOAD  : $up Mbps" -ForegroundColor Green
  $client.Dispose()
} catch {
  Write-Host "Speed test sebagian/seluruhnya gagal: koneksi/endpoint tidak tersedia." -ForegroundColor Yellow
}

# ---------------------------------------------------------------
H "7. KESIMPULAN HASIL PEMERIKSAAN"
$global:rep = @()

# Aplikasi terlarang
if($found.Count -eq 0){
  Row "OK" "Aplikasi terlarang" "TIDAK DITEMUKAN"
} else {
  Row "BAD" "Aplikasi terlarang" ("DITEMUKAN {0} item - harus ditutup/dihapus!" -f $found.Count)
  $found | ForEach-Object { $line = "         -> $_"; Write-Host $line -ForegroundColor Red; $global:rep += $line }
  $masalah += "Ditemukan aplikasi/proses yang tidak boleh digunakan. Tutup atau uninstall lalu cek ulang."
}

# DNS & IP
if($dnsOK -eq $null){ Row "WARN" "Flush DNS / IP renew" "DILEWATI (tidak berjalan sebagai Administrator)"; $peringatan += "Flush DNS dan IP renew dilewati. Jalankan sebagai Administrator." }
else {
  if($dnsOK){ Row "OK" "Flush DNS" "BERHASIL" } else { Row "BAD" "Flush DNS" "GAGAL"; $masalah += "Flush DNS gagal." }
  if($renewOK -and $ipAfter.Count -gt 0){
    Row "OK" "IP terbaru" ("SUDAH DIPERBARUI ({0})" -f $ipText)
  } else {
    Row "BAD" "IP terbaru" "GAGAL / tidak mendapat IP"
    $masalah += "IP renew gagal atau tidak ada IP aktif. Periksa koneksi Wi-Fi/LAN."
  }
}

# SEB version
switch($sebStatus){
  "OK"       { Row "OK"   "Versi SEB" $sebText }
  "OLD"      { Row "WARN" "Versi SEB" $sebText; Write-Host "         -> Mohon CHECK UPDATE SEB terbaru: $SEB_DOWNLOAD" -ForegroundColor Yellow; $global:rep += "         -> Mohon CHECK UPDATE SEB terbaru: $SEB_DOWNLOAD" }
  "NOTFOUND" { Row "WARN" "Versi SEB" $sebText }
  default    { Row "WARN" "Versi SEB" $sebText }
}

# Internet: ping DNS Google
if($pg.OK){
  $st = if($pg.Avg -le 200 -and $pg.Loss -lt 20){"OK"}else{"WARN"}
  Row $st "Internet (DNS Google)" ("rata-rata {0} ms (min {1} / maks {2} ms), loss {3}% -> {4}" -f $pg.Avg,$pg.Min,$pg.Max,$pg.Loss,(Rate-Latency $pg.Avg))
  if($pg.Avg -gt 200){ $peringatan += "Latensi ke Google tinggi ($($pg.Avg) ms). Koneksi mungkin kurang stabil." }
  if($pg.Loss -ge 20){ $peringatan += "Terjadi packet loss $($pg.Loss)% saat ping Google. Koneksi kurang stabil." }
} else {
  Row "BAD" "Internet (DNS Google)" "TIDAK ADA BALASAN - internet bermasalah"
  $masalah += "Tidak ada koneksi internet (ping DNS Google 8.8.8.8 gagal)."
}
# Resolusi DNS
if($pgn.OK){ Row "OK" "Resolusi DNS (google.com)" ("BERHASIL, rata-rata {0} ms" -f $pgn.Avg) }
elseif(-not $pgn.Resolved){ Row "BAD" "Resolusi DNS (google.com)" "GAGAL - DNS bermasalah"; $masalah += "DNS tidak dapat me-resolve nama domain. Coba ganti DNS ke 8.8.8.8 atau ulangi koneksi Wi-Fi." }
else { Row "WARN" "Resolusi DNS (google.com)" "nama ter-resolve, tetapi ping tidak dibalas" }

# Ping e-learning
if($pel.OK){
  $st = if($pel.Avg -le 200 -and $pel.Loss -lt 20){"OK"}else{"WARN"}
  Row $st "Ping e-learning" ("rata-rata {0} ms (min {1} / maks {2} ms), loss {3}% -> {4}" -f $pel.Avg,$pel.Min,$pel.Max,$pel.Loss,(Rate-Latency $pel.Avg))
  if($pel.Avg -gt 200){ $peringatan += "Latensi ke e-learning tinggi ($($pel.Avg) ms)." }
  if($pel.Loss -ge 20){ $peringatan += "Packet loss $($pel.Loss)% ke e-learning. Koneksi kurang stabil." }
} elseif(-not $pel.Resolved){
  Row "BAD" "Ping e-learning" "GAGAL - nama server tidak ter-resolve"
  $masalah += "Alamat e-learning ($ELEARN_HOST) tidak ter-resolve. Periksa DNS/internet."
} else {
  Row "WARN" "Ping e-learning" "tidak ada balasan ping (lihat uji akses HTTPS di bawah)"
  $peringatan += "Ping ke e-learning tidak dibalas. Pastikan akses HTTPS e-learning AMAN."
}

# Ping SEB: informasi saja
if($psb.OK){ Row "OK" "Ping jaringan SEB" ("rata-rata {0} ms, loss {1}%" -f $psb.Avg,$psb.Loss) }
else { Row "OK" "Ping jaringan SEB" "tidak merespon - TIDAK MASALAH (informasi saja)" }

# Akses HTTPS
if($wel.OK){ Row "OK" "Akses ke e-learning" ("AMAN - dapat diakses (HTTP {0}, {1} ms)" -f $wel.Code,$wel.Ms) } else { Row "BAD" "Akses ke e-learning" "GAGAL DIAKSES"; $masalah += "E-learning ($ELEARN_HOST) tidak dapat diakses." }
if($wsb.OK){ Row "OK" "Akses ke situs SEB" ("AMAN - dapat diakses (HTTP {0})" -f $wsb.Code) } else { Row "WARN" "Akses ke situs SEB" "tidak dapat diakses (hanya berpengaruh pada unduh/update SEB)"; $peringatan += "Situs SEB ($SEB_HOST) tidak dapat diakses; unduh/update SEB mungkin terkendala." }

# Speed
if($down -ne $null -and $up -ne $null){
  $txt = "Download {0} Mbps | Upload {1} Mbps" -f $down,$up
  if($down -lt $MIN_MBPS -or $up -lt $MIN_MBPS){
    Row "WARN" "Kecepatan internet" ($txt + " -> INTERNET LAMBAT (di bawah $MIN_MBPS Mbps)")
    $peringatan += "Internet LAMBAT (di bawah $MIN_MBPS Mbps). Pindah ke jaringan yang lebih cepat/dekati router."
  } else {
    Row "OK" "Kecepatan internet" ($txt + " -> INTERNET NORMAL (di atas $MIN_MBPS Mbps)")
  }
} elseif($down -ne $null){
  $txt = "Download {0} Mbps | Upload tidak terukur" -f $down
  if($down -lt $MIN_MBPS){ Row "WARN" "Kecepatan internet" ($txt + " -> INTERNET LAMBAT (di bawah $MIN_MBPS Mbps)"); $peringatan += "Internet LAMBAT (di bawah $MIN_MBPS Mbps)." }
  else { Row "OK" "Kecepatan internet" ($txt + " -> INTERNET NORMAL (di atas $MIN_MBPS Mbps)") }
} else {
  Row "WARN" "Kecepatan internet" "tidak dapat diukur (endpoint speed test tidak tersedia)"
  $peringatan += "Speed test gagal, kecepatan internet tidak dapat dipastikan."
}

# Kesimpulan akhir
Write-Host ""
Write-Host "----------------------------------------------------------------" -ForegroundColor DarkCyan
if($masalah.Count -eq 0 -and $peringatan.Count -eq 0){
  $verdict = "LOLOS PEMERIKSAAN: jaringan, akses SEB & e-learning AMAN. Komputer siap lanjut uji buka SEB."
  Write-Host " $verdict" -ForegroundColor Green
} elseif($masalah.Count -eq 0){
  $verdict = "LOLOS DENGAN CATATAN: ada hal yang perlu diperhatikan (lihat di bawah)."
  Write-Host " $verdict" -ForegroundColor Yellow
} else {
  $verdict = "BELUM LOLOS: perbaiki item merah di bawah lalu jalankan ulang."
  Write-Host " $verdict" -ForegroundColor Red
}
if($masalah.Count -gt 0){ Write-Host "`n Yang harus diperbaiki:" -ForegroundColor Red; $masalah | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red } }
if($peringatan.Count -gt 0){ Write-Host "`n Perlu diperhatikan:" -ForegroundColor Yellow; $peringatan | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow } }
Write-Host "----------------------------------------------------------------" -ForegroundColor DarkCyan

# ---------------------------------------------------------------
H "8. CATATAN"
Write-Host "Gunakan SSID Wi-Fi resmi untuk ujian." -ForegroundColor White
Write-Host "Settings > Network & Internet > Wi-Fi > Manage known networks." -ForegroundColor White
Write-Host "Pada Wi-Fi lain yang tersimpan, matikan opsi Connect automatically." -ForegroundColor White
Write-Host "Pastikan komputer hanya terhubung ke Wi-Fi ujian yang ditentukan." -ForegroundColor White
Write-Host ""
Write-Host "PENTING:" -ForegroundColor Yellow
Write-Host "Hasil script ini bukan sertifikasi keamanan atau alat untuk menyadap;" -ForegroundColor Yellow
Write-Host "alat ini hanya untuk pengecekan jaringan." -ForegroundColor Yellow
Write-Host "Lakukan uji buka SEB sebelum sesi ujian dimulai." -ForegroundColor Yellow

Write-Host "`nHasil tidak disimpan ke file. Scroll ke atas untuk melihat seluruh hasil." -ForegroundColor Cyan
Read-Host "`nTekan ENTER untuk keluar"
