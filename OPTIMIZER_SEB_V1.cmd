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

function Rate-Jitter($ms){
  if($ms -le 10){ return "BAIK" } elseif($ms -le 30){ return "CUKUP" } else { return "TINGGI (koneksi tidak stabil)" }
}
function Rate-BB($inc){
  if($inc -le 30){ return "BAIK (tidak ada bufferbloat berarti)" }
  elseif($inc -le 100){ return "RINGAN" }
  elseif($inc -le 200){ return "SEDANG (rawan lag saat unduh/unggah)" }
  else { return "BERAT (rawan lag/putus saat ujian)" }
}
function Test-Jitter($target,$count){
  $p = New-Object System.Net.NetworkInformation.Ping
  $t = @(); $lost = 0
  for($i=0;$i -lt $count;$i++){
    try { $r = $p.Send($target,1000); if($r.Status -eq "Success"){ $t += [int]$r.RoundtripTime } else { $lost++ } } catch { $lost++ }
    Start-Sleep -Milliseconds 80
  }
  $o = [pscustomobject]@{OK=$false;Jitter=0;Avg=0;Max=0;Lost=$lost;Sent=$count}
  if($t.Count -ge 2){
    $d = @(); for($i=1;$i -lt $t.Count;$i++){ $d += [math]::Abs($t[$i]-$t[$i-1]) }
    $m = $t | Measure-Object -Maximum -Average
    $o.Jitter = [math]::Round(($d | Measure-Object -Average).Average,1)
    $o.Avg = [int][math]::Round($m.Average); $o.Max = [int]$m.Maximum; $o.OK = $true
  }
  return $o
}
function Measure-Loaded($mode){
  $wcs = @(); $tmp = @()
  $o = [pscustomobject]@{OK=$false;Avg=0;Max=0;Lost=0;Sent=0;MB=0}
  try {
    if($mode -eq "down"){
      foreach($i in 1..3){
        $wc = New-Object Net.WebClient; $wc.Headers.Add("User-Agent","Optimizer-SEB-V1")
        $f = Join-Path $env:TEMP ("seb_bb_{0}.tmp" -f [guid]::NewGuid().ToString("N"))
        $tmp += $f
        $wc.DownloadFileAsync([uri]"https://speed.cloudflare.com/__down?bytes=100000000",$f)
        $wcs += $wc
      }
    } else {
      $bytes = New-Object byte[] 20000000
      (New-Object Random).NextBytes($bytes)
      foreach($i in 1..3){
        $wc = New-Object Net.WebClient; $wc.Headers.Add("User-Agent","Optimizer-SEB-V1")
        $wc.UploadDataAsync([uri]"https://speed.cloudflare.com/__up","POST",$bytes)
        $wcs += $wc
      }
    }
    Start-Sleep 1
    $p = New-Object System.Net.NetworkInformation.Ping
    $t = @(); $lost = 0; $sent = 0
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while($sw.Elapsed.TotalSeconds -lt 4){
      $sent++
      try { $r = $p.Send("8.8.8.8",1500); if($r.Status -eq "Success"){ $t += [int]$r.RoundtripTime } else { $lost++ } } catch { $lost++ }
      Start-Sleep -Milliseconds 120
    }
    $o.Sent = $sent; $o.Lost = $lost
    if($t.Count -gt 0){
      $m = $t | Measure-Object -Maximum -Average
      $o.Avg = [int][math]::Round($m.Average); $o.Max = [int]$m.Maximum; $o.OK = $true
    }
    if($mode -eq "down"){
      $bytesGot = 0
      foreach($f in $tmp){ $it = Get-Item -LiteralPath $f -ErrorAction SilentlyContinue; if($it){ $bytesGot += $it.Length } }
      $o.MB = [math]::Round($bytesGot/1MB,1)
      if($o.MB -lt 0.5){ $o.OK = $false }
    }
  } catch {
  } finally {
    foreach($wc in $wcs){ try { $wc.CancelAsync() } catch {}; try { $wc.Dispose() } catch {} }
    Start-Sleep -Milliseconds 200
    foreach($f in $tmp){ Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
  }
  return $o
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
H "4. DETEKSI VIRTUAL MACHINE / HYPERVISOR"
Write-Host "Memeriksa penyebab umum SEB menganggap laptop sebagai virtual machine..." -ForegroundColor White
$vmStrong = @(); $vmWeak = @()
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$bb = Get-CimInstance Win32_BaseBoard
Write-Host ("  Perangkat : {0} {1}" -f $cs.Manufacturer,$cs.Model) -ForegroundColor White
Write-Host ("  BIOS      : {0} {1}" -f $bios.Manufacturer,$bios.SMBIOSBIOSVersion) -ForegroundColor White
Write-Host ("  Mainboard : {0} {1}" -f $bb.Manufacturer,$bb.Product) -ForegroundColor White
$vmRegex = "vmware|virtualbox|vbox|qemu|\bkvm\b|\bxen\b|parallels|bochs|innotek|virtual machine|virtual platform|hyper-v|bhyve|openstack"
$hwText = (@($cs.Manufacturer,$cs.Model,$bios.Manufacturer,$bios.SMBIOSBIOSVersion,$bb.Manufacturer,$bb.Product) -join " | ")
if($hwText -match $vmRegex){ $vmStrong += "Identitas perangkat/BIOS terbaca seperti mesin virtual: $hwText" }
if($cs.HypervisorPresent){ $vmWeak += "Hypervisor aktif di Windows (Hyper-V, VBS, WSL2, Windows Sandbox, atau emulator Android). Windows berjalan di atas lapisan virtualisasi." }
$feats = @(); $hvciOn = $false; $vbsOn = $false; $vmFixed = $false; $needRestart = $false
$dg = Get-CimInstance -Namespace "root\Microsoft\Windows\DeviceGuard" -ClassName Win32_DeviceGuard
if($dg){
  if($dg.VirtualizationBasedSecurityStatus -eq 2){ $vbsOn = $true; $vmWeak += "Virtualization-Based Security (VBS) sedang berjalan." }
  if(@($dg.SecurityServicesRunning) -contains 2){ $hvciOn = $true; $vmWeak += "Memory Integrity / Core Isolation (HVCI) aktif." }
}
if($isAdmin){
  Write-Host "  Memeriksa fitur Windows (beberapa detik)..." -ForegroundColor DarkGray
  $featNames = @("Microsoft-Hyper-V-All","Microsoft-Hyper-V","VirtualMachinePlatform","HypervisorPlatform","Containers-DisposableClientVM","Microsoft-Windows-Subsystem-Linux")
  $feats = @(Get-WindowsOptionalFeature -Online | Where-Object { $featNames -contains $_.FeatureName -and $_.State -eq "Enabled" })
  foreach($f in $feats){ $vmWeak += "Fitur Windows aktif: $($f.FeatureName)" }
} else {
  Write-Host "  (Fitur Windows tidak diperiksa: butuh Administrator)" -ForegroundColor DarkGray
}
foreach($d in @(Get-CimInstance Win32_DiskDrive)){
  if(("$($d.Model) $($d.Caption) $($d.PNPDeviceID)") -match "virtual|vbox|vmware|qemu"){ $vmStrong += "Disk virtual terdeteksi: $($d.Model) ($($d.PNPDeviceID)). Biasanya dibuat oleh WSL/Windows Sandbox/Hyper-V atau VHD yang di-mount." }
}
$ouis = @{"00:50:56"="VMware";"00:0C:29"="VMware";"00:05:69"="VMware";"00:1C:14"="VMware";"08:00:27"="VirtualBox";"0A:00:27"="VirtualBox";"00:15:5D"="Hyper-V";"00:1C:42"="Parallels";"52:54:00"="QEMU/KVM";"00:16:3E"="Xen"}
foreach($n in @(Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.MACAddress })){
  $oui = $n.MACAddress.Substring(0,8).ToUpper()
  if($ouis.ContainsKey($oui)){
    $msg = "Adapter jaringan virtual ({0}): {1} [{2}]" -f $ouis[$oui],$n.Name,$n.MACAddress
    if($ouis[$oui] -eq "Hyper-V"){ $vmWeak += $msg } else { $vmStrong += $msg }
  }
}
$procNames = @(Get-Process | Select-Object -ExpandProperty ProcessName -Unique)
foreach($pn in $procNames){
  if($pn -match "^(vmmem.*|vmware-vmx|VBoxHeadless|VirtualBoxVM|qemu-system.*|prl_vm_app|HD-Player|LdVBoxHeadless|MEmu.*)$"){ $vmStrong += "Mesin virtual sedang berjalan: proses $pn" }
  elseif($pn -match "^(vmms|vmwp|vmcompute|wslservice|wslhost|wsl)$"){ $vmWeak += "Layanan virtualisasi aktif: proses $pn" }
}
foreach($a in @($apps | Where-Object { $_ -match "VMware|VirtualBox|Hyper-V|Parallels|QEMU|BlueStacks|LDPlayer|Nox|MEmu|Genymotion|Docker Desktop|Windows Subsystem" } | Sort-Object -Unique)){ $vmWeak += "Aplikasi virtualisasi/emulator terpasang: $a" }

if($vmStrong.Count -eq 0 -and $vmWeak.Count -eq 0){
  Write-Host "Tidak ada indikator virtual machine/hypervisor yang dikenal." -ForegroundColor Green
} else {
  if($vmStrong.Count -gt 0){ Write-Host "`nINDIKATOR KUAT (SEB berpotensi menolak start):" -ForegroundColor Red; $vmStrong | ForEach-Object { Write-Host "  [!!] $_" -ForegroundColor Red } }
  if($vmWeak.Count -gt 0){ Write-Host "`nINDIKATOR LEMAH (bisa memicu pada versi SEB tertentu):" -ForegroundColor Yellow; $vmWeak | ForEach-Object { Write-Host "  [!] $_" -ForegroundColor Yellow } }
  Write-Host "`nLangkah perbaikan manual (script hanya mengubah pengaturan jika Anda menjawab Y di bawah):" -ForegroundColor Cyan
  Write-Host "  1. Update SEB ke versi terbaru (beberapa versi lama salah mendeteksi VM)." -ForegroundColor White
  Write-Host "  2. Memory Integrity: Windows Security > Device security > Core isolation > Memory integrity = Off, lalu restart." -ForegroundColor White
  Write-Host "  3. Tekan Win+R, ketik optionalfeatures, lalu matikan Hyper-V, Virtual Machine Platform, Windows Hypervisor Platform, Windows Sandbox, WSL; restart." -ForegroundColor White
  Write-Host "  4. Alternatif (CMD Administrator): bcdedit /set hypervisorlaunchtype off lalu restart. Kembalikan setelah ujian: bcdedit /set hypervisorlaunchtype auto" -ForegroundColor White
  Write-Host "  5. Tutup emulator/VM (BlueStacks, LDPlayer, WSL, Docker, VMware, VirtualBox) dan lepas VHD yang di-mount." -ForegroundColor White
  Write-Host "  Catatan: mematikan fitur keamanan ini bersifat sementara; aktifkan kembali setelah ujian. Pada laptop kantor/kampus, konsultasikan ke admin." -ForegroundColor Yellow
}
$canFix = ($cs.HypervisorPresent -or $vbsOn -or $hvciOn -or $feats.Count -gt 0)
if($canFix){
  if(-not $isAdmin){
    Write-Host "`nUntuk mematikan virtualisasi otomatis, jalankan script sebagai Administrator." -ForegroundColor Yellow
  } else {
    $bl = $null
    try { $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop } catch {}
    if($bl -and "$($bl.ProtectionStatus)" -match "On|1"){
      Write-Host "`nPERINGATAN: BitLocker aktif di drive sistem. Pastikan kunci pemulihan BitLocker tersedia sebelum melanjutkan." -ForegroundColor Red
    }
    Write-Host "`nYang akan dilakukan jika Anda menjawab Y (semua dapat dikembalikan):" -ForegroundColor Cyan
    Write-Host "  - Membuat restore point (jika System Protection aktif)" -ForegroundColor White
    Write-Host "  - bcdedit /set hypervisorlaunchtype off" -ForegroundColor White
    if($hvciOn){ Write-Host "  - Mematikan Memory Integrity (HVCI)" -ForegroundColor White }
    if($vbsOn){ Write-Host "  - Mematikan Virtualization-Based Security (VBS)" -ForegroundColor White }
    foreach($f in $feats){ Write-Host ("  - Mematikan fitur Windows: {0}" -f $f.FeatureName) -ForegroundColor White }
    Write-Host "  Setelah itu komputer HARUS direstart. Hyper-V/WSL/Sandbox/emulator tidak akan berfungsi sampai diaktifkan kembali." -ForegroundColor Yellow
    $ansVm = Read-Host "`nMatikan virtualisasi sekarang? (Y/N)"
    if($ansVm -match '^[Yy]'){
      try { Checkpoint-Computer -Description "OPTIMIZER SEB sebelum matikan virtualisasi" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop; Write-Host "  Restore point dibuat." -ForegroundColor Green }
      catch { Write-Host "  (Restore point tidak dibuat: System Protection nonaktif atau baru dibuat dalam 24 jam terakhir)" -ForegroundColor DarkGray }
      $okAll = $true
      $null = bcdedit /set hypervisorlaunchtype off 2>&1
      if($LASTEXITCODE -eq 0){ Write-Host "  [OK] Hypervisor dimatikan saat boot berikutnya." -ForegroundColor Green } else { Write-Host "  [GAGAL] bcdedit hypervisorlaunchtype" -ForegroundColor Red; $okAll = $false }
      if($hvciOn){
        try {
          $hk = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
          if(-not (Test-Path $hk)){ New-Item -Path $hk -Force | Out-Null }
          New-ItemProperty -Path $hk -Name "Enabled" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
          Write-Host "  [OK] Memory Integrity dimatikan." -ForegroundColor Green
        } catch { Write-Host "  [GAGAL] Memory Integrity (mungkin diatur oleh kebijakan/admin)" -ForegroundColor Red; $okAll = $false }
      }
      if($vbsOn){
        try {
          $vk = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
          New-ItemProperty -Path $vk -Name "EnableVirtualizationBasedSecurity" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
          Write-Host "  [OK] VBS dimatikan." -ForegroundColor Green
        } catch { Write-Host "  [GAGAL] VBS (mungkin diatur oleh kebijakan/admin)" -ForegroundColor Red; $okAll = $false }
      }
      foreach($f in $feats){
        Write-Host ("  Mematikan fitur {0} (mohon tunggu)..." -f $f.FeatureName) -ForegroundColor DarkGray
        try { Disable-WindowsOptionalFeature -Online -FeatureName $f.FeatureName -NoRestart -ErrorAction Stop | Out-Null; Write-Host ("  [OK] {0} dimatikan." -f $f.FeatureName) -ForegroundColor Green }
        catch { Write-Host ("  [GAGAL] {0}" -f $f.FeatureName) -ForegroundColor Red; $okAll = $false }
      }
      if($okAll){
        $vmFixed = $true; $needRestart = $true
        Write-Host "`nSelesai. RESTART komputer, lalu jalankan OPTIMIZER lagi untuk memastikan." -ForegroundColor Green
      } else {
        Write-Host "`nSebagian langkah gagal. Gunakan langkah manual di atas atau hubungi admin." -ForegroundColor Yellow
        $needRestart = $true
      }
      Write-Host "`nUntuk MENGAKTIFKAN KEMBALI setelah ujian:" -ForegroundColor Cyan
      Write-Host "  bcdedit /set hypervisorlaunchtype auto   (CMD Administrator, lalu restart)" -ForegroundColor White
      Write-Host "  Memory Integrity: Windows Security > Device security > Core isolation details" -ForegroundColor White
      Write-Host "  Fitur Windows: Win+R > optionalfeatures" -ForegroundColor White
    }
  }
}
$sebLogDir = Join-Path $env:LOCALAPPDATA "SafeExamBrowser"
if(Test-Path -LiteralPath $sebLogDir){
  $logHits = @()
  foreach($lf in @(Get-ChildItem -LiteralPath $sebLogDir -Recurse -Filter *.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3)){
    $logHits += @(Select-String -LiteralPath $lf.FullName -Pattern "virtual" -ErrorAction SilentlyContinue | Select-Object -First 3 | ForEach-Object { $_.Line.Trim() })
  }
  if($logHits.Count -gt 0){
    Write-Host "`nCatatan dari log SEB sebelumnya (kata 'virtual'):" -ForegroundColor Cyan
    $logHits | Select-Object -First 5 | ForEach-Object { $t = $_; if($t.Length -gt 180){ $t = $t.Substring(0,180) }; Write-Host "  $t" -ForegroundColor DarkGray }
  }
}
Write-Host "Catatan: pemeriksaan ini perkiraan; SEB punya aturan deteksi sendiri. Jika SEB tetap menolak, kirim nama/model laptop di atas dan log SEB ke panitia." -ForegroundColor DarkGray

# ---------------------------------------------------------------
H "5. SCAN REGISTRY DAN INTEGRITAS SEB"
$regStrong = @(); $regWarn = @(); $regFixedCount = 0; $regBackupDir = ""
$sebRunNow = @(Get-Process | Where-Object { $_.ProcessName -like "SafeExamBrowser*" -and $_.ProcessName -notlike "*Service*" }).Count -gt 0
$polNames = @("DisableLockWorkstation","DisableChangePassword","DisableTaskMgr","HideFastUserSwitching")
$polKeys = @(
  @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System";   Names=$polNames},
  @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System";   Names=$polNames},
  @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Names=@("NoLogoff","NoClose")},
  @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Names=@("NoLogoff","NoClose")},
  @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU";        Names=@("NoAutoUpdate")}
)
$regLeft = @()
foreach($pk in $polKeys){
  if(Test-Path -LiteralPath $pk.Path){
    foreach($nm in $pk.Names){
      $val = (Get-ItemProperty -LiteralPath $pk.Path -Name $nm -ErrorAction SilentlyContinue).$nm
      if($val -eq 1){ $regLeft += [pscustomobject]@{Path=$pk.Path;Name=$nm} }
    }
  }
}
if($regLeft.Count -eq 0){
  Write-Host "Registry: tidak ada sisa pengaturan Ctrl+Alt+Del/Task Manager/Update yang mengganggu." -ForegroundColor Green
} else {
  Write-Host "Ditemukan pengaturan registry yang dapat tertinggal setelah SEB crash/restart paksa:" -ForegroundColor Yellow
  $regLeft | ForEach-Object { Write-Host ("  - {0} : {1} = 1" -f $_.Path,$_.Name) -ForegroundColor Yellow }
  if($cs.PartOfDomain){ Write-Host "  Komputer ini bagian dari domain/kampus: kebijakan admin dapat menetapkan ulang nilai ini." -ForegroundColor DarkGray }
  Write-Host "  Catatan: nilai yang sama juga bisa sengaja diatur oleh admin/kebijakan kantor." -ForegroundColor DarkGray
  if($sebRunNow){
    Write-Host "  SEB sedang berjalan - tutup SEB dahulu agar registry dapat dipulihkan." -ForegroundColor Red
    $regWarn += "Ada sisa pengaturan registry SEB, tetapi SEB sedang berjalan. Tutup SEB lalu jalankan ulang."
  } elseif(-not $isAdmin){
    Write-Host "  Jalankan sebagai Administrator untuk memulihkan registry." -ForegroundColor Yellow
    $regWarn += "Ada sisa pengaturan registry SEB. Jalankan sebagai Administrator untuk memulihkannya."
  } else {
    $ansReg = Read-Host "`nPulihkan ke default Windows (nilai dihapus, backup .reg dibuat dulu)? (Y/N)"
    if($ansReg -match '^[Yy]'){
      $regBackupDir = Join-Path ([Environment]::GetFolderPath("Desktop")) ("SEB_Registry_Backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
      New-Item -ItemType Directory -Path $regBackupDir -Force | Out-Null
      $idx = 0
      foreach($pp in @($regLeft | Select-Object -ExpandProperty Path -Unique)){
        $idx++
        $regPath = $pp -replace '^HKLM:\\','HKEY_LOCAL_MACHINE\' -replace '^HKCU:\\','HKEY_CURRENT_USER\'
        $null = reg export $regPath (Join-Path $regBackupDir ("backup_{0}.reg" -f $idx)) /y 2>&1
      }
      foreach($it in $regLeft){
        try { Remove-ItemProperty -LiteralPath $it.Path -Name $it.Name -ErrorAction Stop; $regFixedCount++; Write-Host ("  [OK] {0} dipulihkan" -f $it.Name) -ForegroundColor Green }
        catch { Write-Host ("  [GAGAL] {0}" -f $it.Name) -ForegroundColor Red }
      }
      Write-Host ("Dipulihkan: {0} dari {1} nilai. Backup: {2}" -f $regFixedCount,$regLeft.Count,$regBackupDir) -ForegroundColor Cyan
      if($regFixedCount -lt $regLeft.Count){ $regWarn += "Sebagian nilai registry gagal dipulihkan (mungkin diatur kebijakan)." }
    } else { $regWarn += "Sisa pengaturan registry SEB belum dipulihkan (dilewati pengguna)." }
  }
}

# Integritas dan kelengkapan instalasi
$sebDir = @("$env:ProgramFiles\SafeExamBrowser","${env:ProgramFiles(x86)}\SafeExamBrowser") | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
$sebInstalledAny = ($sebInst.Count -gt 0) -or [bool]$sebDir
if($sebInstalledAny){
  if(-not $sebDir){ $regStrong += "Entri SEB ada di daftar program, tetapi folder program tidak ditemukan (instalasi rusak/sisa registry)." }
  else {
    Write-Host "`nMemeriksa keutuhan file SEB di $sebDir ..." -ForegroundColor DarkGray
    $badFiles = @()
    foreach($sf in @(Get-ChildItem -LiteralPath $sebDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "SafeExamBrowser*" -and ($_.Extension -eq ".exe" -or $_.Extension -eq ".dll") })){
      $sig = Get-AuthenticodeSignature -LiteralPath $sf.FullName
      if($sig.Status -eq "HashMismatch"){ $badFiles += $sf.Name }
    }
    if($badFiles.Count -gt 0){ $regStrong += ("File SEB berubah/rusak (tanda tangan tidak cocok): {0}" -f (($badFiles | Select-Object -First 5) -join ", ")) }
    else { Write-Host "  Keutuhan file SEB: tidak ada file yang rusak/dimodifikasi." -ForegroundColor Green }
  }
  $assocMissing = @()
  foreach($an in @(".seb","seb","sebs")){ if(-not (Test-Path -LiteralPath ("Registry::HKEY_CLASSES_ROOT\" + $an))){ $assocMissing += $an } }
  if($assocMissing.Count -gt 0){ $regWarn += ("Asosiasi file/protokol SEB tidak lengkap ({0}). Link ujian seb:// atau file .seb mungkin tidak membuka SEB." -f ($assocMissing -join ", ")) }
  $sebSvc = @(Get-Service | Where-Object { $_.Name -like "*SafeExam*" -or $_.DisplayName -like "*Safe Exam*" })
  if($sebSvc.Count -eq 0){ $regWarn += "Layanan (service) SEB tidak ditemukan; dapat menyebabkan error 'SEB Service' saat start." }
  else { $sebSvc | ForEach-Object { Write-Host ("  Layanan SEB: {0} ({1})" -f $_.DisplayName,$_.Status) -ForegroundColor DarkGray } }
}
if($apps | Where-Object { $_ -like "*Kaspersky Total Security*" }){
  $regStrong += "Kaspersky Total Security terpasang: dilaporkan tim SEB membuat SEB berstatus 'installation is corrupted'. Uninstall sebelum ujian."
}
$avHit = @($apps | Where-Object { $_ -match "Bitdefender|Kaspersky|ESET|Avast|AVG|Norton|McAfee|Avira" } | Sort-Object -Unique)
if($avHit.Count -gt 0){ $regWarn += ("Antivirus terdeteksi ({0}). Sebelum ujian, matikan fitur scan lalu lintas HTTPS (rekomendasi resmi SEB)." -f ($avHit -join ", ")) }

if($regStrong.Count -gt 0){ Write-Host "`nMasalah pada instalasi SEB:" -ForegroundColor Red; $regStrong | ForEach-Object { Write-Host "  [!!] $_" -ForegroundColor Red } }
if($regWarn.Count -gt 0){ Write-Host "`nCatatan:" -ForegroundColor Yellow; $regWarn | ForEach-Object { Write-Host "  [!] $_" -ForegroundColor Yellow } }
if($regStrong.Count -gt 0 -or $assocMissing.Count -gt 0 -or ($sebInstalledAny -and $sebSvc.Count -eq 0)){
  Write-Host "`nSolusi untuk instalasi bermasalah: uninstall SEB (ini juga memulihkan nilai registry yang diubah SEB), restart, lalu install ulang versi terbaru dari:" -ForegroundColor Cyan
  Write-Host "  $SEB_DOWNLOAD" -ForegroundColor Cyan
  $regReinstall = $true
}
Write-Host "Catatan: instalasi ulang adalah satu-satunya cara resmi membuat ulang registry/asosiasi bawaan SEB; script tidak menulis registry installer sendiri." -ForegroundColor DarkGray

# ---------------------------------------------------------------
H "6. BERSIHKAN KONFIGURASI SEB LAMA"
$cfgStatus = "NONE"; $cfgText = "tidak ada konfigurasi lama"; $cfgBackup = ""
$cfgPaths = @(
  @{Label="ProgramData";     Path=(Join-Path $env:ProgramData "SafeExamBrowser")},
  @{Label="AppData_Roaming"; Path=(Join-Path $env:APPDATA "SafeExamBrowser")},
  @{Label="AppData_Local";   Path=(Join-Path $env:LOCALAPPDATA "SafeExamBrowser")}
)
$cfgPaths = @($cfgPaths | Where-Object { Test-Path -LiteralPath $_.Path })
if($cfgPaths.Count -eq 0){
  Write-Host "Tidak ditemukan konfigurasi SEB lama." -ForegroundColor Green
} else {
  Write-Host "Ditemukan konfigurasi/data SEB lama:" -ForegroundColor White
  foreach($c in $cfgPaths){
    $sum = (Get-ChildItem -LiteralPath $c.Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Write-Host ("  - {0} ({1} KB)" -f $c.Path,[math]::Round($sum/1KB,1)) -ForegroundColor White
  }
  $running = @(Get-Process | Where-Object { $_.ProcessName -like "SafeExamBrowser*" -and $_.ProcessName -notlike "*Service*" })
  if($running.Count -gt 0){
    $cfgStatus = "RUNNING"; $cfgText = "DILEWATI - SEB sedang berjalan"
    Write-Host "SEB sedang berjalan. Tutup SEB sepenuhnya lalu jalankan ulang script ini." -ForegroundColor Red
    $peringatan += "SEB sedang berjalan sehingga konfigurasi lama tidak dibersihkan. Tutup SEB lalu jalankan ulang."
  } else {
    Write-Host "Folder di atas akan DIPINDAHKAN ke folder backup di Desktop (bukan dihapus permanen)." -ForegroundColor Yellow
    Write-Host "Aplikasi SEB tidak dihapus. Jika ujian memakai file konfigurasi dari kampus (SebClientSettings.seb)," -ForegroundColor Yellow
    Write-Host "kembalikan dari folder backup atau buka ulang file .seb/link ujian dari e-learning." -ForegroundColor Yellow
    $ans = Read-Host "`nBersihkan konfigurasi SEB lama sekarang? (Y/N)"
    if($ans -match '^[Yy]'){
      $cfgBackup = Join-Path ([Environment]::GetFolderPath("Desktop")) ("SEB_Config_Backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
      New-Item -ItemType Directory -Path $cfgBackup -Force | Out-Null
      $moved = 0; $fail = 0
      foreach($c in $cfgPaths){
        try { Move-Item -LiteralPath $c.Path -Destination (Join-Path $cfgBackup $c.Label) -Force -ErrorAction Stop; $moved++ }
        catch { $fail++; Write-Host ("  GAGAL memindahkan: {0}" -f $c.Path) -ForegroundColor Red }
      }
      if($fail -eq 0){
        Get-ChildItem -LiteralPath $cfgBackup -Recurse -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "cache" } | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
        $cfgStatus = "CLEANED"; $cfgText = "DIBERSIHKAN ($moved folder dipindah ke $cfgBackup; folder cache dihapus)"
        Write-Host "Konfigurasi SEB lama sudah dibersihkan." -ForegroundColor Green
        Write-Host "Backup: $cfgBackup (boleh dihapus setelah SEB berjalan normal)." -ForegroundColor DarkGray
      } else {
        $cfgStatus = "PARTIAL"; $cfgText = "SEBAGIAN GAGAL ($fail folder). Jalankan sebagai Administrator & tutup SEB."
        $peringatan += "Sebagian konfigurasi SEB lama gagal dibersihkan. Jalankan sebagai Administrator dan pastikan SEB tertutup."
      }
    } else {
      $cfgStatus = "SKIP"; $cfgText = "dilewati oleh pengguna"
    }
  }
}

# ---------------------------------------------------------------
H "7. WI-FI DAN MODE DAYA (PERFORMA)"
$pwrStatus = "SKIP"; $pwrText = "dilewati"
$wifiAd = @(Get-NetAdapter -Physical | Where-Object { $_.NdisPhysicalMedium -eq 9 -or "$($_.PhysicalMediaType)" -match "802.11" })
$guidRx = '([0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})'
$actLine = (powercfg /getactivescheme | Out-String).Trim()
$oldGuid = ""; if($actLine -match $guidRx){ $oldGuid = $matches[1] }
Write-Host ("Skema daya aktif : {0}" -f $actLine) -ForegroundColor White
if($wifiAd.Count -gt 0){ $wifiAd | ForEach-Object { Write-Host ("Adapter Wi-Fi    : {0} ({1})" -f $_.Name,$_.InterfaceDescription) -ForegroundColor White } } else { Write-Host "Adapter Wi-Fi    : tidak terdeteksi (pengaturan hanya diterapkan pada skema daya)" -ForegroundColor Yellow }
if(-not $isAdmin){
  Write-Host "Perlu Administrator untuk mengubah pengaturan daya. Langkah ini dilewati." -ForegroundColor Yellow
  $pwrText = "dilewati (bukan Administrator)"
} else {
  Write-Host "`nYang akan dilakukan jika Anda menjawab Y:" -ForegroundColor Cyan
  Write-Host "  - Mode daya Windows: Performa tertinggi (High performance / Best performance)" -ForegroundColor White
  Write-Host "  - Wireless Adapter Settings > Power Saving Mode = Maximum Performance (colok charger dan baterai)" -ForegroundColor White
  Write-Host "  - Mematikan 'Allow the computer to turn off this device to save power' pada adapter Wi-Fi" -ForegroundColor White
  Write-Host "  - Battery Saver tidak menyala otomatis" -ForegroundColor White
  Write-Host "  Catatan: baterai lebih cepat habis, sebaiknya laptop dicolok ke charger saat ujian." -ForegroundColor Yellow
  $ansP = Read-Host "`nAtur Wi-Fi dan mode daya ke PERFORMA sekarang? (Y/N)"
  if($ansP -match '^[Yy]'){
    $okCnt = 0; $failCnt = 0
    $null = powercfg /setactive SCHEME_MIN 2>&1
    if($LASTEXITCODE -ne 0){
      $dup = (powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-String)
      if($dup -match $guidRx){ $null = powercfg /setactive $matches[1] 2>&1 }
    }
    $null = powercfg /overlaysetactive OVERLAY_SCHEME_MAX 2>&1
    if($LASTEXITCODE -eq 0){ Write-Host "  [OK] Mode daya: performa tertinggi." -ForegroundColor Green; $okCnt++ } else { Write-Host "  [!] Overlay 'Best performance' tidak tersedia; memakai skema High performance." -ForegroundColor DarkGray }
    $sw1 = "19cbb8fa-5279-450e-9fac-8a3d5fedd0c1"; $sw2 = "12bbebe6-58d6-4636-95bb-3217ef867c1a"
    $null = powercfg /setacvalueindex SCHEME_CURRENT $sw1 $sw2 0 2>&1; $e1 = $LASTEXITCODE
    $null = powercfg /setdcvalueindex SCHEME_CURRENT $sw1 $sw2 0 2>&1; $e2 = $LASTEXITCODE
    $null = powercfg /setdcvalueindex SCHEME_CURRENT de830923-a562-41af-a086-e3a2c6bad2da e69653ca-cf7f-4f05-aa73-cb833fa90ad4 0 2>&1
    $null = powercfg /setactive SCHEME_CURRENT 2>&1
    if($e1 -eq 0 -and $e2 -eq 0){ Write-Host "  [OK] Wireless Adapter Power Saving Mode = Maximum Performance." -ForegroundColor Green; $okCnt++ } else { Write-Host "  [GAGAL] Pengaturan Wireless Adapter pada skema daya." -ForegroundColor Red; $failCnt++ }
    foreach($wa in $wifiAd){
      try { Set-NetAdapterPowerManagement -Name $wa.Name -AllowComputerToTurnOffDevice Disabled -ErrorAction Stop; Write-Host ("  [OK] {0}: tidak boleh dimatikan untuk hemat daya." -f $wa.Name) -ForegroundColor Green; $okCnt++ }
      catch { Write-Host ("  [!] {0}: driver tidak mendukung pengaturan ini (dapat diabaikan)." -f $wa.Name) -ForegroundColor DarkGray }
    }
    if($failCnt -eq 0){ $pwrStatus = "OK"; $pwrText = "PERFORMA aktif (Wi-Fi tidak hemat daya, Battery Saver tidak otomatis)" } else { $pwrStatus = "PARTIAL"; $pwrText = "sebagian pengaturan gagal diterapkan" }
    Write-Host "`nUntuk mengembalikan setelah ujian:" -ForegroundColor Cyan
    if($oldGuid){ Write-Host "  powercfg /setactive $oldGuid      (kembali ke skema daya sebelumnya)" -ForegroundColor White }
    Write-Host "  Pengaturan Wi-Fi: Control Panel > Power Options > Change plan settings > Wireless Adapter Settings" -ForegroundColor White
  } else { $pwrText = "dilewati oleh pengguna" }
}

# ---------------------------------------------------------------
H "8. PING KE INTERNET DAN E-LEARNING"
Write-Host "Ping DNS Google (8.8.8.8)..." -ForegroundColor White
$pg  = Test-Ping "8.8.8.8" $PING_COUNT
Show-Ping "DNS Google" $pg
Write-Host "`nPing google.com (uji resolusi DNS)..." -ForegroundColor White
$pgn = Test-Ping "google.com" $PING_COUNT
Show-Ping "Google.com" $pgn
Write-Host "`nPing e-learning..." -ForegroundColor White
$pel = Test-Ping $ELEARN_HOST $PING_COUNT
Show-Ping "E-learning" $pel

# ---------------------------------------------------------------
H "9. UJI AKSES E-LEARNING (HTTPS)"
Write-Host "Mengakses $ELEARN_URL ..." -ForegroundColor White
$wel = Test-Web $ELEARN_URL
if($wel.OK){ Write-Host ("  E-learning: DAPAT DIAKSES (HTTP {0}, {1} ms)" -f $wel.Code,$wel.Ms) -ForegroundColor Green } else { Write-Host ("  E-learning: GAGAL DIAKSES {0}" -f $wel.Err) -ForegroundColor Red }

# ---------------------------------------------------------------
H "10. SPEED TEST"
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
H "11. JITTER DAN BUFFERBLOAT"
$JTARGET = "8.8.8.8"
Write-Host "Mengukur jitter ke $JTARGET (12 ping, sekitar 2 detik)..." -ForegroundColor White
$jt = Test-Jitter $JTARGET 12
if($jt.OK){
  Write-Host ("  Jitter {0} ms | rata-rata {1} ms | lonjakan maks {2} ms | loss {3}/{4}" -f $jt.Jitter,$jt.Avg,$jt.Max,$jt.Lost,$jt.Sent) -ForegroundColor White
} else {
  Write-Host "  Jitter tidak dapat diukur (ping gagal)." -ForegroundColor Yellow
}
$bbDown = $null; $bbUp = $null
if($down -ne $null -and $jt.OK){
  Write-Host "`nUji bufferbloat saat DOWNLOAD penuh (sekitar 5 detik)..." -ForegroundColor White
  $bbDown = Measure-Loaded "down"
  if($bbDown.OK){ Write-Host ("  Ping saat download: rata-rata {0} ms | maks {1} ms | loss {2}/{3}" -f $bbDown.Avg,$bbDown.Max,$bbDown.Lost,$bbDown.Sent) -ForegroundColor White } else { Write-Host "  Tidak dapat diukur." -ForegroundColor Yellow }
  Write-Host "`nUji bufferbloat saat UPLOAD penuh (sekitar 5 detik)..." -ForegroundColor White
  $bbUp = Measure-Loaded "up"
  if($bbUp.OK){ Write-Host ("  Ping saat upload  : rata-rata {0} ms | maks {1} ms | loss {2}/{3}" -f $bbUp.Avg,$bbUp.Max,$bbUp.Lost,$bbUp.Sent) -ForegroundColor White } else { Write-Host "  Tidak dapat diukur." -ForegroundColor Yellow }
} else {
  Write-Host "Uji bufferbloat dilewati (speed test/ping belum berhasil)." -ForegroundColor Yellow
}

# ---------------------------------------------------------------
H "12. KESIMPULAN HASIL PEMERIKSAAN"
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

# Deteksi virtual machine
if($vmFixed){
  Row "WARN" "Deteksi Virtual Machine" "virtualisasi sudah dimatikan - RESTART diperlukan, lalu jalankan ulang"
  $peringatan += "Virtualisasi baru dimatikan. Restart komputer lalu jalankan OPTIMIZER lagi untuk memastikan."
} elseif($vmStrong.Count -gt 0){
  Row "BAD" "Deteksi Virtual Machine" ("{0} indikator KUAT - SEB berpotensi menolak start" -f $vmStrong.Count)
  $masalah += "Terdeteksi indikator virtual machine yang kuat. SEB dapat menolak start. Lihat langkah perbaikan di bagian 4."
} elseif($vmWeak.Count -gt 0){
  Row "WARN" "Deteksi Virtual Machine" ("{0} indikator lemah (Hyper-V/VBS/WSL/emulator) - dapat memicu SEB 'virtual machine'" -f $vmWeak.Count)
  $peringatan += "Ada fitur virtualisasi aktif (Hyper-V/VBS/WSL/emulator). Jika SEB menolak start dengan pesan virtual machine, ikuti langkah di bagian 4 dan update SEB."
} else {
  Row "OK" "Deteksi Virtual Machine" "tidak ada indikator VM/hypervisor"
}

# Registry dan integritas SEB
if($regLeft.Count -eq 0){ Row "OK" "Registry SEB" "bersih (tidak ada sisa pengaturan)" }
elseif($regFixedCount -eq $regLeft.Count){ Row "OK" "Registry SEB" ("DIPULIHKAN ({0} nilai, backup: {1})" -f $regFixedCount,$regBackupDir) }
else { Row "WARN" "Registry SEB" ("{0} nilai tertinggal belum dipulihkan" -f ($regLeft.Count - $regFixedCount)) }
if($regStrong.Count -gt 0){
  Row "BAD" "Integritas instalasi SEB" ("{0} masalah - uninstall dan install ulang SEB" -f $regStrong.Count)
  $regStrong | ForEach-Object { $masalah += $_ }
} elseif($sebInstalledAny){ Row "OK" "Integritas instalasi SEB" "tidak ada file rusak terdeteksi" }
$regWarn | ForEach-Object { $peringatan += $_ }

# Konfigurasi SEB lama
switch($cfgStatus){
  "CLEANED" { Row "OK"   "Konfigurasi SEB lama" $cfgText }
  "NONE"    { Row "OK"   "Konfigurasi SEB lama" $cfgText }
  default   { Row "WARN" "Konfigurasi SEB lama" $cfgText }
}

# Mode daya Wi-Fi
switch($pwrStatus){
  "OK"      { Row "OK"   "Wi-Fi & mode daya" $pwrText }
  "PARTIAL" { Row "WARN" "Wi-Fi & mode daya" $pwrText; $peringatan += "Sebagian pengaturan mode performa gagal. Atur manual: Power Options > Wireless Adapter Settings." }
  default   { Row "WARN" "Wi-Fi & mode daya" $pwrText }
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

# Akses HTTPS
if($wel.OK){ Row "OK" "Akses ke e-learning" ("AMAN - dapat diakses (HTTP {0}, {1} ms)" -f $wel.Code,$wel.Ms) } else { Row "BAD" "Akses ke e-learning" "GAGAL DIAKSES"; $masalah += "E-learning ($ELEARN_HOST) tidak dapat diakses." }

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

# Jitter
if($jt.OK){
  $st = if($jt.Jitter -le 30){"OK"}else{"WARN"}
  Row $st "Jitter (kestabilan)" ("{0} ms (lonjakan maks {1} ms, loss {2}/{3}) -> {4}" -f $jt.Jitter,$jt.Max,$jt.Lost,$jt.Sent,(Rate-Jitter $jt.Jitter))
  if($jt.Jitter -gt 30){ $peringatan += "Jitter tinggi ($($jt.Jitter) ms). Koneksi tidak stabil, dekati router atau gunakan jaringan lain." }
} else { Row "WARN" "Jitter (kestabilan)" "tidak dapat diukur" }
# Bufferbloat
foreach($b in @(@{N="download";R=$bbDown},@{N="upload";R=$bbUp})){
  $lbl = "Bufferbloat $($b.N)"
  if($b.R -and $b.R.OK){
    $inc = [math]::Max(0,($b.R.Avg - $jt.Avg))
    $st = if($inc -le 100){"OK"}else{"WARN"}
    Row $st $lbl ("ping naik {0} ms -> {1} ms (+{2} ms) saat {3} penuh -> {4}" -f $jt.Avg,$b.R.Avg,$inc,$b.N,(Rate-BB $inc))
    if($inc -gt 100){ $peringatan += "Bufferbloat saat $($b.N) (+$inc ms). Hentikan unduhan/streaming/perangkat lain selama ujian." }
  } else { Row "WARN" $lbl "tidak dapat diukur" }
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
H "13. CATATAN"
Write-Host "Gunakan SSID Wi-Fi resmi untuk ujian." -ForegroundColor White
Write-Host "Settings > Network & Internet > Wi-Fi > Manage known networks." -ForegroundColor White
Write-Host "Pada Wi-Fi lain yang tersimpan, matikan opsi Connect automatically." -ForegroundColor White
Write-Host "Pastikan komputer hanya terhubung ke Wi-Fi ujian yang ditentukan." -ForegroundColor White
Write-Host ""
Write-Host "PENTING:" -ForegroundColor Yellow
Write-Host "Hasil script ini bukan sertifikasi keamanan atau alat untuk menyadap;" -ForegroundColor Yellow
Write-Host "alat ini hanya untuk pengecekan jaringan." -ForegroundColor Yellow
Write-Host "Lakukan uji buka SEB sebelum sesi ujian dimulai." -ForegroundColor Yellow

if($needRestart){
  $rs = Read-Host "`nRestart komputer sekarang agar pengaturan virtualisasi berlaku? (Y/N)"
  if($rs -match '^[Yy]'){ shutdown /r /t 15 /c "OPTIMIZER SEB: restart untuk menerapkan perubahan"; Write-Host "Komputer akan restart dalam 15 detik. Simpan pekerjaan Anda." -ForegroundColor Yellow }
}
Write-Host "`nHasil tidak disimpan ke file. Scroll ke atas untuk melihat seluruh hasil." -ForegroundColor Cyan
Read-Host "`nTekan ENTER untuk keluar"
