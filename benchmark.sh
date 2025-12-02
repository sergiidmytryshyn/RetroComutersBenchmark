#!/bin/bash

# No usage, just run ./benchmark.sh and it runs NTSC for loops = [500,1000,1500,5000,10000], 3 repetitions each

RESULTS_FILE="benchmark_results.csv"
EMULATOR_TIMEOUT="10s"

if [ "$#" -eq 3 ]; then
    STANDARD="$1"
    SINGLE_LOOPS="$2"
    SINGLE_RUN_COUNT="$3"
    MODE="single"
else
    # default automated sequential mode
    STANDARD="ntsc"
    LOOPS_LIST=(500 1000 1500 5000 10000)
    REPS=3
    MODE="batch"
fi

# --- SETTINGS BASED ON STANDARD ---
if [ "$STANDARD" == "pal" ]; then
    FPS=50
    MACHINE_FLAG_SPEC="48"
    MACHINE_FLAG_ATARI="-pal"
elif [ "$STANDARD" == "ntsc" ]; then
    FPS=60
    MACHINE_FLAG_SPEC="48_ntsc"
    MACHINE_FLAG_ATARI="-ntsc"
else
    echo "Error: Standard must be 'pal' or 'ntsc'."
    exit 1
fi

# ensure results file header
if [ ! -f "$RESULTS_FILE" ]; then
    echo "Run,Machine,Standard,Loops,Frames,Seconds" > "$RESULTS_FILE"
fi

echo "Standard: $STANDARD (FPS=$FPS). Results -> $RESULTS_FILE"

# helper to run one benchmark for a given LOOPS and incrementing run id
GLOBAL_RUN=0
run_once() {
    local LOOPS="$1"

    GLOBAL_RUN=$((GLOBAL_RUN + 1))
    local i="$GLOBAL_RUN"

    echo "--- Run $i --- (Loops=$LOOPS)"

    if [ "$STANDARD" = "pal" ]; then
        BASE_TIME_PER_LOOP="0.0079"
    else
        BASE_TIME_PER_LOOP="0.005466"
    fi

    SAFETY="1.5"
    TIMEOUT_SEC=$(awk -v loops="$LOOPS" -v base="$BASE_TIME_PER_LOOP" -v k="$SAFETY" 'BEGIN { print loops * base * k }')
    EMULATOR_TIMEOUT="${TIMEOUT_SEC}s"
    echo "Calculated timeout: $EMULATOR_TIMEOUT"

    # --- GENERATE BASIC FILES (per-run, using LOOPS) ---
cat << EOF > spectrum.bas
10 POKE 23672, 0
20 POKE 23673, 0
30 LET A = 0
40 FOR I = 1 TO $LOOPS
50   LET A = A + 1
60 NEXT I
70 LET FRAMES = PEEK(23672) + PEEK(23673) * 256
80 LET SECS = FRAMES / $FPS
90 LPRINT A; ","; FRAMES; ","; SECS
EOF

# Generate Atari .bas file
cat << EOF > atari.bas
10 POKE 20, 0
20 POKE 19, 0
30 POKE 18, 0
40 LET A = 0
50 FOR I = 1 TO $LOOPS
60   A = A + 1
70 NEXT I
80 FRAMES = PEEK(20) + PEEK(19) * 256 + PEEK(18) * 65536
90 SECS = FRAMES / $FPS
100 LPRINT A; ","; FRAMES; ","; SECS
110 END
EOF

    # create TAP for Spectrum
    ../spectrum/bas2tap/bas2tap -a10 spectrum.bas benchmark.tap

    # ---------------------------
    # Run Spectrum
    # ---------------------------
    echo "Running Spectrum..."
    set +m
    setsid fuse --machine "$MACHINE_FLAG_SPEC" --tape benchmark.tap --auto-load --fastload --textfile temp_spec.txt >/dev/null 2>&1 & FUSE_PID=$!

    # sleep emulator timeout then terminate group
    sleep "$EMULATOR_TIMEOUT"

    kill -TERM -"${FUSE_PID}" 2>/dev/null || true
    sleep 1
    kill -KILL -"${FUSE_PID}" 2>/dev/null || true

    # read result (first non-empty line)
    SPEC_RESULT=$(head -n 1 temp_spec.txt 2>/dev/null | tr -d '[:space:]')
    echo "$i,Spectrum,$STANDARD,$LOOPS,$SPEC_RESULT" >> "$RESULTS_FILE"

    # ---------------------------
    # Run Atari
    # ---------------------------
    echo "Running Atari..."
    # use timeout wrapper to avoid hangs (keeps behavior similar to your original)
    timeout $EMULATOR_TIMEOUT atari800 $MACHINE_FLAG_ATARI -run atari.bas -nosound cat > temp_atari.txt 2>/dev/null || true

    ATARI_RESULT=$(head -n 1 temp_atari.txt 2>/dev/null | tr -d '[:space:]')
    echo "$i,Atari,$STANDARD,$LOOPS,$ATARI_RESULT" >> "$RESULTS_FILE"

    # cleanup small temps (keep baseline TAP if you'd like)
    rm -f spectrum.bas atari.bas benchmark.tap temp_spec.txt temp_atari.txt
}

# --- MAIN EXECUTION PATHS ---
if [ "$MODE" == "single" ]; then
    # keep original single-run behaviour (one loops value for run_count runs)
    for run_i in $(seq 1 "$SINGLE_RUN_COUNT"); do
        run_once "$SINGLE_LOOPS"
    done
else
    # batch mode: iterate list and repeat REPS times each, sequentially
    for loops_val in "${LOOPS_LIST[@]}"; do
        for rep in $(seq 1 "$REPS"); do
            run_once "$loops_val"
        done
    done
fi

echo "--- All Done ---"
echo "Results saved to $RESULTS_FILE"
cat "$RESULTS_FILE"
