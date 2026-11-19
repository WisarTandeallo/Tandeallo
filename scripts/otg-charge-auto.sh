#!/system/bin/sh
# OTG + daya luar otomatis (v3): sink + host + batas arus
# v3: tahan terhadap kedipan tegangan, coba ulang lebih lama, batas arus 1,2 A.
A=1200000
U=/sys/class/power_supply/usb
M=/sys/devices/platform/soc/a600000.ssusb/mode
P=/sys/module/smb_lib/parameters/otg_chg_icl_ua
V=/sys/kernel/debug/pmic-votable/USB_ICL
D=/sys/bus/usb/devices
LOG=/data/local/tmp/otg-charge-auto.log

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null
echo "$(date +%T) skrip v3 mulai (A=$A)" >> $LOG

aktif=0
dicoba=0
hilang=0

ada_perangkat() {
  [ -e $D/1-1 ] || [ -e $D/2-1 ]
}

pasang_arus() {
  if [ -f $P ]; then
    echo $A > $P
    echo $A > $V/force_val
    echo 1 > $V/force_active
  fi
}

lepas_arus() {
  [ -f $V/force_active ] && echo 0 > $V/force_active
  [ -f $P ] && echo 0 > $P
}

coba_host() {
  n=1
  while [ $n -le 3 ]; do
    echo 2 > $U/typec_power_role; sleep 3
    echo host > $M; sleep 2
    i=0
    while [ $i -lt 10 ]; do
      ada_perangkat && return 0
      [ "$(cat $U/present)" = "1" ] || return 1
      sleep 1; i=$((i + 1))
    done
    echo "$(date +%T) percobaan $n belum ada hub, ulangi" >> $LOG
    echo none > $M; sleep 1
    n=$((n + 1))
  done
  return 1
}

while true; do
  ada=$(cat $U/present)

  # Daya luar terdeteksi: siapkan sink + host.
  if [ "$ada" = "1" ] && [ "$dicoba" = "0" ]; then
    dicoba=1
    sleep 2
    echo "$(date +%T) terdeteksi: $(cat $U/typec_mode)" >> $LOG
    if coba_host; then
      pasang_arus
      aktif=1
      echo "$(date +%T) aktif (peran $(cat $U/typec_power_role))" >> $LOG
    else
      lepas_arus
      echo 1 > $U/typec_power_role
      echo peripheral > $M
      echo "$(date +%T) tidak ada hub, kembali normal" >> $LOG
    fi
  fi

  # Jaga kunci sink selama aktif.
  if [ "$aktif" = "1" ] && [ "$ada" = "1" ] && [ "$(cat $U/typec_power_role)" != "sink" ]; then
    echo 2 > $U/typec_power_role
    echo "$(date +%T) kunci sink dipasang ulang" >> $LOG
  fi

  # Hub hilang padahal daya masih ada: sambungkan ulang host.
  if [ "$aktif" = "1" ] && [ "$ada" = "1" ] && ! ada_perangkat; then
    sleep 3
    if ! ada_perangkat; then
      echo "$(date +%T) hub hilang, sambung ulang" >> $LOG
      if coba_host; then
        pasang_arus
        echo "$(date +%T) tersambung lagi" >> $LOG
      fi
    fi
  fi

  # Daya hilang: anggap dicabut hanya jika berlangsung 3 detik berturut-turut.
  if [ "$ada" != "1" ] && [ "$dicoba" = "1" ]; then
    hilang=$((hilang + 1))
    if [ $hilang -ge 3 ]; then
      lepas_arus
      echo 1 > $U/typec_power_role
      aktif=0
      dicoba=0
      hilang=0
      echo "$(date +%T) dicabut, normal" >> $LOG
    fi
  else
    hilang=0
  fi

  sleep 1
done
