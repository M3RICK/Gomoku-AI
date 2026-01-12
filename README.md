# Gomoku AI Engine

A high-performance Gomoku (Five in a Row) AI engine written in Zig, implementing advanced game tree search algorithms and strategic evaluation techniques.

## Overview

This Gomoku AI combines classical minimax search with modern optimization techniques to deliver strong tactical and strategic play. The engine supports the standard Gomoku protocol and can compete against other AI implementations or serve as a challenging opponent.

## Key Features

### Search Algorithms

- **Negamax with Alpha-Beta Pruning**: Efficient game tree search with aggressive pruning
- **Iterative Deepening**: Progressive depth search up to 14 plies with time management
- **Principal Variation Search (PVS)**: Zero-window search for non-principal moves with re-search when needed
- **Quiescence Search**: Tactical search extension (4 plies) to avoid horizon effects
- **Null Move Pruning**: Forward pruning technique with adaptive reduction (R=2-3)
- **Late Move Reductions (LMR)**: Reduced-depth search for later moves in the move ordering

### Optimization Techniques

- **Transposition Tables**: 1 million entry hash table with Zobrist hashing for position caching
- **Move Ordering**:
  - Winning moves (highest priority)
  - Blocking opponent wins
  - Killer move heuristic (2 slots per depth)
  - History heuristic with depth-squared bonuses
  - Center proximity bias
- **Adaptive Move Generation**: Dynamic search radius based on board density (radius 3-5)
- **Critical Move Narrowing**: Focused search on tactical moves in critical positions

### Evaluation System

- **Pattern Recognition**: Multi-directional pattern scanning (horizontal, vertical, diagonal, anti-diagonal)
- **Threat Detection**:
  - Five-in-a-row detection
  - Open four patterns
  - Semi-open four patterns
  - Fork detection (double threats)
  - Broken pattern analysis (threes, fours, fives)
- **Positional Scoring**: Pattern-based evaluation with configurable weights
- **Dynamic Defense Weighting**: Adaptive opponent score multiplier (10x-13x) based on threat level

### Strategic Components

- **Opening Book**: Predefined responses for the first 2-3 moves
- **Time Management**: Deadline-based search with graceful termination
- **Tactical Extensions**: Automatic search deepening in forcing sequences

## Architecture

The codebase follows a modular design pattern with clear separation of concerns:

```
src/
├── ai/
│   ├── engine.zig                    # Main AI engine interface
│   ├── opening_book.zig              # Opening move database
│   ├── search/
│   │   ├── minimax.zig               # Core search algorithm with PVS
│   │   ├── quiescence.zig            # Tactical search extension
│   │   └── timer.zig                 # Time management utilities
│   ├── evaluation/
│   │   ├── pattern.zig               # Pattern recognition and scoring
│   │   ├── position.zig              # Position evaluation
│   │   ├── threat.zig                # Threat detection and analysis
│   │   └── advanced_patterns.zig     # Complex pattern detection
│   └── optimization/
│       ├── transposition.zig         # Hash table and Zobrist hashing
│       └── move_ordering.zig         # Move ordering heuristics
├── game/
│   ├── board.zig                     # Board representation and operations
│   ├── move.zig                      # Move structure and utilities
│   ├── movegen.zig                   # Move generation with adaptive radius
│   ├── rules.zig                     # Game rules and win detection
│   └── direction.zig                 # Direction utilities for pattern scanning
├── protocol/
│   ├── parser.zig                    # Command parsing
│   ├── handler.zig                   # Command handling
│   ├── reader.zig                    # Input reading
│   └── writer.zig                    # Output writing
└── main.zig                          # Entry point
```

## Building

### Prerequisites

- Zig 0.16.0-dev or later

### Build Commands

```bash
# Build the executable (optimized)
make

# Or using Zig directly
zig build -Doptimize=ReleaseFast

# Run tests
zig build test

# Run the engine
./zig-out/bin/G_AIA_500_TLS_5_1_gomoku_16
```

## Usage

The engine communicates via standard input/output using the Gomoku protocol. Key commands:

```
START <board_size>           # Initialize game with specified board size
TURN <x>,<y>                 # Opponent move notification
BEGIN                        # AI plays first
BOARD <board_state>          # Set board state
INFO timeout_turn <ms>       # Set time limit per move
```

The AI responds with:
```
<x>,<y>                      # AI move coordinates
```

## Technical Details

### Search Characteristics

| Parameter | Value |
|-----------|-------|
| Maximum Depth | 14 plies |
| Transposition Table Size | 1,000,000 entries |
| Quiescence Depth | 4 plies |
| Killer Move Slots | 2 per depth |
| Default Time Limit | 5000ms per move |
| Move Generation Radius | 3-5 (adaptive) |

### Scoring System

The evaluation function uses weighted patterns:

| Pattern | Closed | Semi-Open | Open |
|---------|--------|-----------|------|
| Two | 50 | 200 | 500 |
| Three | 1,000 | 5,000 | 50,000 |
| Four | 10,000 | 60,000 | 100,000 |
| Five | 500,000 | 500,000 | 500,000 |

Additional tactical bonuses:
- Open Four: 950,000
- Semi-Open Four: 550,000
- Open Three: 95,000
- Fork (double threat): 500,000+

### Performance Optimizations

1. **Incremental Hash Updates**: O(1) hash updates during move make/undo
2. **Bitwise Operations**: Efficient position hashing
3. **Memory Pooling**: Reusable data structures for move generation
4. **Inline Critical Paths**: Hot path optimization
5. **Lazy Evaluation**: Defer expensive computations until needed

### Algorithm Complexity

- **Time Complexity**: O(b^d) where b is effective branching factor (~15-30) and d is depth
- **Space Complexity**: O(d) for search stack + O(1M) for transposition table
- **Average Nodes Searched**: ~10,000-500,000 per move (depending on position complexity)

## Algorithm Flow

```
findBestMove()
    ↓
tryOpeningBook() → If opening, return book move
    ↓
iterativeDeepening(depth 1..14)
    ↓
    For each depth:
        searchAtDepth()
            ↓
            generateSmart() → Adaptive radius move generation
            ↓
            narrowMovesIfCritical() → Focus on tactical moves if needed
            ↓
            orderMoves() → Sort by tactical importance
            ↓
            For each move:
                minimax() with alpha-beta pruning
                    ↓
                    Check transposition table
                    ↓
                    If depth == 0: quiescence()
                    ↓
                    Try null move pruning
                    ↓
                    PVS with zero-window search
                    ↓
                    Late move reductions
                    ↓
                    Store in transposition table
```

## Testing

The codebase includes comprehensive unit tests for:
- Move generation
- Pattern recognition
- Threat detection
- Transposition table operations
- Search algorithm correctness
- Position evaluation

Run tests with:
```bash
zig build test
```

## Performance Characteristics

- **Search Speed**: ~50,000-200,000 nodes/second (depending on hardware)
- **Typical Search Depth**: 8-12 plies in middlegame
- **Average Response Time**: 100-2000ms per move
- **Memory Usage**: ~50MB (primarily transposition table)

## Implementation Highlights

### History Heuristic

The history heuristic tracks move performance across the search tree, updating with depth-squared bonuses:

```zig
bonus = depth * depth
history[move] += bonus  // Capped at 10,000
```

This creates a learning effect where moves that cause cutoffs are prioritized in sibling positions.

### Zobrist Hashing

Each position receives a unique hash via XOR operations:

```zig
hash = 0
for each occupied square (x, y, player):
    hash ^= zobrist_table[x][y][player]
```

Incremental updates during search enable O(1) hash maintenance.

### Adaptive Move Generation

Search radius expands in early game and contracts as the board fills:

- **Density < 5%**: radius + 2
- **Density 5-15%**: radius + 1
- **Density 15-30%**: base radius
- **Density > 30%**: base radius

This balances tactical awareness with computational efficiency.

## Future Enhancements

Potential areas for improvement:
- Machine learning integration for evaluation tuning
- Endgame tablebase
- Multi-threading for parallel search
- Enhanced opening book
- Deeper tactical pattern recognition
- Neural network-based evaluation

## License

This project was developed as part of the EPITECH curriculum.

---

Built with Zig 🚀
