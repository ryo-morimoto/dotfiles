# Mermaid Syntax Reference

Complete syntax reference for all supported diagram types.

## Flowchart

### Basic Structure

```mermaid
flowchart TD
    A[Start] --> B[Process]
    B --> C[End]
```

### Direction

| Code | Direction |
|------|-----------|
| `TD` / `TB` | Top to Bottom |
| `BT` | Bottom to Top |
| `LR` | Left to Right |
| `RL` | Right to Left |

### Node Shapes

| Syntax | Shape |
|--------|-------|
| `[text]` | Rectangle |
| `(text)` | Rounded rectangle |
| `{text}` | Diamond (decision) |
| `((text))` | Circle |
| `>text]` | Flag |
| `[[text]]` | Subroutine |
| `[(text)]` | Cylinder (database) |
| `{{text}}` | Hexagon |
| `[/text/]` | Parallelogram |
| `[\text\]` | Parallelogram alt |

### Arrow Types

| Syntax | Description |
|--------|-------------|
| `-->` | Arrow |
| `---` | Line (no arrow) |
| `-.->` | Dotted arrow |
| `==>` | Thick arrow |
| `--text-->` | Arrow with label |
| `-->｜text｜` | Alternative label syntax |
| `~~~` | Invisible link |

### Subgraphs

```mermaid
flowchart TD
    subgraph Group1[Title]
        A --> B
    end
    subgraph Group2
        C --> D
    end
    B --> C
```

### Styling

```mermaid
flowchart TD
    A[Start]:::green --> B[End]:::red
    classDef green fill:#9f6,stroke:#333
    classDef red fill:#f96,stroke:#333
```

---

## Sequence Diagram

### Basic Structure

```mermaid
sequenceDiagram
    participant A as Client
    participant B as Server
    A->>B: Request
    B-->>A: Response
```

### Arrow Types

| Syntax | Description |
|--------|-------------|
| `->>` | Solid arrow |
| `-->>` | Dotted arrow |
| `-x` | Solid with X (async) |
| `--x` | Dotted with X |
| `-)` | Solid open arrow |
| `--)` | Dotted open arrow |

### Activation

```mermaid
sequenceDiagram
    A->>B: Request
    activate B
    B-->>A: Response
    deactivate B
```

Or shorthand:
```mermaid
sequenceDiagram
    A->>+B: Request
    B-->>-A: Response
```

### Notes

```mermaid
sequenceDiagram
    A->>B: Message
    Note over A,B: Note spanning both
    Note left of A: Left note
    Note right of B: Right note
```

### Control Flow

```mermaid
sequenceDiagram
    A->>B: Request

    loop Every minute
        B->>B: Health check
    end

    alt Success
        B-->>A: 200 OK
    else Failure
        B-->>A: 500 Error
    end

    opt Optional step
        A->>B: Retry
    end

    par Parallel
        A->>B: Request 1
    and
        A->>C: Request 2
    end
```

### Background Highlighting

```mermaid
sequenceDiagram
    rect rgb(200, 220, 255)
        A->>B: In highlighted region
    end
```

### Auto-numbering

```mermaid
sequenceDiagram
    autonumber
    A->>B: First
    B->>C: Second
```

---

## Class Diagram

### Basic Structure

```mermaid
classDiagram
    class Animal {
        +String name
        +int age
        +makeSound() void
    }
```

### Visibility

| Symbol | Visibility |
|--------|------------|
| `+` | Public |
| `-` | Private |
| `#` | Protected |
| `~` | Package/Internal |

### Relationships

| Syntax | Relationship |
|--------|--------------|
| `<｜--` | Inheritance |
| `*--` | Composition |
| `o--` | Aggregation |
| `-->` | Association |
| `--` | Link (solid) |
| `..>` | Dependency |
| `..｜>` | Implementation |
| `..` | Link (dashed) |

### Cardinality

```mermaid
classDiagram
    Customer "1" --> "*" Order
    Order "1" --> "1..*" LineItem
```

Labels: `"1"`, `"0..1"`, `"1..*"`, `"*"`, `"n"`

### Annotations

```mermaid
classDiagram
    class Shape {
        <<interface>>
        +draw() void
    }
    class AbstractShape {
        <<abstract>>
    }
    class Utility {
        <<service>>
    }
```

---

## State Diagram

### Basic Structure

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Running: start
    Running --> Idle: stop
    Running --> [*]: terminate
```

### Composite States

```mermaid
stateDiagram-v2
    state Active {
        [*] --> Running
        Running --> Paused: pause
        Paused --> Running: resume
    }
    [*] --> Active
    Active --> [*]
```

### Concurrent States

```mermaid
stateDiagram-v2
    state Active {
        [*] --> Running
        --
        [*] --> Monitoring
    }
```

### Special States

| Syntax | State |
|--------|-------|
| `[*]` | Start/End |
| `<<fork>>` | Fork |
| `<<join>>` | Join |
| `<<choice>>` | Choice |

### Notes

```mermaid
stateDiagram-v2
    State1: Description
    note right of State1: This is a note
```

---

## ER Diagram

### Basic Structure

```mermaid
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
```

### Cardinality

| Left | Right | Meaning |
|------|-------|---------|
| `｜｜` | `｜｜` | Exactly one |
| `｜｜` | `o｜` | Zero or one |
| `｜｜` | `}｜` | One or more |
| `｜｜` | `}o` | Zero or more |

### Attributes

```mermaid
erDiagram
    USER {
        int id PK
        string name
        string email UK
        int department_id FK
        datetime created_at
    }
```

Markers: `PK` (Primary Key), `FK` (Foreign Key), `UK` (Unique Key)

---

## Gantt Chart

### Basic Structure

```mermaid
gantt
    title Project Schedule
    dateFormat YYYY-MM-DD

    section Planning
    Requirements    :a1, 2024-01-01, 7d
    Design          :a2, after a1, 5d

    section Development
    Backend         :b1, after a2, 14d
    Frontend        :b2, after a2, 14d

    section Testing
    Integration     :c1, after b1 b2, 7d
```

### Task Types

| Syntax | Type |
|--------|------|
| `:active` | Active task |
| `:done` | Completed task |
| `:crit` | Critical path |
| `:milestone` | Milestone |

Example:
```mermaid
gantt
    Planning    :done, a1, 2024-01-01, 7d
    Development :active, a2, after a1, 14d
    Review      :crit, a3, after a2, 3d
    Launch      :milestone, m1, after a3, 0d
```

---

## Pie Chart

### Basic Structure

```mermaid
pie showData
    title Browser Market Share
    "Chrome" : 65
    "Safari" : 19
    "Firefox" : 10
    "Other" : 6
```

Options:
- `showData`: Display percentages
- `title`: Chart title

---

## Best Practices

1. **Use meaningful IDs**: `userService` not `A`
2. **Keep diagrams focused**: One concept per diagram
3. **Use consistent styling**: Same direction and arrow types
4. **Quote special characters**: `["Value: 100"]`
5. **Validate incrementally**: Add sections one at a time
6. **Use subgraphs/states**: Improve readability of complex diagrams
