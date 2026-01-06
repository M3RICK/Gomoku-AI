#!/bin/bash
echo "Testing if threat detection for ALL 4 directions:"
echo ""
echo "Horizontal"
{ echo "START 20"; echo "BOARD"; echo "10,10,1"; echo "10,11,1"; echo "10,12,1"; echo "10,13,1"; echo "DONE"; echo "END"; } | ./pbrain-gomoku-ai 2>/dev/null | grep -v "^$"

echo ""
echo "Vertical"
{ echo "START 20"; echo "BOARD"; echo "10,10,1"; echo "11,10,1"; echo "12,10,1"; echo "13,10,1"; echo "DONE"; echo "END"; } | ./pbrain-gomoku-ai 2>/dev/null | grep -v "^$"

echo ""
echo "Diagonal issue ?"
{ echo "START 20"; echo "BOARD"; echo "10,10,1"; echo "11,11,1"; echo "12,12,1"; echo "13,13,1"; echo "DONE"; echo "END"; } | ./pbrain-gomoku-ai 2>/dev/null | grep -v "^$"

echo ""
echo "Anti-diagonal no issue please"
{ echo "START 20"; echo "BOARD"; echo "10,13,1"; echo "11,12,1"; echo "12,11,1"; echo "13,10,1"; echo "DONE"; echo "END"; } | ./pbrain-gomoku-ai 2>/dev/null | grep -v "^$"
