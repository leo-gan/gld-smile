# mojo-smile

mojo-smile is a from-scratch Smile 1.0.7 library for Mojo 1.1.0. The runtime
and the generator do not link a C, C++, or Rust Smile codec. Jackson is used
only as a local test oracle.

## Data model

A `SmileDoc` is an arena of nodes. The kinds are null, bool, int32, int64,
big integer, float32, float64, big decimal, string, binary, array, and
object. int32 and int64 stay distinct. Float widths stay distinct, including
the sign of zero. A big decimal keeps its scale and its unscaled
two's-complement bytes. Objects keep field order and duplicate names.

## Wire

The reader accepts a missing header. In that case shared names are on, shared
values are off, and raw binary is off. A new header in a top-level stream
resets both share windows and the flags. `0xFF` ends the stream. Bytes after
it are an error.

The writer follows `EncodeOptions`. Shared values and raw binary are forced
off when the header is omitted, because a headerless decoder would reject
them. Unused bits are 0. int64 uses at least five VInt data bytes.

Back-references use Jackson's index rules. Value index `i < 31` is the byte
`i + 1`. Name index `i < 64` is the byte `0x40 + i`. Indexes whose low byte
is `0xFE` or `0xFF` are stored and never referenced.

## Schema

`gld-smilegen-mojo` reads a JSON Schema subset: `type`, `properties`,
`required`, `items`, `$ref`, `$defs`, `definitions`, `enum`, `const`,
`oneOf`, and `anyOf`. The extra type names are `binary`, `biginteger`, and
`bigdecimal`. Generated structs expose `encoded_len`, `encode_to`, and
`decode_from`. A cycle is a schema error.

## Limits

Depth is 1024. One payload is at most 64 MiB. Those caps keep a corrupt
length from allocating the specification's theoretical 2 GiB.

## Package

The conda package is `mojo-smile`. The import is `smile`. The repository is
`leo-gan/gld-smile`. `.env` stays local and is gitignored.
