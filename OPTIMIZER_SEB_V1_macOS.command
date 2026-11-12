#!/bin/bash
# OPTIMIZER SEB V1 - versi macOS
# Cara pakai: bash OPTIMIZER_SEB_V1_macOS.command   (atau klik dua kali setelah chmod +x)

if [ -z "$BASH_VERSION" ]; then exec /bin/bash "$0" "$@"; fi
export LC_ALL=C LANG=C

# ===================== PENGATURAN (boleh diubah) =====================
SEB_HOST="safeexambrowser.org"
SEB_URL="https://safeexambrowser.org/"
SEB_DOWNLOAD="https://safeexambrowser.org/download_en.html"
SEB_API="https://api.github.com/repos/SafeExamBrowser/seb-mac/releases/latest"
ELEARN_HOST="elearning.poltekkes-smg.ac.id"
ELEARN_URL="https://elearning.poltekkes-smg.ac.id/"
MIN_MBPS=2
PING_COUNT=5
# =====================================================================

clear
C_R=$'\033[31m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_C=$'\033[36m'; C_W=$'\033[97m'; C_D=$'\033[90m'; C_0=$'\033[0m'
cat <<'BANNER'

    ######    ########    ##########  ##########  ##      ##  ##########  ##########  ##########  ########
  ##      ##  ##      ##      ##          ##      ####  ####      ##            ##    ##          ##      ##
  ##      ##  ########        ##          ##      ##  ##  ##      ##          ##      ########    ########
  ##      ##  ##              ##          ##      ##      ##      ##        ##        ##          ##    ##
    ######    ##              ##      ##########  ##      ##  ##########  ##########  ##########  ##      ##

  ##      ##      ##
  ##      ##    ####
  ##      ##      ##
    ##  ##        ##
      ##        ######

BANNER
echo "${C_C}  ==============================================================================================================${C_0}"
echo "  Pemeriksaan jaringan, versi SEB, dan kesiapan Mac untuk Safe Exam Browser"
echo "${C_C}  ==============================================================================================================${C_0}"
echo
echo "${C_D}  Script hanya melakukan pemeriksaan jaringan, versi SEB, dan aplikasi remote.${C_0}"
echo "${C_D}  Tidak mengambil/mengirim data pribadi dan tidak menghapus aplikasi.${C_0}"

MASALAH=(); PERINGATAN=()
H(){ echo; echo "${C_C}================================================================${C_0}"; echo "${C_C} $1${C_0}"; echo "${C_C}================================================================${C_0}"; }
Row(){ # status label text
  local tag col
  case "$1" in OK) tag="[ OK ]"; col=$C_G;; WARN) tag="[ !  ]"; col=$C_Y;; *) tag="[ XX ]"; col=$C_R;; esac
  printf "%s%s %-28s: %s%s\n" "$col" "$tag" "$2" "$3" "$C_0"
}
# versi a >= b ?
ver_ge(){ awk -v a="$1" -v b="$2" 'BEGIN{na=split(a,x,".");nb=split(b,y,".");n=(na>nb)?na:nb;for(i=1;i<=n;i++){xi=x[i]+0;yi=y[i]+0;if(xi>yi){exit 0}if(xi<yi){exit 1}}exit 0}'; }
rate(){ if [ "$1" -le 100 ]; then echo "BAIK"; elif [ "$1" -le 200 ]; then echo "CUKUP"; else echo "TINGGI / LAMBAT"; fi; }

rate_jitter(){ awk -v j="$1" 'BEGIN{ if(j<=10) print "BAIK"; else if(j<=30) print "CUKUP"; else print "TINGGI (koneksi tidak stabil)" }'; }
rate_bb(){ if [ "$1" -le 30 ]; then echo "BAIK (tidak ada bufferbloat berarti)"; elif [ "$1" -le 100 ]; then echo "RINGAN"; elif [ "$1" -le 200 ]; then echo "SEDANG (rawan lag saat unduh/unggah)"; else echo "BERAT (rawan lag/putus saat ujian)"; fi; }
bb_run(){ # down|up -> BB_OK BB_AVG BB_MAX BB_LOST BB_SENT
  local pids="" tmp="" i out times n
  BB_OK=0; BB_AVG=0; BB_MAX=0; BB_LOST=0; BB_SENT=$BCOUNT
  if [ "$1" = "down" ]; then
    for i in 1 2 3; do curl -s -o /dev/null -m 8 "https://speed.cloudflare.com/__down?bytes=100000000" >/dev/null 2>&1 & pids="$pids $!"; done
  else
    tmp=$(mktemp /tmp/optseb_bb.XXXXXX); head -c 20000000 /dev/urandom > "$tmp"
    for i in 1 2 3; do curl -s -o /dev/null -m 8 -X POST --data-binary @"$tmp" "https://speed.cloudflare.com/__up" >/dev/null 2>&1 & pids="$pids $!"; done
  fi
  sleep 1
  out=$(ping -c "$BCOUNT" $PI -W 1000 8.8.8.8 2>&1)
  { kill $pids; wait $pids; } 2>/dev/null
  [ -n "$tmp" ] && rm -f "$tmp"
  times=$(echo "$out" | sed -n 's/.*time=\([0-9.]*\) ms.*/\1/p'); n=$(echo "$times" | grep -c .)
  BB_LOST=$((BCOUNT-n))
  if [ "$n" -ge 1 ]; then
    read BB_AVG BB_MAX <<EOF_B
$(echo "$times" | awk '{sum+=$1; if($1>m)m=$1} END{printf "%.0f %.0f", sum/NR, m}')
EOF_B
    BB_OK=1
  fi
}

# interval ping cepat (jika diizinkan macOS)
PI=""; JCOUNT=8; BCOUNT=6
if ping -c 1 -i 0.25 127.0.0.1 >/dev/null 2>&1; then PI="-i 0.25"; JCOUNT=12; BCOUNT=16; fi

# hasil ping: PG_OK PG_MIN PG_AVG PG_MAX PG_LOSS PG_RESOLVED
do_ping(){
  local out
  PG_OK=0; PG_MIN=0; PG_AVG=0; PG_MAX=0; PG_LOSS=100; PG_RES=1
  out=$(ping -c "$PING_COUNT" -W 2000 -q "$1" 2>&1)
  if echo "$out" | grep -qi "cannot resolve\|unknown host"; then PG_RES=0; return; fi
  PG_LOSS=$(echo "$out" | sed -n 's/.* \([0-9.]*\)% packet loss.*/\1/p' | cut -d. -f1)
  [ -z "$PG_LOSS" ] && PG_LOSS=100
  local stats; stats=$(echo "$out" | sed -n 's/.*= \([0-9.]*\)\/\([0-9.]*\)\/\([0-9.]*\)\/.*/\1 \2 \3/p')
  if [ -n "$stats" ]; then
    set -- $stats
    PG_MIN=$(awk -v v="$1" 'BEGIN{printf "%.0f", v}'); PG_AVG=$(awk -v v="$2" 'BEGIN{printf "%.0f", v}'); PG_MAX=$(awk -v v="$3" 'BEGIN{printf "%.0f", v}'); PG_OK=1
  fi
}
show_ping(){ # nama target
  if [ $PG_OK -eq 1 ]; then echo "  $1 ($2): loss ${PG_LOSS}% | min ${PG_MIN} ms, maks ${PG_MAX} ms, rata-rata ${PG_AVG} ms"
  elif [ $PG_RES -eq 0 ]; then echo "  ${C_R}$1 ($2): nama tidak dapat di-resolve (DNS bermasalah)${C_0}"
  else echo "  ${C_Y}$1 ($2): tidak ada balasan ping (mungkin diblokir server)${C_0}"; fi
}
web_test(){ # url -> W_CODE W_MS W_OK
  local r; r=$(curl -s -o /dev/null -m 15 -L -A "Optimizer-SEB-V1" -w "%{http_code} %{time_total}" "$1" 2>/dev/null)
  W_CODE=${r%% *}; W_MS=$(awk -v t="${r##* }" 'BEGIN{printf "%.0f", t*1000}')
  W_OK=0; if [ "$W_CODE" != "000" ] && [ "$W_CODE" -lt 500 ] 2>/dev/null; then W_OK=1; fi
}

# ---------------------------------------------------------------
H "1. FLUSH DNS DAN IP RENEW"
IFACE=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
IP_BEFORE=""; [ -n "$IFACE" ] && IP_BEFORE=$(ipconfig getifaddr "$IFACE" 2>/dev/null)
DNS_OK=-1; RENEW_OK=-1
echo "Langkah ini membutuhkan password Mac (sudo). Ketik password lalu ENTER (tidak tampil di layar)."
if sudo -v; then
  sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder && DNS_OK=1 || DNS_OK=0
  if [ $DNS_OK -eq 1 ]; then echo "${C_G}DNS: SUDAH DI-FLUSH${C_0}"; else echo "${C_R}DNS: GAGAL${C_0}"; fi
  if [ -n "$IFACE" ]; then
    echo "${C_Y}Melakukan DHCP renew pada $IFACE. Koneksi dapat terputus sementara...${C_0}"
    sudo ipconfig set "$IFACE" DHCP >/dev/null 2>&1 && RENEW_OK=1 || RENEW_OK=0
    echo "${C_Y}Menunggu koneksi pulih...${C_0}"
    for i in $(seq 1 15); do sleep 2; ping -c 1 -W 1000 8.8.8.8 >/dev/null 2>&1 && break; done
    IFACE2=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}'); [ -n "$IFACE2" ] && IFACE=$IFACE2
  else
    echo "${C_Y}Interface jaringan aktif tidak ditemukan.${C_0}"; RENEW_OK=0
  fi
else
  echo "${C_Y}Tanpa sudo: Flush DNS dan IP renew DILEWATI.${C_0}"
fi
IP_NOW=""; [ -n "$IFACE" ] && IP_NOW=$(ipconfig getifaddr "$IFACE" 2>/dev/null)
GW=$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')
echo; echo "IP aktif saat ini:"
if [ -n "$IP_NOW" ]; then
  echo "  ${C_W}$IFACE : $IP_NOW | Gateway: ${GW:-?}${C_0}"
  if [ $RENEW_OK -eq 1 ]; then
    if [ "$IP_NOW" = "$IP_BEFORE" ]; then echo "${C_D}  (IP sama seperti sebelumnya - normal jika DHCP memberi alamat yang sama)${C_0}"
    else echo "${C_D}  (IP sebelumnya: ${IP_BEFORE:-tidak diketahui})${C_0}"; fi
  fi
else echo "  ${C_R}tidak ada IP aktif${C_0}"; fi

# ---------------------------------------------------------------
H "2. DETEKSI APLIKASI REMOTE ACCESS (TIDAK BOLEH DIGUNAKAN)"
PAT="TeamViewer|AnyDesk|RustDesk|UltraViewer|Supremo|Chrome Remote Desktop|Remote Utilities|VNC|Radmin|AeroAdmin|DWService|Splashtop|LogMeIn|GoTo Resolve|ScreenConnect|ConnectWise|Zoho Assist|Parsec|Jump Desktop|Screens|Apple Remote Desktop|NoMachine"
FOUND=()
APPLIST=$(ls /Applications "$HOME/Applications" 2>/dev/null | grep -iE "$PAT" | grep -i "\.app$" | sort -u)
while IFS= read -r app; do [ -n "$app" ] && FOUND+=("Aplikasi terpasang: $app"); done <<EOF_APPS
$APPLIST
EOF_APPS
RUNPAT="TeamViewer|AnyDesk|RustDesk|UltraViewer|Supremo|vnc|Radmin|Splashtop|ScreenConnect|ConnectWise|remoting_host|NoMachine|Parsec|ARDAgent|screensharingd"
PROCLIST=$(ps -axco comm 2>/dev/null | grep -iE "$RUNPAT" | sort -u)
while IFS= read -r p; do [ -n "$p" ] && FOUND+=("Proses aktif: $p"); done <<EOF_PROCS
$PROCLIST
EOF_PROCS
if [ ${#FOUND[@]} -eq 0 ]; then
  echo "${C_G}TIDAK DITEMUKAN aplikasi remote yang dikenal.${C_0}"
else
  echo "${C_R}PERINGATAN! DITEMUKAN aplikasi/proses yang tidak boleh digunakan saat ujian:${C_0}"
  for f in "${FOUND[@]}"; do echo "${C_R}  [PERIKSA] $f${C_0}"; done
  echo "${C_R}Tutup/hapus secara manual jika tidak diperlukan, lalu jalankan pemeriksaan ulang.${C_0}"
  echo "${C_D}Catatan: Screen Sharing/ARD bawaan macOS juga harus dimatikan (System Settings > General > Sharing).${C_0}"
fi
echo "${C_D}Catatan: deteksi berdasarkan nama aplikasi/proses, bukan jaminan 100%.${C_0}"

# ---------------------------------------------------------------
H "3. VERSI SAFE EXAM BROWSER (SEB) macOS"
SEB_APP=""
for p in "/Applications/Safe Exam Browser.app" "/Applications/SafeExamBrowser.app" "$HOME/Applications/Safe Exam Browser.app"; do [ -d "$p" ] && SEB_APP="$p" && break; done
if [ -z "$SEB_APP" ]; then SEB_APP=$(mdfind "kMDItemCFBundleIdentifier == 'org.safeexambrowser.SafeExamBrowser'" 2>/dev/null | head -1); fi
SEB_CUR=""
if [ -n "$SEB_APP" ]; then
  SEB_CUR=$(defaults read "$SEB_APP/Contents/Info" CFBundleShortVersionString 2>/dev/null)
  echo "${C_W}SEB terpasang : $SEB_APP (versi ${SEB_CUR:-?})${C_0}"
else
  echo "${C_Y}SEB belum terdeteksi terpasang di Mac ini.${C_0}"
fi
SEB_LATEST=$(curl -s -m 15 -H "User-Agent: Optimizer-SEB-V1" "$SEB_API" 2>/dev/null | sed -n 's/.*"tag_name"[ ]*:[ ]*"\([^"]*\)".*/\1/p' | head -1 | sed 's/^[vV]//')
if [ -n "$SEB_LATEST" ]; then echo "${C_W}SEB terbaru   : $SEB_LATEST${C_0}"
else echo "${C_Y}SEB terbaru   : tidak dapat dicek (internet/GitHub tidak dapat diakses)${C_0}"; fi
SEB_STATUS="UNKNOWN"; SEB_TEXT=""
SEB_CUR3=$(echo "$SEB_CUR" | grep -oE '^[0-9]+(\.[0-9]+){0,2}'); SEB_LAT3=$(echo "$SEB_LATEST" | grep -oE '^[0-9]+(\.[0-9]+){0,2}')
if [ -z "$SEB_APP" ]; then
  SEB_STATUS="NOTFOUND"; SEB_TEXT="SEB tidak terdeteksi - install dari $SEB_DOWNLOAD"
  PERINGATAN+=("SEB belum terdeteksi. Unduh dan install dari $SEB_DOWNLOAD (atau sesuai arahan panitia).")
elif [ -z "$SEB_LAT3" ] || [ -z "$SEB_CUR3" ]; then
  SEB_STATUS="UNKNOWN"; SEB_TEXT="versi ${SEB_CUR:-?} (pengecekan versi terbaru gagal, cek manual di safeexambrowser.org)"
  PERINGATAN+=("Versi terbaru SEB tidak dapat dicek. Silakan cek manual: $SEB_DOWNLOAD")
elif ver_ge "$SEB_CUR3" "$SEB_LAT3"; then
  SEB_STATUS="OK"; SEB_TEXT="versi $SEB_CUR - SUDAH TERBARU"
  echo "${C_G}Versi SEB sudah yang terbaru.${C_0}"
else
  SEB_STATUS="OLD"; SEB_TEXT="versi $SEB_CUR BELUM TERBARU (terbaru: $SEB_LATEST)"
  echo "${C_R}VERSI SEB BELUM TERBARU. Silakan CHECK UPDATE / unduh versi terbaru di:${C_0}"
  echo "${C_R}  $SEB_DOWNLOAD${C_0}"
  echo "${C_Y}  (Jika panitia ujian mewajibkan versi tertentu, ikuti ketentuan panitia.)${C_0}"
  PERINGATAN+=("SEB belum versi terbaru (terpasang $SEB_CUR, terbaru $SEB_LATEST). Mohon check update: $SEB_DOWNLOAD")
  printf "\nBuka halaman unduh SEB sekarang? (Y/N): "; read -r ans < /dev/tty
  case "$ans" in [Yy]*) open "$SEB_DOWNLOAD";; esac
fi

SEB_SIG="NA"
if [ -n "$SEB_APP" ]; then
  if codesign --verify --deep --strict "$SEB_APP" >/dev/null 2>&1; then SEB_SIG="OK"; echo "${C_G}Keutuhan aplikasi SEB: tanda tangan valid.${C_0}"
  else SEB_SIG="BAD"; echo "${C_R}Keutuhan aplikasi SEB: tanda tangan TIDAK valid (aplikasi rusak/dimodifikasi).${C_0}"
    MASALAH+=("Aplikasi SEB rusak/dimodifikasi (verifikasi tanda tangan gagal). Hapus SEB dari Applications lalu install ulang dari $SEB_DOWNLOAD.")
  fi
fi

# ---------------------------------------------------------------
H "4. DETEKSI VIRTUAL MACHINE / HYPERVISOR"
echo "${C_W}Memeriksa penyebab umum SEB menganggap Mac sebagai virtual machine...${C_0}"
VM_STRONG=(); VM_WEAK=()
HW_MODEL=$(sysctl -n hw.model 2>/dev/null); CPU_BRAND=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
HV_PRESENT=$(sysctl -n kern.hv_vmm_present 2>/dev/null)
echo "${C_W}  Model : ${HW_MODEL:-?}${C_0}"
echo "${C_W}  CPU   : ${CPU_BRAND:-?}${C_0}"
[ "$HV_PRESENT" = "1" ] && VM_STRONG+=("macOS melaporkan berjalan di dalam virtual machine (kern.hv_vmm_present=1)")
echo "$HW_MODEL" | grep -qiE "vmware|parallels|virtual|qemu|vbox" && VM_STRONG+=("Model perangkat terbaca seperti mesin virtual: $HW_MODEL")
VMPROC=$(ps -axco comm 2>/dev/null | grep -iE "^(prl_vm_app|vmware-vmx|VBoxHeadless|VirtualBoxVM|qemu-system.*|com.apple.Virtualization.VirtualMachine|UTM)$" | sort -u)
while IFS= read -r p; do [ -n "$p" ] && VM_STRONG+=("Mesin virtual sedang berjalan: proses $p"); done <<EOF_VP
$VMPROC
EOF_VP
VMAPPS=$(ls /Applications "$HOME/Applications" 2>/dev/null | grep -iE "Parallels|VMware|VirtualBox|UTM|QEMU|Docker|Genymotion|BlueStacks" | grep -i "\.app$" | sort -u)
while IFS= read -r a; do [ -n "$a" ] && VM_WEAK+=("Aplikasi virtualisasi terpasang: $a"); done <<EOF_VA
$VMAPPS
EOF_VA
if [ ${#VM_STRONG[@]} -eq 0 ] && [ ${#VM_WEAK[@]} -eq 0 ]; then
  echo "${C_G}Tidak ada indikator virtual machine yang dikenal.${C_0}"
else
  if [ ${#VM_STRONG[@]} -gt 0 ]; then echo; echo "${C_R}INDIKATOR KUAT (SEB berpotensi menolak start):${C_0}"; for v in "${VM_STRONG[@]}"; do echo "${C_R}  [!!] $v${C_0}"; done; fi
  if [ ${#VM_WEAK[@]} -gt 0 ]; then echo; echo "${C_Y}INDIKATOR LEMAH:${C_0}"; for v in "${VM_WEAK[@]}"; do echo "${C_Y}  [!] $v${C_0}"; done; fi
  echo; echo "${C_C}Langkah perbaikan manual (script TIDAK mengubah pengaturan apa pun):${C_0}"
  echo "  1. Update SEB ke versi terbaru."
  echo "  2. Tutup semua mesin virtual/emulator (Parallels, VMware, VirtualBox, UTM, Docker)."
  echo "  3. Pastikan SEB dijalankan langsung di macOS, bukan di dalam mesin virtual."
fi
echo "${C_D}Catatan: pemeriksaan ini perkiraan; jika SEB tetap menolak, kirim model Mac di atas ke panitia.${C_0}"

# ---------------------------------------------------------------
H "5. BERSIHKAN KONFIGURASI SEB LAMA"
CFG_STATUS="NONE"; CFG_TEXT="tidak ada konfigurasi lama"; CFG_BK=""
CFG_ITEMS=()
for d in "$HOME/Library/Preferences" "$HOME/Library/Application Support" "$HOME/Library/Caches" "$HOME/Library/Saved Application State"; do
  [ -d "$d" ] || continue
  CFG_LIST=$(find "$d" -maxdepth 1 \( -iname '*safeexambrowser*' -o -iname '*safe exam browser*' \) 2>/dev/null)
  while IFS= read -r f; do [ -n "$f" ] && CFG_ITEMS+=("$f"); done <<EOF_CFG
$CFG_LIST
EOF_CFG
done
if [ ${#CFG_ITEMS[@]} -eq 0 ]; then
  echo "${C_G}Tidak ditemukan konfigurasi SEB lama.${C_0}"
else
  echo "${C_W}Ditemukan konfigurasi/data SEB lama:${C_0}"
  for f in "${CFG_ITEMS[@]}"; do echo "${C_W}  - $f${C_0}"; done
  if pgrep -ix "Safe Exam Browser" >/dev/null 2>&1 || pgrep -ix "SafeExamBrowser" >/dev/null 2>&1; then
    CFG_STATUS="RUNNING"; CFG_TEXT="DILEWATI - SEB sedang berjalan"
    echo "${C_R}SEB sedang berjalan. Tutup SEB sepenuhnya lalu jalankan ulang script ini.${C_0}"
    PERINGATAN+=("SEB sedang berjalan sehingga konfigurasi lama tidak dibersihkan. Tutup SEB lalu jalankan ulang.")
  else
    echo "${C_Y}Item di atas akan DIPINDAHKAN ke folder backup di home (bukan dihapus permanen).${C_0}"
    echo "${C_Y}Aplikasi SEB tidak dihapus. Jika ujian memakai file konfigurasi dari kampus,${C_0}"
    echo "${C_Y}kembalikan dari folder backup atau buka ulang file .seb/link ujian dari e-learning.${C_0}"
    printf "\nBersihkan konfigurasi SEB lama sekarang? (Y/N): "; read -r ans < /dev/tty
    case "$ans" in
      [Yy]*)
        CFG_BK="$HOME/SEB_Config_Backup_$(date +%Y%m%d_%H%M%S)"; mkdir -p "$CFG_BK"
        moved=0; fail=0
        for f in "${CFG_ITEMS[@]}"; do
          dest="$CFG_BK/$(basename "$(dirname "$f")")__$(basename "$f")"
          if mv "$f" "$dest" 2>/dev/null; then moved=$((moved+1)); else fail=$((fail+1)); echo "${C_R}  GAGAL memindahkan: $f${C_0}"; fi
        done
        killall cfprefsd >/dev/null 2>&1
        if [ $fail -eq 0 ]; then
          CFG_STATUS="CLEANED"; CFG_TEXT="DIBERSIHKAN ($moved item dipindah ke $CFG_BK)"
          echo "${C_G}Konfigurasi SEB lama sudah dibersihkan.${C_0}"
          echo "${C_D}Backup: $CFG_BK (boleh dihapus setelah SEB berjalan normal).${C_0}"
        else
          CFG_STATUS="PARTIAL"; CFG_TEXT="SEBAGIAN GAGAL ($fail item). Tutup SEB lalu coba lagi."
          PERINGATAN+=("Sebagian konfigurasi SEB lama gagal dibersihkan. Pastikan SEB tertutup lalu coba lagi.")
        fi;;
      *) CFG_STATUS="SKIP"; CFG_TEXT="dilewati oleh pengguna";;
    esac
  fi
fi

# ---------------------------------------------------------------
H "6. MODE DAYA (PERFORMA)"
PWR_STATUS="SKIP"; PWR_TEXT="dilewati"
LPM=$(pmset -g 2>/dev/null | awk '/lowpowermode/{print $2}')
if [ -z "$LPM" ]; then
  PWR_STATUS="NA"; PWR_TEXT="Mode Daya Rendah tidak tersedia di Mac ini"
  echo "${C_D}Mode Daya Rendah tidak tersedia di Mac ini.${C_0}"
elif [ "$LPM" = "0" ]; then
  PWR_STATUS="OK"; PWR_TEXT="Mode Daya Rendah sudah MATI"
  echo "${C_G}Mode Daya Rendah sudah mati.${C_0}"
else
  echo "${C_Y}Mode Daya Rendah sedang AKTIF (dapat memperlambat Wi-Fi dan performa).${C_0}"
  printf "Matikan Mode Daya Rendah sekarang? (Y/N): "; read -r ansP < /dev/tty
  case "$ansP" in
    [Yy]*)
      if sudo pmset -a lowpowermode 0; then PWR_STATUS="OK"; PWR_TEXT="Mode Daya Rendah DIMATIKAN"; echo "${C_G}Mode Daya Rendah dimatikan.${C_0}"
        echo "${C_D}Untuk mengaktifkan kembali: sudo pmset -a lowpowermode 1${C_0}"
      else PWR_STATUS="FAIL"; PWR_TEXT="gagal mematikan Mode Daya Rendah"; fi;;
    *) PWR_STATUS="SKIP"; PWR_TEXT="dilewati oleh pengguna";;
  esac
fi
echo "${C_D}Catatan: macOS tidak menyediakan pengaturan hemat daya Wi-Fi terpisah; sebaiknya colok charger saat ujian.${C_0}"

# ---------------------------------------------------------------
H "7. PING KE INTERNET DAN E-LEARNING"
echo "${C_W}Ping DNS Google (8.8.8.8)...${C_0}"
do_ping 8.8.8.8; show_ping "DNS Google" 8.8.8.8
G_OK=$PG_OK; G_MIN=$PG_MIN; G_AVG=$PG_AVG; G_MAX=$PG_MAX; G_LOSS=$PG_LOSS
echo; echo "${C_W}Ping google.com (uji resolusi DNS)...${C_0}"
do_ping google.com; show_ping "Google.com" google.com
N_OK=$PG_OK; N_AVG=$PG_AVG; N_RES=$PG_RES
echo; echo "${C_W}Ping e-learning...${C_0}"
do_ping "$ELEARN_HOST"; show_ping "E-learning" "$ELEARN_HOST"
E_OK=$PG_OK; E_MIN=$PG_MIN; E_AVG=$PG_AVG; E_MAX=$PG_MAX; E_LOSS=$PG_LOSS; E_RES=$PG_RES

# ---------------------------------------------------------------
H "8. UJI AKSES E-LEARNING (HTTPS)"
echo "${C_W}Mengakses $ELEARN_URL ...${C_0}"; web_test "$ELEARN_URL"; WE_OK=$W_OK; WE_CODE=$W_CODE; WE_MS=$W_MS
if [ $WE_OK -eq 1 ]; then echo "${C_G}  E-learning: DAPAT DIAKSES (HTTP $WE_CODE, $WE_MS ms)${C_0}"; else echo "${C_R}  E-learning: GAGAL DIAKSES${C_0}"; fi

# ---------------------------------------------------------------
H "9. SPEED TEST"
DOWN=""; UP=""
echo "${C_W}Mengukur download (maks. 12 detik)...${C_0}"
d=$(curl -s -o /dev/null -m 12 -w "%{speed_download}" "https://speed.cloudflare.com/__down?bytes=20000000" 2>/dev/null)
if [ -n "$d" ] && awk -v v="$d" 'BEGIN{exit !(v>0)}'; then DOWN=$(awk -v v="$d" 'BEGIN{printf "%.2f", v*8/1000000}'); echo "${C_G}  DOWNLOAD: $DOWN Mbps${C_0}"; fi
echo "${C_W}Mengukur upload (3 MB)...${C_0}"
TMPF=$(mktemp /tmp/optseb.XXXXXX); head -c 3000000 /dev/urandom > "$TMPF"
u=$(curl -s -o /dev/null -m 60 -X POST --data-binary @"$TMPF" -w "%{speed_upload}" "https://speed.cloudflare.com/__up" 2>/dev/null)
rm -f "$TMPF"
if [ -n "$u" ] && awk -v v="$u" 'BEGIN{exit !(v>0)}'; then UP=$(awk -v v="$u" 'BEGIN{printf "%.2f", v*8/1000000}'); echo "${C_G}  UPLOAD  : $UP Mbps${C_0}"; fi
[ -z "$DOWN" ] && echo "${C_Y}Speed test gagal: endpoint tidak tersedia.${C_0}"

# ---------------------------------------------------------------
H "10. JITTER DAN BUFFERBLOAT"
JT_OK=0; JT_J=0; JT_AVG=0; JT_MAX=0; JT_LOSS=$JCOUNT
echo "${C_W}Mengukur jitter ke 8.8.8.8 ($JCOUNT ping)...${C_0}"
jout=$(ping -c "$JCOUNT" $PI -W 1000 8.8.8.8 2>&1)
jtimes=$(echo "$jout" | sed -n 's/.*time=\([0-9.]*\) ms.*/\1/p')
jn=$(echo "$jtimes" | grep -c .)
if [ "$jn" -ge 2 ]; then
  read JT_J JT_AVG JT_MAX <<EOF_J
$(echo "$jtimes" | awk 'NR>1{d=$1-p; if(d<0)d=-d; s+=d; n++} {sum+=$1; if($1>m)m=$1; p=$1} END{printf "%.1f %.0f %.0f", s/n, sum/NR, m}')
EOF_J
  JT_LOSS=$((JCOUNT-jn)); JT_OK=1
  echo "  Jitter $JT_J ms | rata-rata $JT_AVG ms | lonjakan maks $JT_MAX ms | loss $JT_LOSS/$JCOUNT"
else
  echo "${C_Y}  Jitter tidak dapat diukur (ping gagal).${C_0}"
fi
BBD_OK=0; BBU_OK=0
if [ -n "$DOWN" ] && [ $JT_OK -eq 1 ]; then
  echo; echo "${C_W}Uji bufferbloat saat DOWNLOAD penuh (sekitar 5 detik)...${C_0}"
  bb_run down; BBD_OK=$BB_OK; BBD_AVG=$BB_AVG; BBD_MAX=$BB_MAX; BBD_LOST=$BB_LOST
  if [ $BBD_OK -eq 1 ]; then echo "  Ping saat download: rata-rata $BBD_AVG ms | maks $BBD_MAX ms | loss $BBD_LOST/$BCOUNT"; else echo "${C_Y}  Tidak dapat diukur.${C_0}"; fi
  echo; echo "${C_W}Uji bufferbloat saat UPLOAD penuh (sekitar 5 detik)...${C_0}"
  bb_run up; BBU_OK=$BB_OK; BBU_AVG=$BB_AVG; BBU_MAX=$BB_MAX; BBU_LOST=$BB_LOST
  if [ $BBU_OK -eq 1 ]; then echo "  Ping saat upload  : rata-rata $BBU_AVG ms | maks $BBU_MAX ms | loss $BBU_LOST/$BCOUNT"; else echo "${C_Y}  Tidak dapat diukur.${C_0}"; fi
else
  echo "${C_Y}Uji bufferbloat dilewati (speed test/ping belum berhasil).${C_0}"
fi

# ---------------------------------------------------------------
H "11. KESIMPULAN HASIL PEMERIKSAAN"
if [ ${#FOUND[@]} -eq 0 ]; then Row OK "Aplikasi terlarang" "TIDAK DITEMUKAN"
else
  Row BAD "Aplikasi terlarang" "DITEMUKAN ${#FOUND[@]} item - harus ditutup/dihapus!"
  for f in "${FOUND[@]}"; do echo "${C_R}         -> $f${C_0}"; done
  MASALAH+=("Ditemukan aplikasi/proses yang tidak boleh digunakan. Tutup atau hapus lalu cek ulang.")
fi
if [ $DNS_OK -eq -1 ]; then Row WARN "Flush DNS / IP renew" "DILEWATI (tanpa sudo)"; PERINGATAN+=("Flush DNS dan IP renew dilewati. Jalankan ulang dan masukkan password Mac.")
else
  if [ $DNS_OK -eq 1 ]; then Row OK "Flush DNS" "BERHASIL"; else Row BAD "Flush DNS" "GAGAL"; MASALAH+=("Flush DNS gagal."); fi
  if [ $RENEW_OK -eq 1 ] && [ -n "$IP_NOW" ]; then Row OK "IP terbaru" "SUDAH DIPERBARUI ($IP_NOW)"
  else Row BAD "IP terbaru" "GAGAL / tidak mendapat IP"; MASALAH+=("IP renew gagal atau tidak ada IP aktif. Periksa koneksi Wi-Fi."); fi
fi
case "$SEB_STATUS" in
  OK) Row OK "Versi SEB" "$SEB_TEXT";;
  OLD) Row WARN "Versi SEB" "$SEB_TEXT"; echo "${C_Y}         -> Mohon CHECK UPDATE SEB terbaru: $SEB_DOWNLOAD${C_0}";;
  *) Row WARN "Versi SEB" "$SEB_TEXT";;
esac
if [ ${#VM_STRONG[@]} -gt 0 ]; then
  Row BAD "Deteksi Virtual Machine" "${#VM_STRONG[@]} indikator KUAT - SEB berpotensi menolak start"
  MASALAH+=("Terdeteksi indikator virtual machine yang kuat. SEB dapat menolak start. Lihat langkah di bagian 4.")
elif [ ${#VM_WEAK[@]} -gt 0 ]; then
  Row WARN "Deteksi Virtual Machine" "${#VM_WEAK[@]} indikator lemah (aplikasi virtualisasi terpasang)"
  PERINGATAN+=("Ada aplikasi virtualisasi terpasang. Pastikan tidak berjalan saat ujian.")
else Row OK "Deteksi Virtual Machine" "tidak ada indikator VM"; fi
case "$SEB_SIG" in
  OK) Row OK "Integritas aplikasi SEB" "tanda tangan valid";;
  BAD) Row BAD "Integritas aplikasi SEB" "RUSAK/dimodifikasi - install ulang SEB";;
esac
case "$PWR_STATUS" in
  OK) Row OK "Mode daya" "$PWR_TEXT";;
  NA) ;;
  *) Row WARN "Mode daya" "$PWR_TEXT"; PERINGATAN+=("Mode Daya Rendah mungkin aktif. Matikan di System Settings > Battery sebelum ujian.");;
esac
case "$CFG_STATUS" in
  CLEANED|NONE) Row OK "Konfigurasi SEB lama" "$CFG_TEXT";;
  *) Row WARN "Konfigurasi SEB lama" "$CFG_TEXT";;
esac
if [ $G_OK -eq 1 ]; then
  st=OK; { [ $G_AVG -gt 200 ] || [ $G_LOSS -ge 20 ]; } && st=WARN
  Row $st "Internet (DNS Google)" "rata-rata $G_AVG ms (min $G_MIN / maks $G_MAX ms), loss ${G_LOSS}% -> $(rate $G_AVG)"
  [ $G_AVG -gt 200 ] && PERINGATAN+=("Latensi ke Google tinggi ($G_AVG ms). Koneksi mungkin kurang stabil.")
  [ $G_LOSS -ge 20 ] && PERINGATAN+=("Terjadi packet loss ${G_LOSS}% saat ping Google. Koneksi kurang stabil.")
else
  Row BAD "Internet (DNS Google)" "TIDAK ADA BALASAN - internet bermasalah"
  MASALAH+=("Tidak ada koneksi internet (ping DNS Google 8.8.8.8 gagal).")
fi
if [ $N_OK -eq 1 ]; then Row OK "Resolusi DNS (google.com)" "BERHASIL, rata-rata $N_AVG ms"
elif [ $N_RES -eq 0 ]; then Row BAD "Resolusi DNS (google.com)" "GAGAL - DNS bermasalah"; MASALAH+=("DNS tidak dapat me-resolve nama domain. Coba ganti DNS ke 8.8.8.8 atau sambungkan ulang Wi-Fi.")
else Row WARN "Resolusi DNS (google.com)" "nama ter-resolve, tetapi ping tidak dibalas"; fi
if [ $E_OK -eq 1 ]; then
  st=OK; { [ $E_AVG -gt 200 ] || [ $E_LOSS -ge 20 ]; } && st=WARN
  Row $st "Ping e-learning" "rata-rata $E_AVG ms (min $E_MIN / maks $E_MAX ms), loss ${E_LOSS}% -> $(rate $E_AVG)"
  [ $E_AVG -gt 200 ] && PERINGATAN+=("Latensi ke e-learning tinggi ($E_AVG ms).")
  [ $E_LOSS -ge 20 ] && PERINGATAN+=("Packet loss ${E_LOSS}% ke e-learning. Koneksi kurang stabil.")
elif [ $E_RES -eq 0 ]; then Row BAD "Ping e-learning" "GAGAL - nama server tidak ter-resolve"; MASALAH+=("Alamat e-learning ($ELEARN_HOST) tidak ter-resolve. Periksa DNS/internet.")
else Row WARN "Ping e-learning" "tidak ada balasan ping (lihat uji akses HTTPS di bawah)"; PERINGATAN+=("Ping ke e-learning tidak dibalas. Pastikan akses HTTPS e-learning AMAN."); fi

if [ $WE_OK -eq 1 ]; then Row OK "Akses ke e-learning" "AMAN - dapat diakses (HTTP $WE_CODE, $WE_MS ms)"; else Row BAD "Akses ke e-learning" "GAGAL DIAKSES"; MASALAH+=("E-learning ($ELEARN_HOST) tidak dapat diakses."); fi
if [ -n "$DOWN" ]; then
  txt="Download $DOWN Mbps | Upload ${UP:-tidak terukur} Mbps"
  slow=$(awk -v d="$DOWN" -v u="${UP:-999}" -v m="$MIN_MBPS" 'BEGIN{print (d<m||u<m)?1:0}')
  if [ "$slow" = "1" ]; then Row WARN "Kecepatan internet" "$txt -> INTERNET LAMBAT (di bawah $MIN_MBPS Mbps)"; PERINGATAN+=("Internet LAMBAT (di bawah $MIN_MBPS Mbps). Pindah ke jaringan yang lebih cepat/dekati router.")
  else Row OK "Kecepatan internet" "$txt -> INTERNET NORMAL (di atas $MIN_MBPS Mbps)"; fi
else Row WARN "Kecepatan internet" "tidak dapat diukur (endpoint speed test tidak tersedia)"; PERINGATAN+=("Speed test gagal, kecepatan internet tidak dapat dipastikan."); fi

if [ $JT_OK -eq 1 ]; then
  st=OK; awk -v j="$JT_J" 'BEGIN{exit !(j>30)}' && st=WARN
  Row $st "Jitter (kestabilan)" "$JT_J ms (lonjakan maks $JT_MAX ms, loss $JT_LOSS/$JCOUNT) -> $(rate_jitter $JT_J)"
  [ $st = WARN ] && PERINGATAN+=("Jitter tinggi ($JT_J ms). Koneksi tidak stabil, dekati router atau gunakan jaringan lain.")
else Row WARN "Jitter (kestabilan)" "tidak dapat diukur"; fi
for mode in download upload; do
  if [ $mode = download ]; then ok=$BBD_OK; av=$BBD_AVG; else ok=$BBU_OK; av=$BBU_AVG; fi
  if [ "$ok" = "1" ]; then
    inc=$((av-JT_AVG)); [ $inc -lt 0 ] && inc=0
    st=OK; [ $inc -gt 100 ] && st=WARN
    Row $st "Bufferbloat $mode" "ping naik $JT_AVG ms -> $av ms (+$inc ms) saat $mode penuh -> $(rate_bb $inc)"
    [ $inc -gt 100 ] && PERINGATAN+=("Bufferbloat saat $mode (+$inc ms). Hentikan unduhan/streaming/perangkat lain selama ujian.")
  else Row WARN "Bufferbloat $mode" "tidak dapat diukur"; fi
done

echo; echo "${C_C}----------------------------------------------------------------${C_0}"
if [ ${#MASALAH[@]} -eq 0 ] && [ ${#PERINGATAN[@]} -eq 0 ]; then echo "${C_G} LOLOS PEMERIKSAAN: jaringan, akses SEB & e-learning AMAN. Mac siap lanjut uji buka SEB.${C_0}"
elif [ ${#MASALAH[@]} -eq 0 ]; then echo "${C_Y} LOLOS DENGAN CATATAN: ada hal yang perlu diperhatikan (lihat di bawah).${C_0}"
else echo "${C_R} BELUM LOLOS: perbaiki item merah di bawah lalu jalankan ulang.${C_0}"; fi
if [ ${#MASALAH[@]} -gt 0 ]; then echo; echo "${C_R} Yang harus diperbaiki:${C_0}"; for m in "${MASALAH[@]}"; do echo "${C_R}  - $m${C_0}"; done; fi
if [ ${#PERINGATAN[@]} -gt 0 ]; then echo; echo "${C_Y} Perlu diperhatikan:${C_0}"; for m in "${PERINGATAN[@]}"; do echo "${C_Y}  - $m${C_0}"; done; fi
echo "${C_C}----------------------------------------------------------------${C_0}"

H "12. CATATAN"
echo "Gunakan SSID Wi-Fi resmi untuk ujian."
echo "System Settings > Wi-Fi > Known Networks: hapus/nonaktifkan auto-join jaringan lain."
echo "Pastikan Mac hanya terhubung ke Wi-Fi ujian yang ditentukan."
echo
echo "${C_Y}PENTING:${C_0}"
echo "${C_Y}Hasil script ini bukan sertifikasi keamanan atau alat untuk menyadap;${C_0}"
echo "${C_Y}alat ini hanya untuk pengecekan jaringan.${C_0}"
echo "${C_Y}Lakukan uji buka SEB sebelum sesi ujian dimulai.${C_0}"
echo; echo "${C_C}Hasil tidak disimpan ke file. Scroll ke atas untuk melihat seluruh hasil.${C_0}"
echo; read -r -p "Tekan ENTER untuk keluar" < /dev/tty
