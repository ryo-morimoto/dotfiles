---
name: mermaid-validator
description: Use when creating Mermaid diagrams (flowcharts, sequence, class, state, ER diagrams) or fixing Mermaid syntax errors and rendering issues. Validates diagrams using mermaid-ast (pure static analysis, no browser required).
---

# Mermaid Validator

Validate Mermaid diagram syntax using mermaid-ast (pure static analysis, no browser required).

## Validation Process

### Validate file
```bash
node ${CLAUDE_PLUGIN_ROOT}/dist/validate.mjs /path/to/diagram.mmd
```

### Validate via stdin
```bash
echo 'flowchart TD
    A --> B' | node ${CLAUDE_PLUGIN_ROOT}/dist/validate.mjs
```

### Output
- **Success**: `✅ Valid - [diagram type]`
- **Failure**: `❌ Invalid` with error message

### Common issues
- Arrow syntax (`-->` not `->` in flowcharts)
- Special characters in node IDs (wrap in quotes)
- Missing `end` keywords for blocks
- Keyword spelling (e.g., `sequenceDiagram` not `sequence`)

## Supported Diagram Types

| Type | Keyword | Use Case |
|------|---------|----------|
| Flowchart | `flowchart TD` | Process flows, decision trees |
| Sequence | `sequenceDiagram` | API interactions, message flows |
| Class | `classDiagram` | OOP structures, relationships |
| State | `stateDiagram-v2` | State machines, transitions |
| ER | `erDiagram` | Database schemas |
| Gantt | `gantt` | Project schedules |
| Pie | `pie` | Data distribution |
| Mindmap | `mindmap` | Hierarchical ideas |
| Timeline | `timeline` | Chronological events |
| Git Graph | `gitGraph` | Git branch visualization |

See [references/REFERENCE.md](references/REFERENCE.md) for detailed syntax of each diagram type.

## Quick Syntax Reference

### Flowchart

```mermaid
flowchart TD
    A[Rectangle] --> B{Decision}
    B -->|Yes| C[Process]
    B -->|No| D[End]
```

Directions: `TD` (top-down), `LR` (left-right), `BT`, `RL`

### Sequence Diagram

```mermaid
sequenceDiagram
    participant A as Client
    participant B as Server
    A->>B: Request
    B-->>A: Response
```

### Class Diagram

```mermaid
classDiagram
    class Animal {
        +String name
        +makeSound() void
    }
    Animal <|-- Dog
```

### State Diagram

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Running: start
    Running --> [*]: stop
```

### ER Diagram

```mermaid
erDiagram
    USER ||--o{ ORDER : places
    USER {
        int id PK
        string name
    }
```

## Common Errors

### Parse error
- Check arrow format (`-->` not `->`)
- Verify keyword spelling

### Lexical error
- Wrap text with special chars in quotes: `A["Value: 100"]`

### Unknown diagram type
- Use exact keywords: `flowchart`, `sequenceDiagram`, `classDiagram`
- Supported: flowchart, sequence, class, state, erDiagram, gantt, gitGraph, mindmap, journey, kanban, pie, timeline, sankey, quadrant, requirement, xychart, c4, block

## Output Format

### Success
```
✅ Valid - flowchart
```

### Error
```
❌ Invalid
Failed to parse flowchart: Parse error on line 2:
flowchart TD    A -> B
------------------^
Expecting 'SEMI', 'NEWLINE', 'EOF', 'AMP', 'START_LINK', 'LINK', 'LINK_ID', got 'MINUS'
```

The error shows:
- Diagram type that failed
- Line number
- Visual pointer to error location
- Expected vs actual tokens
