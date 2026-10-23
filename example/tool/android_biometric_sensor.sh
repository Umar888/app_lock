#!/bin/bash
# Plays the fingerprint sensor for integration_test/biometrics_test.dart on an
# Android emulator. Enroll finger 1 in Settings first (adb emu finger touch 1);
# finger 2 is used as the unknown finger.
#
#   flutter test integration_test/biometrics_test.dart -d <serial> > bio.log 2>&1 &
#   tool/android_biometric_sensor.sh <serial> bio.log <screenshot dir>
E=$1; LOG=$2; OUT=$3; ACT=dev.umarghaffar.app_lock_example/.MainActivity
match() { adb -s $E emu finger touch 1 >/dev/null; echo "sent match"; }
nomatch() { adb -s $E emu finger touch 2 >/dev/null; echo "sent nomatch"; }
shot() { adb -s $E exec-out screencap -p > "$OUT/$1.png"; }
seen=""
while true; do
  for step in enable_match unlock_nomatch_then_match leave_during_prompt; do
    if [[ "$seen" != *"$step"* ]] && grep -q "BIO_WAIT:$step" "$LOG" 2>/dev/null; then
      seen="$seen $step"; echo "step $step"; sleep 3
      case $step in
        enable_match) shot 1_enable_prompt; match ;;
        unlock_nomatch_then_match) shot 2_lock_prompt; nomatch; sleep 2; shot 3_after_nomatch; match; sleep 2; shot 4_after_match ;;
        leave_during_prompt) nomatch; sleep 1.5; shot 5_failed
          adb -s $E shell input keyevent KEYCODE_HOME; echo "left app"; sleep 3; shot 6_home
          adb -s $E shell am start -n $ACT >/dev/null; echo "returned"; sleep 3; shot 7_returned_reprompt
          match; sleep 2; shot 8_unlocked ;;
      esac
    fi
  done
  grep -qE "All tests passed|Some tests failed|\[E\]" "$LOG" 2>/dev/null && break
  sleep 0.5
done
echo host done
