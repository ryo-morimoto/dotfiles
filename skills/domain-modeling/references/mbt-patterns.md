# MoonBit Domain Modeling Patterns

## Foundational Types

MoonBit has built-in `Result[T, E]` and `T?` (Option). No need to define these.

```moonbit
// Built-in:
// Result[T, E] = Ok(T) | Err(E)
// T? = Some(T) | None
```

## Conversion Examples

### Product type (A has B and C)

```moonbit
struct Order {
  id : OrderId
  items : Array[OrderItem]
  created_at : String
}
```

### Sum type (A is B or C)

```moonbit
enum PaymentMethod {
  CreditCard(card_number~ : String, expiry~ : String)
  BankTransfer(account_id~ : String)
  Cash
}
```

### Wrapper/newtype (constrained primitive)

MoonBit uses the `struct Name(Inner)` newtype pattern:

```moonbit
struct Email(String)
struct OrderId(String)
struct PortNumber(Int)

// Parse function — the ONLY way to create an Email
fn Email::parse(s : String) -> Result[Email, EmailParseError] {
  if s.contains("@") {
    Ok(Email(s))
  } else {
    Err(InvalidFormat(s))
  }
}

enum EmailParseError {
  InvalidFormat(String)
}
```

Access the inner value with `.0`:

```moonbit
let email = Email("user@example.com")
let raw : String = email.0
```

### Function signature (A transforms to B)

```moonbit
fn validate_order(input : RawOrder) -> Result[ValidatedOrder, ValidationError] {
  ...
}

fn submit_task(input : TaskInput) -> Result[PendingTask, TaskSubmissionError] {
  ...
}
```

### Collection (A has many B)

```moonbit
struct Order {
  items : Array[OrderItem]
}
```

### Optionals — prefer enum variants over Option fields

```moonbit
// Avoid: Option field hides when/why it's absent
struct Order {
  delivery_date : String?
}

// Prefer: each state has exactly the fields it needs
struct PendingOrder {
  items : Array[OrderItem]
}

struct ShippedOrder {
  items : Array[OrderItem]
  delivery_date : String
  tracking_id : TrackingId
}
```

When a field is genuinely independent of state, `T?` is acceptable.

### State machines

```moonbit
enum Task {
  Pending(input~ : TaskInput)
  Running(input~ : TaskInput, log~ : Array[String])
  Completed(input~ : TaskInput, result~ : TaskResult)
}

// Transitions as functions
fn start_task(task : Task) -> Task {
  match task {
    Pending(input~) => Running(input~, log=Array::new())
    _ => abort("start_task: expected Pending")
  }
}

fn complete_task(task : Task, result : TaskResult) -> Task {
  match task {
    Running(input~, ..) => Completed(input~, result~=result)
    _ => abort("complete_task: expected Running")
  }
}
```

Alternative: use separate structs + a top-level enum for stronger compile-time guarantees:

```moonbit
struct PendingTask {
  input : TaskInput
}

struct RunningTask {
  input : TaskInput
  log : Array[String]
}

struct CompletedTask {
  input : TaskInput
  result : TaskResult
}

enum Task {
  Pending(PendingTask)
  Running(RunningTask)
  Completed(CompletedTask)
}

fn start(task : PendingTask) -> RunningTask {
  { input: task.input, log: Array::new() }
}

fn complete(task : RunningTask, result : TaskResult) -> CompletedTask {
  { input: task.input, result }
}
```

### Error types

```moonbit
enum TaskSubmissionError {
  AgentNotFound(AgentId)
  AgentOffline(AgentId)
  AgentBusy(AgentId)
}
```

MoonBit also supports error types with `type!`:

```moonbit
type! TaskError {
  NotFound(String)
  Offline(String)
  Busy(String)
}

// Usage with raise/try
fn submit(id : AgentId) -> Unit!TaskError {
  raise TaskError::NotFound(id.0)
}
```

## Placeholder Syntax

```moonbit
struct UnknownPaymentResult {
  _placeholder : String  // "UNKNOWN: payment result structure undefined"
}
```

Or use an enum variant:

```moonbit
enum PaymentResult {
  Unknown  // UNKNOWN: payment result structure undefined
  // TODO: define actual variants after API spec confirmed
}
```

## Compilation Check

```bash
moon check
```
