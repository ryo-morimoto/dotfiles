# prelude/ 推奨実装

プロジェクトに既存の prelude や FP ライブラリ（Effect, neverthrow 等）がある場合はそちらを優先すること。
以下はゼロから始める場合の推奨テンプレート。

## result.ts

```typescript
export type Result<T, E> =
  | { readonly ok: true;  readonly value: T }
  | { readonly ok: false; readonly error: E };

export const ok  = <T>(value: T): Result<T, never> => ({ ok: true,  value });
export const err = <E>(error: E): Result<never, E> => ({ ok: false, error });

export const map = <T, U, E>(
  r: Result<T, E>, f: (v: T) => U
): Result<U, E> => r.ok ? ok(f(r.value)) : r;

export const andThen = <T, U, E>(
  r: Result<T, E>, f: (v: T) => Result<U, E>
): Result<U, E> => r.ok ? f(r.value) : r;

export const mapError = <T, E, F>(
  r: Result<T, E>, f: (e: E) => F
): Result<T, F> => r.ok ? r : err(f(r.error));
```

## option.ts

```typescript
export type Option<T> =
  | { readonly some: true;  readonly value: T }
  | { readonly some: false };

export const some        = <T>(value: T): Option<T> => ({ some: true, value });
export const none        = (): Option<never>         => ({ some: false });
export const fromNullable = <T>(v: T | null | undefined): Option<T> =>
  v != null ? some(v) : none();
export const map         = <T, U>(o: Option<T>, f: (v: T) => U): Option<U> =>
  o.some ? some(f(o.value)) : none();
export const getOrElse   = <T>(o: Option<T>, fallback: T): T =>
  o.some ? o.value : fallback;
```

## brand.ts

```typescript
declare const __brand: unique symbol;
export type Brand<T, B> = T & { readonly [__brand]: B };
```

## pattern.ts

```typescript
import type { Result } from "./result";
import type { Option } from "./option";

export const absurd = (x: never): never => {
  throw new Error(`Unreachable: ${JSON.stringify(x)}`);
};

export const match = <T extends { readonly _tag: string }, R>(
  value: T,
  cases: { readonly [K in T["_tag"]]: (v: Extract<T, { _tag: K }>) => R }
): R => {
  const handler = cases[value._tag as T["_tag"]];
  return handler(value as Extract<T, { _tag: typeof value._tag }>);
};

export const matchResult = <T, E, R>(
  result: Result<T, E>,
  cases: { readonly ok: (v: T) => R; readonly err: (e: E) => R }
): R => result.ok ? cases.ok(result.value) : cases.err(result.error);

export const matchOption = <T, R>(
  option: Option<T>,
  cases: { readonly some: (v: T) => R; readonly none: () => R }
): R => option.some ? cases.some(option.value) : cases.none();
```
