# Test data

The byte vectors in `tests/test_oracle.mojo` were produced by Jackson
`jackson-dataformat-smile` 2.13.5. The Mojo encoder matches those bytes for
integers, positive floats, strings, 7-bit binary, raw binary, big integers,
big decimals, objects, and shared values. Negative floats from Jackson may
have 1-bits in unused positions. This decoder accepts them. This encoder
writes those bits as 0, so a second encode is shorter in the unused bits and
still decodes to the same float.

`tests/test_basic.mojo` checks the smallest tokens: null, booleans, the empty
string, the small-integer range, a repeated field name, and a shared value
with a header. `tests/test_edges.mojo` checks a bad version, raw binary
without the header flag, a shared reference with no window, distinct int32
and int64 values, and strict unused bits. `tests/test_num.mojo` checks the
two's-complement decimal conversion used by big integers and big decimals.
`tests/test_gen.mojo` round-trips the generated `Point`, `Message`, and
`Token` structs.

## Schemas

| File | What it checks |
| --- | --- |
| `testdata/schema/point.json` | An object, an optional integer, and a string enum. |
| `testdata/schema/message.json` | `$ref`, an integer array, binary, big integer, big decimal, boolean, and an optional number. |
| `testdata/schema/token.json` | `oneOf` string or integer. |

`pixi run check-generated` must match the files in `tests/generated/`. Those
files are committed so a reader can see the generator output without running
it.
