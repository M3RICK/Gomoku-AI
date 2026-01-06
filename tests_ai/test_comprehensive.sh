#!/bin/bash

echo "WINNING MOVE TESTS"

echo "Test 1: Horizontal win"
{
    echo "START 20"
    echo "BOARD"
    echo "10,10,1"
    echo "10,11,1"
    echo "10,12,1"
    echo "10,13,1"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
echo "Expected: 10,14 or 10,9"

echo ""
echo "Test 2: Vertical win"
{
    echo "START 20"
    echo "BOARD"
    echo "5,8,1"
    echo "6,8,1"
    echo "7,8,1"
    echo "8,8,1"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
echo "Expected: 9,8 or 4,8"

echo ""
echo "Test 3: Diagonal win"
{
    echo "START 20"
    echo "BOARD"
    echo "10,10,1"
    echo "11,11,1"
    echo "12,12,1"
    echo "13,13,1"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
echo "Expected: 14,14 or 9,9"

echo ""
echo "Test 4: Anti-diagonal win"
{
    echo "START 20"
    echo "BOARD"
    echo "10,13,1"
    echo "11,12,1"
    echo "12,11,1"
    echo "13,10,1"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
echo "Expected: 14,9 or 9,14"

echo ""
echo "BLOCKING TESTS"

echo "Test 5: Block horizontal"
{
    echo "START 20"
    echo "BOARD"
    echo "7,7,2"
    echo "7,8,2"
    echo "7,9,2"
    echo "7,10,2"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
echo "Expected: 7,11 or 7,6 (block)"

echo ""
echo "Test 6: Block vertical"
{
    echo "START 20"
    echo "BOARD"
    echo "12,5,2"
    echo "13,5,2"
    echo "14,5,2"
    echo "15,5,2"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
echo "Expected: 16,5 or 11,5 (block)"

echo ""
echo "Test 7: Block diagonal"
{
    echo "START 20"
    echo "BOARD"
    echo "5,5,2"
    echo "6,6,2"
    echo "7,7,2"
    echo "8,8,2"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
echo "Expected: 9,9 or 4,4 (block)"

echo ""
echo "=== THREAT TESTS ==="

echo "Test 8: Open-4 threat, SHOULD block instead of aligning 3"
{
    echo "START 20"
    echo "BOARD"
    echo "10,10,1"
    echo "10,11,1"
    echo "10,12,1"
    echo "5,5,2"
    echo "5,6,2"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
echo "Expected: 10,9 or 10,13 (create open-4 threat)"

echo ""
echo "Test 9: Defend against fourchette attempt"
{
    echo "START 20"
    echo "BOARD"
    echo "10,10,2"
    echo "11,11,2"
    echo "12,12,2"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
echo "Expected: Defensive move vs fork"

echo ""
echo "EDGE CASES"

echo "Test 10: Near edge"
{
    echo "START 20"
    echo "BOARD"
    echo "0,10,1"
    echo "1,10,1"
    echo "2,10,1"
    echo "3,10,1"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
echo "Expected: 4,10 negative es no possible"

echo ""
echo "Test 11: Win vs block priority SHOULD win not block)"
{
    echo "START 20"
    echo "BOARD"
    echo "10,10,1"
    echo "10,11,1"
    echo "10,12,1"
    echo "10,13,1"
    echo "5,5,2"
    echo "5,6,2"
    echo "5,7,2"
    echo "5,8,2"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai 2>/dev/null
echo "Expected: 10,14 or 10,9 (WIN, not block at 5,9/5,4)"
