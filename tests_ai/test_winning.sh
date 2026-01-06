#!/bin/bash

echo "Test 1: Should detect winning move"
{
    echo "START 20"
    echo "BOARD"
    echo "10,10,1"
    echo "10,11,1"
    echo "10,12,1"
    echo "10,13,1"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai

echo ""
echo "Test 2: Should block opponent win"
{
    echo "START 20"
    echo "BOARD"
    echo "5,5,2"
    echo "5,6,2"
    echo "5,7,2"
    echo "5,8,2"
    echo "DONE"
    echo "END"
} | ./pbrain-gomoku-ai

echo ""
echo "Test 3: Simple turn response"
{
    echo "START 20"
    echo "TURN 10,10"
    echo "END"
} | ./pbrain-gomoku-ai
