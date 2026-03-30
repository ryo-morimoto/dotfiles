# TypeScript Domain Modeling Patterns

## Foundational Types

Define these first in every TypeScript domain model:

```typescript
// Result type (TypeScript has no built-in)
type Result<T, E> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };

// Branded type helper (for wrapper/newtype)
type Brand<T, B extends string> = T & { readonly _brand: B };
```

## Conversion Examples

### Product type (A has B and C)

```typescript
type Order = {
  readonly id: OrderId;
  readonly items: readonly OrderItem[];
  readonly createdAt: Date;
};
```

### Sum type (A is B or C)

Use discriminated unions with a `tag`/`kind` field:

```typescript
type PaymentMethod =
  | { readonly kind: "creditCard"; readonly cardNumber: string; readonly expiry: string }
  | { readonly kind: "bankTransfer"; readonly accountId: string }
  | { readonly kind: "cash" };
```

### Wrapper/branded type (constrained primitive)

```typescript
type Email = Brand<string, "Email">;
type OrderId = Brand<string, "OrderId">;
type PortNumber = Brand<number, "PortNumber">;

// Parse function — the ONLY way to create an Email
function parseEmail(s: string): Result<Email, EmailParseError> {
  if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s)) {
    return { ok: true, value: s as Email };
  }
  return { ok: false, error: { kind: "invalidFormat", input: s } };
}

type EmailParseError = { readonly kind: "invalidFormat"; readonly input: string };
```

### Function signature (A transforms to B)

```typescript
type ValidateOrder = (input: RawOrder) => Result<ValidatedOrder, ValidationError>;
type SubmitTask = (input: TaskInput) => Result<PendingTask, TaskSubmissionError>;
```

### Collection (A has many B)

```typescript
type Order = {
  readonly items: readonly OrderItem[]; // use readonly array
};
```

### Optionals — prefer sum types over `?`

```typescript
// Avoid: optional field hides when/why it's absent
type Order = { deliveryDate?: Date };

// Prefer: each state has exactly the fields it needs
type PendingOrder = { readonly items: readonly OrderItem[] };
type ShippedOrder = { readonly items: readonly OrderItem[]; readonly deliveryDate: Date };
```

When a field is genuinely independent of state (e.g., "user may optionally provide a nickname"), `T | null` is acceptable.

### State machines

```typescript
type PendingTask = { readonly phase: "pending"; readonly input: TaskInput };
type RunningTask = { readonly phase: "running"; readonly input: TaskInput; readonly log: readonly string[] };
type CompletedTask = { readonly phase: "completed"; readonly input: TaskInput; readonly result: TaskResult };
type Task = PendingTask | RunningTask | CompletedTask;

// Transitions as functions
type StartTask = (task: PendingTask) => RunningTask;
type CompleteTask = (task: RunningTask, result: TaskResult) => CompletedTask;
```

### Error types

```typescript
type TaskSubmissionError =
  | { readonly kind: "agentNotFound"; readonly agentId: AgentId }
  | { readonly kind: "agentOffline"; readonly agentId: AgentId }
  | { readonly kind: "agentBusy"; readonly agentId: AgentId };
```

## Placeholder Syntax

```typescript
type UnknownPaymentResult = { readonly _placeholder: "UNKNOWN: payment result structure undefined" };
```

## Compilation Check

```bash
tsc --noEmit
```
