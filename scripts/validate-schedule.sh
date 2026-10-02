#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
validation_dir=$(mktemp -d)
trap 'rm -rf "$validation_dir"' EXIT
swiftc -swift-version 6 -parse-as-library \
  NitteiApp/Models/ClassEntry.swift \
  NitteiApp/Models/AcademicCalendar.swift \
  NitteiApp/Store/AutumnSchedule.swift \
  NitteiApp/Store/ScheduleStore.swift \
  Tests/ScheduleValidation.swift \
  -o "$validation_dir/validate-schedule"
"$validation_dir/validate-schedule"
