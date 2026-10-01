from std.collections import List

from runtime.doc import K_ARRAY, K_I32, K_OBJECT, K_STRING, SmileDoc
from runtime.eq import docs_eq
from runtime.options import EncodeOptions
from wire.codec import decode, encode


def fail(msg: String) raises:
    print(msg)
    raise Error(msg)


def hex_of(raw: List[Byte]) -> String:
    var digits = "0123456789abcdef"
    var db = digits.as_bytes()
    var out = String()
    var i = 0
    while i < len(raw):
        var b = Int(raw[i])
        out = out + chr(Int(db[b >> 4]))
        out = out + chr(Int(db[b & 0xF]))
        i += 1
    return out


def expect(raw: List[Byte], want: String) raises:
    var got = hex_of(raw)
    if got != want:
        fail(got + " != " + want)


def no_header() -> EncodeOptions:
    return EncodeOptions(False, True, False, False, False)


def round(doc: SmileDoc, options: EncodeOptions) raises:
    var raw = encode(doc, options)
    var back = decode(Span(raw), False)
    if not docs_eq(doc, back):
        fail("round " + hex_of(raw))


def main() raises:
    var opt = no_header()
    var doc = SmileDoc()
    doc.add_top(doc.add_null())
    expect(encode(doc, opt), "21")
    round(doc, opt)

    doc = SmileDoc()
    doc.add_top(doc.add_bool(True))
    doc.add_top(doc.add_bool(False))
    expect(encode(doc, opt), "2322")

    doc = SmileDoc()
    doc.add_top(doc.add_string(String()))
    expect(encode(doc, opt), "20")

    doc = SmileDoc()
    doc.add_top(doc.add_i32(0))
    doc.add_top(doc.add_i32(1))
    doc.add_top(doc.add_i32(-1))
    doc.add_top(doc.add_i32(15))
    doc.add_top(doc.add_i32(-16))
    expect(encode(doc, opt), "c0c2c1dedf")
    round(doc, opt)

    doc = SmileDoc()
    doc.add_top(doc.add_string(String("a")))
    expect(encode(doc, opt), "4061")

    doc = SmileDoc()
    var obj = doc.start_object()
    doc.add_field(obj, doc._text(String("a")), doc.add_i32(1))
    doc.add_field(obj, doc._text(String("a")), doc.add_i32(1))
    doc.add_top(obj)
    expect(encode(doc, opt), "fa8061c240c2fb")
    round(doc, opt)

    doc = SmileDoc()
    var arr = doc.start_array()
    doc.add_elem(arr, doc.add_i32(1))
    doc.add_elem(arr, doc.add_bool(True))
    doc.add_elem(arr, doc.add_null())
    doc.add_top(arr)
    expect(encode(doc, opt), "f8c22321f9")
    var back = decode(Span(encode(doc, opt)), False)
    if back.nodes[back.top[0]].kind != K_ARRAY:
        fail("array kind")
    if back.nodes[back.top[0]].nchild != 3:
        fail("array n")

    var with_h = EncodeOptions(True, True, False, False, False)
    doc = SmileDoc()
    doc.add_top(doc.add_null())
    expect(encode(doc, with_h), "3a290a0121")
    round(doc, with_h)

    var share_v = EncodeOptions(True, True, True, False, True)
    doc = SmileDoc()
    doc.add_top(doc.add_string(String("a")))
    doc.add_top(doc.add_string(String("a")))
    expect(encode(doc, share_v), "3a290a03406101ff")
    round(doc, share_v)

    doc = SmileDoc()
    obj = doc.start_object()
    doc.add_field(obj, doc._text(String("a")), doc.add_string(String("hi")))
    doc.add_top(obj)
    round(doc, opt)
    var n = doc.nodes[doc.top[0]]
    if n.kind != K_OBJECT:
        fail("obj")
    _ = K_I32
    _ = K_STRING
    print("ok")
