#!/bin/bash
echo "Debug: Manual diagonal test, parce que ca veut pas la"
{
    echo "START 20"
    echo "BOARD"
    echo "10,10,1"
    echo "11,11,1"
    echo "12,12,1"
    echo "13,13,1"
    echo "14,14,1"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
