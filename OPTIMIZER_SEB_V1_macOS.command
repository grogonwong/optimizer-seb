#!/bin/bash
# OPTIMIZER SEB V1 - versi macOS
# Cara pakai: bash OPTIMIZER_SEB_V1_macOS.command   (atau klik dua kali setelah chmod +x)

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

printf '\033[8;45;120t' 2>/dev/null
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

# hasil ping: PG_OK PG_MIN PG_AVG PG_MAX PG_LOSS PG_RESOLVED
do_ping(){
  local out
  PG_OK=0; PG_MIN=0; PG_AVG=0; PG_MAX=0; PG_LOSS=100; PG_RES=1
  out=$(ping -c "$PING_COUNT" -i 0.3 -W 2000 -q "$1" 2>&1)
  if echo "$out" | grep -qi "cannot resolve\|unknown host"; then PG_RES=0; return; fi
  PG_LOSS=$(echo "$out" | sed -n 's/.* \([0-9.]*\)% packet loss.*/\1/p' | cut -d. -f1)
  [ -z "$PG_LOSS" ] && PG_LOSS=100
  local stats; stats=$(echo "$out" | sed -n 's/.*= \([0-9.]*\)\/\([0-9.]*\)\/\([0-9.]*\)\/.*/\1 \2 \3/p')
  if [ -n "$stats" ]; then
    set -- $stats
    PG_MIN=$(printf "%.0f" "$1"); PG_AVG=$(printf "%.0f" "$2"); PG_MAX=$(printf "%.0f" "$3"); PG_OK=1
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
if sudo -v 2>/dev/null; then
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
while IFS= read -r app; do [ -n "$app" ] && FOUND+=("Aplikasi terpasang: $app"); done < <(ls /Applications ~/Applications 2>/dev/null | grep -iE "$PAT" | grep -i "\.app$" | sort -u)
RUNPAT="TeamViewer|AnyDesk|RustDesk|UltraViewer|Supremo|vnc|Radmin|Splashtop|ScreenConnect|ConnectWise|remoting_host|NoMachine|Parsec|ARDAgent|screensharingd"
while IFS= read -r p; do [ -n "$p" ] && FOUND+=("Proses aktif: $p"); done < <(ps -axco comm 2>/dev/null | grep -iE "$RUNPAT" | sort -u)
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
  printf "\nBuka halaman unduh SEB sekarang? (Y/N): "; read -r ans
  case "$ans" in [Yy]*) open "$SEB_DOWNLOAD";; esac
fi

# ---------------------------------------------------------------
H "4. PING KE INTERNET, E-LEARNING, DAN SEB"
echo "${C_W}Ping DNS Google (8.8.8.8)...${C_0}"
do_ping 8.8.8.8; show_ping "DNS Google" 8.8.8.8
G_OK=$PG_OK; G_MIN=$PG_MIN; G_AVG=$PG_AVG; G_MAX=$PG_MAX; G_LOSS=$PG_LOSS
echo; echo "${C_W}Ping google.com (uji resolusi DNS)...${C_0}"
do_ping google.com; show_ping "Google.com" google.com
N_OK=$PG_OK; N_AVG=$PG_AVG; N_RES=$PG_RES
echo; echo "${C_W}Ping e-learning...${C_0}"
do_ping "$ELEARN_HOST"; show_ping "E-learning" "$ELEARN_HOST"
E_OK=$PG_OK; E_MIN=$PG_MIN; E_AVG=$PG_AVG; E_MAX=$PG_MAX; E_LOSS=$PG_LOSS; E_RES=$PG_RES
echo; echo "${C_W}Ping jaringan SEB (informasi saja, tidak mempengaruhi hasil)...${C_0}"
do_ping "$SEB_HOST"; show_ping "SEB" "$SEB_HOST"
S_OK=$PG_OK; S_AVG=$PG_AVG; S_LOSS=$PG_LOSS

# ---------------------------------------------------------------
H "5. UJI AKSES SEB DAN E-LEARNING (HTTPS)"
echo "${C_W}Mengakses $SEB_URL ...${C_0}"; web_test "$SEB_URL"; WS_OK=$W_OK; WS_CODE=$W_CODE; WS_MS=$W_MS
if [ $WS_OK -eq 1 ]; then echo "${C_G}  SEB: DAPAT DIAKSES (HTTP $WS_CODE, $WS_MS ms)${C_0}"; else echo "${C_R}  SEB: GAGAL DIAKSES${C_0}"; fi
echo "${C_W}Mengakses $ELEARN_URL ...${C_0}"; web_test "$ELEARN_URL"; WE_OK=$W_OK; WE_CODE=$W_CODE; WE_MS=$W_MS
if [ $WE_OK -eq 1 ]; then echo "${C_G}  E-learning: DAPAT DIAKSES (HTTP $WE_CODE, $WE_MS ms)${C_0}"; else echo "${C_R}  E-learning: GAGAL DIAKSES${C_0}"; fi

# ---------------------------------------------------------------
H "6. SPEED TEST"
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
H "7. KESIMPULAN HASIL PEMERIKSAAN"
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
if [ $S_OK -eq 1 ]; then Row OK "Ping jaringan SEB" "rata-rata $S_AVG ms, loss ${S_LOSS}%"; else Row OK "Ping jaringan SEB" "tidak merespon - TIDAK MASALAH (informasi saja)"; fi
if [ $WE_OK -eq 1 ]; then Row OK "Akses ke e-learning" "AMAN - dapat diakses (HTTP $WE_CODE, $WE_MS ms)"; else Row BAD "Akses ke e-learning" "GAGAL DIAKSES"; MASALAH+=("E-learning ($ELEARN_HOST) tidak dapat diakses."); fi
if [ $WS_OK -eq 1 ]; then Row OK "Akses ke situs SEB" "AMAN - dapat diakses (HTTP $WS_CODE)"; else Row WARN "Akses ke situs SEB" "tidak dapat diakses (hanya berpengaruh pada unduh/update SEB)"; PERINGATAN+=("Situs SEB ($SEB_HOST) tidak dapat diakses; unduh/update SEB mungkin terkendala."); fi
if [ -n "$DOWN" ]; then
  txt="Download $DOWN Mbps | Upload ${UP:-tidak terukur} Mbps"
  slow=$(awk -v d="$DOWN" -v u="${UP:-999}" -v m="$MIN_MBPS" 'BEGIN{print (d<m||u<m)?1:0}')
  if [ "$slow" = "1" ]; then Row WARN "Kecepatan internet" "$txt -> INTERNET LAMBAT (di bawah $MIN_MBPS Mbps)"; PERINGATAN+=("Internet LAMBAT (di bawah $MIN_MBPS Mbps). Pindah ke jaringan yang lebih cepat/dekati router.")
  else Row OK "Kecepatan internet" "$txt -> INTERNET NORMAL (di atas $MIN_MBPS Mbps)"; fi
else Row WARN "Kecepatan internet" "tidak dapat diukur (endpoint speed test tidak tersedia)"; PERINGATAN+=("Speed test gagal, kecepatan internet tidak dapat dipastikan."); fi

echo; echo "${C_C}----------------------------------------------------------------${C_0}"
if [ ${#MASALAH[@]} -eq 0 ] && [ ${#PERINGATAN[@]} -eq 0 ]; then echo "${C_G} LOLOS PEMERIKSAAN: jaringan, akses SEB & e-learning AMAN. Mac siap lanjut uji buka SEB.${C_0}"
elif [ ${#MASALAH[@]} -eq 0 ]; then echo "${C_Y} LOLOS DENGAN CATATAN: ada hal yang perlu diperhatikan (lihat di bawah).${C_0}"
else echo "${C_R} BELUM LOLOS: perbaiki item merah di bawah lalu jalankan ulang.${C_0}"; fi
if [ ${#MASALAH[@]} -gt 0 ]; then echo; echo "${C_R} Yang harus diperbaiki:${C_0}"; for m in "${MASALAH[@]}"; do echo "${C_R}  - $m${C_0}"; done; fi
if [ ${#PERINGATAN[@]} -gt 0 ]; then echo; echo "${C_Y} Perlu diperhatikan:${C_0}"; for m in "${PERINGATAN[@]}"; do echo "${C_Y}  - $m${C_0}"; done; fi
echo "${C_C}----------------------------------------------------------------${C_0}"

H "8. CATATAN"
echo "Gunakan SSID Wi-Fi resmi untuk ujian."
echo "System Settings > Wi-Fi > Known Networks: hapus/nonaktifkan auto-join jaringan lain."
echo "Pastikan Mac hanya terhubung ke Wi-Fi ujian yang ditentukan."
echo
echo "${C_Y}PENTING:${C_0}"
echo "${C_Y}Hasil script ini bukan sertifikasi keamanan atau alat untuk menyadap;${C_0}"
echo "${C_Y}alat ini hanya untuk pengecekan jaringan.${C_0}"
echo "${C_Y}Lakukan uji buka SEB sebelum sesi ujian dimulai.${C_0}"
echo; echo "${C_C}Hasil tidak disimpan ke file. Scroll ke atas untuk melihat seluruh hasil.${C_0}"
echo; read -r -p "Tekan ENTER untuk keluar"
