#!/bin/bash
# Plays the Face ID / Touch ID sensor for integration_test/biometrics_test.dart
# on an iOS simulator: it watches the test log for BIO_WAIT markers and sends
# match / no-match events, saving a screenshot at each step.
#
#   xcrun simctl spawn <udid> notifyutil -s com.apple.BiometricKit.enrollmentChanged 1
#   xcrun simctl spawn <udid> notifyutil -p com.apple.BiometricKit.enrollmentChanged
#   flutter test integration_test/biometrics_test.dart -d <udid> > bio.log 2>&1 &
#   tool/ios_biometric_sensor.sh <udid> bio.log <screenshot dir> <face|finger>
U=$1; LOG=$2; OUT=$3; KIND=$4; BUNDLE=dev.umarghaffar.appLockExample
if [ "$KIND" = face ]; then EV=pearl; else EV=fingerTouch; fi
send() { xcrun simctl spawn $U notifyutil -p com.apple.BiometricKit_Sim.$EV.$1; echo "sent $1"; }
shot() { xcrun simctl io $U screenshot "$OUT/$1.png" >/dev/null 2>&1; echo "shot $1"; }
seen=""
while true; do
  for step in enable_match unlock_nomatch_then_match leave_during_prompt; do
    if [[ "$seen" != *"$step"* ]] && grep -q "BIO_WAIT:$step" "$LOG" 2>/dev/null; then
      seen="$seen $step"
      echo "step $step"
      sleep 2.5
      case $step in
        enable_match) shot 1_enable_prompt; send match ;;
        unlock_nomatch_then_match) shot 2_lock_prompt; send nomatch; sleep 2; shot 3_after_nomatch; send match; sleep 2; shot 4_after_match ;;
        leave_during_prompt) send nomatch; sleep 1.5; shot 5_failed_dialog
          xcrun simctl launch $U com.apple.Preferences >/dev/null; echo "left app"; sleep 3; shot 6_in_settings
          xcrun simctl launch $U $BUNDLE >/dev/null; echo "returned"; sleep 3; shot 7_returned_reprompt
          send match; sleep 2; shot 8_unlocked ;;
      esac
    fi
  done
  grep -qE "All tests passed|Some tests failed|\[E\]" "$LOG" 2>/dev/null && break
  sleep 0.5
done
echo host done
