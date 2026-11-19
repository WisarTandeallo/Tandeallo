#!/system/bin/sh
# OTG + daya luar otomatis (v2): sink + host + batas arus
# Bekerja untuk adaptor OTG (Sink attached) dan rakitan kabel A-ke-C (Source attached).
A=2000000
U=/sys/class/power_supply/usb
M=/sys/devices/platform/soc/a600000.ssusb/mode
P=/sys/module/smb_lib/parameters/otg_chg_icl_ua
V=/sys/kernel/debug/pmic-votable/USB_ICL
D=/sys/bus/usb/devices
LOG=/data/local/tmp/otg-charge-auto.log

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null
echo "$(date +%T) skrip mulai" >> $LOG

aktif=0
dicoba=0

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
  echo 2 > $U/typec_power_role; sleep 3
  echo host > $M; sleep 2
  i=0
  while [ $i -lt 6 ]; do
    ada_perangkat && return 0
    sleep 1; i=$((i + 1))
  done
  return 1
}

while true; do
  ada=$(cat $U/present)
  if [ "$ada" = "1" ] && [ "$dicoba" = "0" ]; then
    dicoba=1
    mode=$(cat $U/typec_mode)
    echo "$(date +%T) terdeteksi: $mode" >> $LOG
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
  if [ "$aktif" = "1" ] && [ "$(cat $U/typec_power_role)" != "sink" ]; then
    echo 2 > $U/typec_power_role
    echo "$(date +%T) kunci sink dipasang ulang" >> $LOG
  fi
  if [ "$ada" != "1" ] && [ "$dicoba" = "1" ]; then
    lepas_arus
    echo 1 > $U/typec_power_role
    aktif=0
    dicoba=0
    echo "$(date +%T) dicabut, normal" >> $LOG
  fi
  sleep 1
done
