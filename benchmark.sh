#!/bin/bash

# --- ARGUMENT VALIDATION ---
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <pal|ntsc> <loops> <run_count>"
    echo "Example: $0 ntsc 50000 10"
    exit 1
fi

STANDARD="$1"
LOOPS="$2"
RUN_COUNT="$3"
RESULTS_FILE="benchmark_results.csv"
#RESULTS_FILE="all_results.txt" 
EMULATOR_TIMEOUT="10s"

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

# --- GENERATE BASIC FILES ---
echo "Generating BASIC files for $STANDARD ($FPS Hz) with $LOOPS loops..."

# Generate ZX Spectrum .bas file
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


../spectrum/bas2tap/bas2tap -a10 spectrum.bas benchmark.tap


if [ ! -f "$RESULTS_FILE" ]; then
    echo "Run,Machine,Standard,Loops,Frames,Seconds" > "$RESULTS_FILE"
fi


echo "Starting $RUN_COUNT benchmark runs. Results will be saved to $RESULTS_FILE"

for i in $(seq 1 "$RUN_COUNT"); do
    echo "--- Run $i of $RUN_COUNT ---"

    # --- Run Spectrum ---
    echo "Running Spectrum..."
    #timeout $EMULATOR_TIMEOUT fuse --machine "$MACHINE_FLAG_SPEC" --tape benchmark.tap --auto-load --fastload --textfile temp_spec.txt 


    #pgrep -f '^fuse' >/dev/null && pkill -f '^fuse' || true
    
    set +m
    
    setsid fuse --machine "$MACHINE_FLAG_SPEC" --tape benchmark.tap --auto-load --fastload --textfile temp_spec.txt >/dev/null 2>&1 & FUSE_PID=$!

    sleep "$EMULATOR_TIMEOUT"


    kill -TERM -"${FUSE_PID}" 2>/dev/null || true
    sleep 1
    kill -KILL -"${FUSE_PID}" 2>/dev/null || true
    

    # SPEC_RESULT=$(cat temp_spec.txt | tr -d '[:space:]')
    # echo "$i,Spectrum,$STANDARD,$SPEC_RESULT" >> "$RESULTS_FILE"
    
    SPEC_RESULT=$(head -n 1 temp_spec.txt | tr -d '[:space:]')
    echo "$i,Spectrum,$STANDARD,$SPEC_RESULT" >> "$RESULTS_FILE"
    

    echo "Running Atari..."

    timeout $EMULATOR_TIMEOUT atari800 $MACHINE_FLAG_ATARI -run atari.bas -nosound cat > temp_atari.txt


    # ATARI_RESULT=$(cat temp_atari.txt | tr -d '[:space:]')
    # echo "$i,Atari,$STANDARD,$ATARI_RESULT" >> "$RESULTS_FILE"
    
    ATARI_RESULT=$(head -n 1 temp_atari.txt | tr -d '[:space:]')
    echo "$i,Atari,$STANDARD,$ATARI_RESULT" >> "$RESULTS_FILE"
    

done


echo "Cleaning up temporary files..."
# rm spectrum.bas atari.bas benchmark.tap temp_spec.txt temp_atari.txt

echo "--- All Done ---"
echo "Results saved to $RESULTS_FILE"
cat "$RESULTS_FILE"
