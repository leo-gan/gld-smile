# Techniques

The in-memory value is an arena, not a recursive struct. `SmileDoc` stores
nodes, text, byte slices, float64 bit patterns, and edges. An array or object
node points at a contiguous run of edges. If a later sibling would break that
run, the parent edges are copied to the end of the edge list. That keeps
random access O(1) after the value is built.

## Integers and floats

Small integers use one byte, `0xC0` plus a 5-bit zigzag. Larger int32 values
use token `0x24` and a short zigzag VInt. int64 values use token `0x25` and at
least five VInt bytes, which is what a Smile 1.0 decoder requires for that
token. Floats are big-endian IEEE bits packed into 7-bit bytes. The first
float32 byte holds four data bits. The first float64 byte holds one. Unused
bits are written as 0 and ignored on decode unless strict mode is on.

## Safe binary

Big integers, big decimals, and 7-bit binary carry a raw length, then the
payload with seven data bits per byte. The length is the raw byte count, not
the encoded count. The last encoded byte holds its data in the low bits. Raw
binary, token `0xFD`, is used only when the header says it may appear. Its
bytes are copied unchanged, so they may include `0xFF`.

## Share windows

Names and values have separate windows of 1024 strings. A new short string is
appended. When the window is full, it is cleared and the next string is index
0. A reference does not append another copy. The first 64 texts in a document
are interned, so a repeated key compares as an integer index before any string
scan. A miss still compares text, which keeps two copies of the same string
shareable after that cap. Null, bool, integer, and short ASCII values are
encoded and decoded in one loop, so that index check sits next to the byte it
emits. A float, a big number, or a long string still uses the general codec,
and a document can switch at the first such value.

Value indexes 0 through 30 use the one-byte form `0x01` through `0x1F`. Index
31 and above use the two-byte form. Name indexes 0 through 63 use `0x40`
through `0x7F`. The encoder never emits a reference whose low byte is `0xFE`
or `0xFF`. The slot still exists, so later indexes stay aligned with a
decoder that stored every short string. Long strings are not added to the
value window. Long names are added to the name window. The empty string is a
constant token and is not shared.

## Limits

Nesting stops at 1024 containers. One binary, string, or big-integer payload
stops at 64 MiB. A corrupt length cannot allocate up to the specification's
theoretical 2 GiB. The dynamic API still accepts every token shape inside
that bound.
