#!/bin/bash
# Usage: ./run-cuda.sh <size>
# Example: ./run-cuda.sh 256


RUNNER="./rabbitRunner-SSE-NVCC"
INPUT="./RabbitInput/RabbitInput.rct"
REF="./RabbitInput/Reference512.vol"

$RUNNER -i $INPUT -m LolaCUDA -s 512 -c $REF