#!/bin/bash

echo "Test: Should see the trap, #methode de la fourchette"
{
    echo "START 20"
    echo "BOARD"
    echo "10,10,2"
    echo "11,11,2"
    echo "12,12,2"
    echo "9,11,1"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null

echo ""
echo "empty board"
{
    echo "START 20"
    echo "BEGIN"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
