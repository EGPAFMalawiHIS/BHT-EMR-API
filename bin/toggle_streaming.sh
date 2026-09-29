#!/bin/bash

# Toggle the optional patient streaming feature on or off.
#
# Usage: bin/toggle_streaming.sh enable|disable [environment]
#
#   enable   - provisions the `queue` database config/schema (if not already
#              present) via bin/setup_streaming.sh, then activates the
#              patient.streaming GlobalProperty flag.
#   disable  - deactivates the patient.streaming flag WITHOUT touching the
#              queue database or database.yml (non-destructive).
#
# environment defaults to "development" (development|test|production).
#
# Streaming is optional: most sites never need to run this script. The app
# boots and runs fully without a `queue` database unless streaming has been
# enabled.

set -e

ACTION=$1
RAILS_ENV_ARG=${2:-development}

usage() {
  echo "Usage: $0 enable|disable [environment]"
  echo
  echo "  enable   - provision queue DB/schema (if needed) and activate streaming"
  echo "  disable  - deactivate streaming without touching the queue database"
  echo
  echo "environment defaults to 'development' (development|test|production)"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$ACTION" in
  enable)
    # setup_streaming.sh injects the `queue:` block into database.yml only if
    # it isn't already present, then runs `rails streaming:setup`.
    "$SCRIPT_DIR/setup_streaming.sh" "$RAILS_ENV_ARG"
    ;;
  disable)
    RAILS_ENV=$RAILS_ENV_ARG bundle exec rails streaming:disable
    ;;
  *)
    usage
    exit 255
    ;;
esac
