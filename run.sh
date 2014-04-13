#!/bin/bash
start_time = 'date +%s'

lua client.lua

END = $(date +%s)
DIFF = $(( $END - $start_time ))
echo "It took $DIFF seconds"

