# Examples

Run the dynamic example from the repository root:

```bash
pixi run mojo run -I src examples/encode_value.mojo
```

The program builds one object, encodes it with the default options, and
decodes the bytes. The default options write a header, share property names,
and leave shared values and raw binary off.

```mojo
from std.collections import Span

from runtime.doc import SmileDoc
from runtime.options import EncodeOptions
from smile import decode_bytes, encode_doc

var doc = SmileDoc()
var obj = doc.start_object()
doc.add_field(obj, doc._text(String("id")), doc.add_i32(7))
doc.add_field(obj, doc._text(String("name")), doc.add_string(String("smile")))
doc.add_top(obj)
var raw = encode_doc(doc, EncodeOptions())
var back = decode_bytes(Span(raw))
```

`SmileBin` writes the same subset without a `SmileDoc`. `begin` writes the
header with shared names on. The first use of a key stores it in the name
window; a later `key_lit` of that key is a one-byte backref. The value bytes
are written on every call. `SmileCur` reads the bytes, and `decode` accepts
them as well.

```mojo
from wire.direct import SmileBin, SmileCur

var bin = SmileBin()
bin.begin()
bin.start_object()
bin.key_lit("id")
bin.write_i64(7)
bin.end_object()
var raw = bin^.take()
var cur = SmileCur(Span(raw))
cur.open()
cur.start_object()
_ = cur.next_id()
print(cur.read_i64())
```

A generated `Point` has the same three methods as the other gld serializers.
`encoded_len` returns the byte count. `encode_to` appends those bytes to a
list. `decode_from` fills the struct from a span.

```mojo
var point = Point()
point.x = 3
var raw = point.to_bytes(EncodeOptions())
var back = Point()
back.decode_from(Span(raw))
```

`testdata/schema/message.json` shows a nested `$ref`, an array, binary, a big
integer, and a big decimal. `testdata/schema/token.json` is a `oneOf` of
string and integer. The tag field selects the arm.
