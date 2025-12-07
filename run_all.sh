#!/usr/bin/env bash
# Script to run all types of benchmarks
echo "default"
./benchmark.sh default
echo "power"
./benchmark.sh power
echo "sqrt"
./benchmark.sh sqrt
echo "str"
./benchmark.sh str
