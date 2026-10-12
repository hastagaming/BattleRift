#!/usr/bin/env bash
# Starts a real headless BattleRift server and two probe clients, then checks the reconnect flow.
# Usage: GODOT=/path/to/godot scripts/tests/run_reconnect_probe.sh
set -u
GODOT="${GODOT:-godot}"
PORT="${PORT:-47921}"
LOG_DIR="$(mktemp -d)"

"$GODOT" --headless --path . res://scenes/server/server.tscn -- --dev-accounts --dev-capacity=2 --no-discovery --port="$PORT" --reconnect-grace=4 >"$LOG_DIR/server.log" 2>&1 &
SERVER_PID=$!
sleep 5

"$GODOT" --headless --path . -s res://scripts/tests/reconnect_probe.gd -- --role=bob --port="$PORT" >"$LOG_DIR/bob.log" 2>&1 &
BOB_PID=$!
sleep 1
"$GODOT" --headless --path . -s res://scripts/tests/reconnect_probe.gd -- --role=alice --port="$PORT" >"$LOG_DIR/alice.log" 2>&1 &
ALICE_PID=$!

wait "$ALICE_PID"; ALICE_CODE=$?
wait "$BOB_PID"; BOB_CODE=$?
kill "$SERVER_PID" 2>/dev/null
wait "$SERVER_PID" 2>/dev/null

grep -h "^PASS\|^FAIL\|finished" "$LOG_DIR/alice.log" "$LOG_DIR/bob.log"
echo "--- server log ---"
grep -h "^\[match" "$LOG_DIR/server.log"
echo "logs: $LOG_DIR"
if [ "$ALICE_CODE" -eq 0 ] && [ "$BOB_CODE" -eq 0 ]; then
	echo "RECONNECT PROBE: OK"
	exit 0
fi
echo "RECONNECT PROBE: FAILED (alice=$ALICE_CODE bob=$BOB_CODE)"
exit 1