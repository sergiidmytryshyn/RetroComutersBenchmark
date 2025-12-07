#!/usr/bin/env bash
set -euo pipefail

# Benchmark runner
# Usage examples:
#   ./benchmark.sh <default|power|sqrt|str>

RESULTS_FILE="benchmark_results.csv"

# CONFIGS
DEFAULT_STANDARD="${STANDARD:-ntsc}"
DEFAULT_LOOPS_LIST=(500 1000 1500) # used also 5000, but it is kinda long for non default runs
REPS=3

# parse positional args
BENCHMARK="${1:-default}"         # benchmark type: default|power|sqrt|str
LOOPS_ARG="${2:-}"                # optional comma separated loops 
REPS_ARG="${3:-}"                 # optional repetitions override

# determine loops array
if [ -n "$LOOPS_ARG" ]; then
    IFS=',' read -r -a LOOPS_LIST <<< "$LOOPS_ARG"
else
    LOOPS_LIST=("${DEFAULT_LOOPS_LIST[@]}")
fi


# standard
STANDARD="$DEFAULT_STANDARD"

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

echo "Benchmark: $BENCHMARK | Standard: $STANDARD (FPS=$FPS). Results -> $RESULTS_FILE"

GLOBAL_RUN=0

# -----------------------------------------------------------------------------
# TIMEOUT CONFIGURATION
# Define estimated seconds per loop iteration for each benchmark type here.
# -----------------------------------------------------------------------------

# I need to set timeout to kill process, read its outputs and continue
# These values were taken from several runs
get_time_per_loop() {
    case "$BENCHMARK" in
        default)
            # Simple 'for' loop is fast
            echo "0.008" 
            ;;
        power)
            # Bringing number to power 1.234
            echo "0.2"  
            ;;
        sqrt)
            # Square roots
            echo "0.12" 
            ;;
        str)
            # String manipulation and memory allocation
            echo "0.08" 
            ;;
        *)
            # Fallback for unknown benchmarks
            echo "0.1"
            ;;
    esac
}

# Yes, generation of .bas could be more automated(only loop part changed), but sometimes need some extra changes, so whatever
# Generating .bas for Spectrum
generate_spectrum_basic() {
    local LOOPS="$1"
    local OUT="$2"

    case "$BENCHMARK" in
        default)
            cat > "$OUT" <<EOF
10 POKE 23672,0
20 POKE 23673,0
30 LET A=0
40 FOR I=1 TO $LOOPS
50   LET A=A + 1
60 NEXT I
70 LET FRAMES=PEEK(23672)+PEEK(23673)*256
80 LET SECS=FRAMES/$FPS
90 LPRINT A; ","; FRAMES; ","; SECS
EOF
            ;;
        power)
            cat > "$OUT" <<EOF
10 POKE 23672,0
20 POKE 23673,0
30 LET A=0
40 FOR I=1 TO $LOOPS
45   LET X= I ^ 1.234
50   LET A=A + X
60 NEXT I
70 LET FRAMES=PEEK(23672)+PEEK(23673)*256
80 LET SECS=FRAMES/$FPS
90 LPRINT A; ","; FRAMES; ","; SECS
EOF
            ;;
        sqrt)
            cat > "$OUT" <<EOF
10 POKE 23672,0
20 POKE 23673,0
30 LET S=0
40 FOR I=1 TO $LOOPS
50   LET S = S + SQR(I)
60 NEXT I
70 LET FRAMES=PEEK(23672)+PEEK(23673)*256
80 LET SECS=FRAMES/$FPS
90 LPRINT S; ","; FRAMES; ","; SECS
EOF
            ;;
        str)
            cat > "$OUT" <<EOF
10 POKE 23672,0
20 POKE 23673,0
30 LET S\$ = ""
40 FOR I=1 TO $LOOPS
50   LET S\$ = S\$ + "A"
60 NEXT I
70 LET FRAMES=PEEK(23672)+PEEK(23673)*256
80 LET SECS=FRAMES/$FPS
86 PRINT LEN(S\$)
90 LPRINT LEN(S\$); ","; FRAMES; ","; SECS
EOF
            ;;
        *)
            echo "Unknown benchmark '$BENCHMARK' for Spectrum; falling back to default."
            generate_spectrum_basic "$LOOPS" "$OUT" || true
            ;;
    esac
}

# Generating .bas for Atari
generate_atari_basic() {
    local LOOPS="$1"
    local OUT="$2"

    case "$BENCHMARK" in
        default)
            cat > "$OUT" <<EOF
10 POKE 20,0
20 POKE 19,0
30 POKE 18,0
40 LET A = 0
50 FOR I = 1 TO $LOOPS
60   A = A + 1
70 NEXT I
80 FRAMES = PEEK(20) + PEEK(19) * 256 + PEEK(18) * 65536
90 SECS = FRAMES / $FPS
100 LPRINT A; ","; FRAMES; ","; SECS
110 END
EOF
            ;;
        power)
            cat > "$OUT" <<EOF
10 POKE 20,0
20 POKE 19,0
30 POKE 18,0
40 LET A = 0
50 FOR I = 1 TO $LOOPS
55   X = I ^ 1.234
60   A = A + X
70 NEXT I
80 FRAMES = PEEK(20) + PEEK(19) * 256 + PEEK(18) * 65536
90 SECS = FRAMES / $FPS
100 LPRINT A; ","; FRAMES; ","; SECS
110 END
EOF
            ;;
        sqrt)
            cat > "$OUT" <<EOF
10 POKE 20,0
20 POKE 19,0
30 POKE 18,0
40 S = 0
50 FOR I = 1 TO $LOOPS
60   S = S + SQR(I)
70 NEXT I
80 FRAMES = PEEK(20) + PEEK(19) * 256 + PEEK(18) * 65536
90 SECS = FRAMES / $FPS
100 LPRINT S; ","; FRAMES; ","; SECS
110 END
EOF
            ;;
        str)
            cat > "$OUT" <<EOF
10 POKE 20,0
20 POKE 19,0
30 POKE 18,0
40 L = $LOOPS
50 DIM A\$(L)
60 A\$=""
70 FOR I=1 TO L
80   A\$(LEN(A\$)+1)="A"
90 NEXT I
100 S = LEN(A\$)
110 FRAMES = PEEK(20) + PEEK(19) * 256 + PEEK(18) * 65536
120 SECS = FRAMES / $FPS
130 LPRINT S; ","; FRAMES; ","; SECS
140 END
EOF
            ;;
        *)
            echo "Unknown benchmark '$BENCHMARK' for Atari; falling back to default."
            generate_atari_basic "$LOOPS" "$OUT" || true
            ;;
    esac
}

run_once() {
    local LOOPS="$1"
    GLOBAL_RUN=$((GLOBAL_RUN + 1))
    local i="$GLOBAL_RUN"

    echo "--- Run $i --- (Loops=$LOOPS)"

    # Get the time estimate based on the benchmark type
    BASE_TIME_PER_LOOP=$(get_time_per_loop)
    SAFETY="1.5"
    TIMEOUT_SEC=$(awk -v loops="$LOOPS" -v base="$BASE_TIME_PER_LOOP" -v k="$SAFETY" 'BEGIN { print (loops * base * k) + 2 }')
    EMULATOR_TIMEOUT="${TIMEOUT_SEC}s"
    
    echo "Config: $BENCHMARK | Base Time: ${BASE_TIME_PER_LOOP}s/loop | Timeout: $EMULATOR_TIMEOUT"

    TMP_PREFIX="bench_${BENCHMARK}_${LOOPS}_$$"
    SPEC_BAS="${TMP_PREFIX}_spec.bas"
    ATARI_BAS="${TMP_PREFIX}_atari.bas"
    TAP_FILE="${TMP_PREFIX}.tap"

    TEMP_SPEC_TXT="temp_spec.txt"
    TEMP_ATARI_TXT="temp_atari.txt"

    # generate BASIC bodies
    generate_spectrum_basic "$LOOPS" "$SPEC_BAS"
    generate_atari_basic "$LOOPS" "$ATARI_BAS"

    # create TAP for Spectrum
    ../spectrum/bas2tap/bas2tap -a10 "$SPEC_BAS" "$TAP_FILE" >/dev/null 2>&1 || {
        echo "Warning: bas2tap failed or not found for Spectrum; continuing anyway."
    }

    # ---------------------------
    # Run Spectrum (fuse)
    # ---------------------------
    echo "Running Spectrum..."
    set +m
    setsid fuse --machine "$MACHINE_FLAG_SPEC" --tape "$TAP_FILE" --auto-load --fastload --textfile "$TEMP_SPEC_TXT" >/dev/null 2>&1 & FUSE_PID=$!

    sleep "$EMULATOR_TIMEOUT"

    kill -TERM -"${FUSE_PID}" 2>/dev/null || true
    sleep 1
    kill -KILL -"${FUSE_PID}" 2>/dev/null || true

    SPEC_RESULT=$(grep -m1 -Eo '[^[:space:]]+' "$TEMP_SPEC_TXT" 2>/dev/null | head -n1 || true)
    SPEC_RESULT="${SPEC_RESULT:-}"
    echo "$i,Spectrum,$STANDARD,$LOOPS,$SPEC_RESULT" >> "$RESULTS_FILE"

    # ---------------------------
    # Run Atari
    # ---------------------------
    echo "Running Atari..."
    timeout "$EMULATOR_TIMEOUT" atari800 $MACHINE_FLAG_ATARI -run "$ATARI_BAS" -nosound cat > "$TEMP_ATARI_TXT" 2>/dev/null || true

    ATARI_RESULT=$(grep -m1 -Eo '[^[:space:]]+' "$TEMP_ATARI_TXT" 2>/dev/null | head -n1 || true)
    ATARI_RESULT="${ATARI_RESULT:-}"
    echo "$i,Atari,$STANDARD,$LOOPS,$ATARI_RESULT" >> "$RESULTS_FILE"

    # cleanup
    rm -f "$SPEC_BAS" "$ATARI_BAS" "$TAP_FILE" "$TEMP_SPEC_TXT" "$TEMP_ATARI_TXT"
}

# MAIN: iterate
for loops_val in "${LOOPS_LIST[@]}"; do
    for rep in $(seq 1 "$REPS"); do
        run_once "$loops_val"
    done
done

echo "--- All Done ---"
echo "Results saved to $RESULTS_FILE"
cat "$RESULTS_FILE"
