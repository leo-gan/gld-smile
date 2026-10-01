# Why Smile

Smile is a binary encoding of the JSON data model. A document is a sequence of
tokens. Each token is one byte plus the payload that token requires. The usual
MIME type used by existing tools is `application/x-jackson-smile`.

This library implements Smile specification 1.0.7. A buffer may hold one value
or several root values. An optional 4-byte header names the version and three
flags. The end byte `0xFF` closes the buffer.

## Header flags

| Bit | Mask | Meaning when the header is absent |
| --- | --- | --- |
| Shared property names | `0x01` | On. The decoder keeps a window of names. |
| Shared string values | `0x02` | Off. A back-reference is an error. |
| Raw binary | `0x04` | Off. Only 7-bit binary is legal. |

The version nibble is 0. Bit 3 is reserved. The encoder writes it as 0. A
decoder ignores it unless strict mode is on.

## Values that stay distinct

JSON has one number type. Smile keeps several, and this library stores them
separately.

| Smile token | Stored as |
| --- | --- |
| Small integer or 32-bit zigzag | int32 |
| 64-bit zigzag, at least five data bytes on encode | int64 |
| Big integer | two's-complement bytes |
| 32-bit float | float32 bits, including −0, inf, and NaN |
| 64-bit float | float64 bits |
| Big decimal | scale plus unscaled integer bytes |

A shared string reference becomes the same text as the earlier short string.
Field order is kept. Duplicate names are kept. `1` and `1.0` are not the same
value, because one is an integer and the other is a decimal or a float.

## What the encoder promises

`EncodeOptions` chooses the header, shared names, shared values, raw binary,
and the end marker. Two encodes of the same document with the same options
produce the same bytes. The bytes may differ from a previous encoder when that
encoder used a longer integer, a different share window, or a 1 in an unused
bit. This encoder writes unused bits as 0.

Shared string values and raw binary are emitted only when the header is
written. Without a header, the specification requires those features to be
off, so a document that used them could not be read back.
