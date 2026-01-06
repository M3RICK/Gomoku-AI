#!/bin/bash
echo "Does AI recognize 5-diagonal as won state?"
{
    echo "START 20"
    echo "BOARD"
    echo "7,7,1"
    echo "8,8,1"
    echo "9,9,1"
    echo "10,10,1"
    echo "11,11,1"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
