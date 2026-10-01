from std.collections import List, Span

from runtime.doc import K_I32, K_I64, SmileDoc
from runtime.eq import smile_eq
from runtime.error import DecodeError
from runtime.options import EncodeOptions
from wire.codec import decode, encode


def fail(msg: String) raises:
    print(msg)
    raise Error(msg)


def must_fail(raw: List[Byte], kind: Int) raises:
    var threw = False
    var got = 0
    try:
        _ = decode(Span(raw), False)
    except e:
        threw = True
        got = e.kind
    if not threw or got != kind:
        fail("expected kind " + String(kind))


def byte_list(hexs: String) -> List[Byte]:
    var raw = hexs.as_bytes()
    var out = List[Byte]()
    var i = 0
    while i + 1 < len(raw):
        var hi = Int(raw[i])
        var lo = Int(raw[i + 1])
        if hi >= 97:
            hi -= 87
        else:
            hi -= 48
        if lo >= 97:
            lo -= 87
        else:
            lo -= 48
        out.append(Byte((hi << 4) | lo))
        i += 2
    return out^


def main() raises:
    var empty = List[Byte]()
    var doc = decode(Span(empty), False)
    if len(doc.top) != 0:
        fail("empty")

    must_fail(byte_list("3a290a1021"), DecodeError.KIND_VERSION)
    must_fail(byte_list("fd8100"), DecodeError.KIND_TYPE)
    must_fail(byte_list("2100"), DecodeError.KIND_SYNTAX)
    must_fail(byte_list("01"), DecodeError.KIND_SHARED)

    var opt = EncodeOptions(False, True, False, False, False)
    doc = SmileDoc()
    doc.add_top(doc.add_i32(1))
    doc.add_top(doc.add_i64(1))
    var raw = encode(doc, opt)
    var back = decode(Span(raw), False)
    if smile_eq(back, back.top[0], back, back.top[1]):
        fail("widths")
    if back.nodes[back.top[0]].kind != K_I32 or back.nodes[back.top[1]].kind != K_I64:
        fail("class")

    var nest = SmileDoc()
    var cur = nest.start_array()
    nest.add_top(cur)
    var d = 0
    while d < 8:
        var inner = nest.start_array()
        nest.add_elem(cur, inner)
        cur = inner
        d += 1
    raw = encode(nest, opt)
    back = decode(Span(raw), False)
    if len(back.top) != 1:
        fail("nest")

    var share = EncodeOptions(True, True, True, False, False)
    doc = SmileDoc()
    var n = 0
    while n < 32:
        doc.add_top(doc.add_string(String("v") + String(n)))
        n += 1
    doc.add_top(doc.add_string(String("v31")))
    raw = encode(doc, share)
    back = decode(Span(raw), False)
    if len(back.top) != 33:
        fail("share count")
    if back.texts[back.nodes[back.top[32]].a] != "v31":
        fail("share ref")

    var strict_bad = byte_list("287b7c000000")
    var strict_threw = False
    var strict_kind = 0
    try:
        _ = decode(Span(strict_bad), True)
    except e:
        strict_threw = True
        strict_kind = e.kind
    if not strict_threw or strict_kind != DecodeError.KIND_SYNTAX:
        fail("strict float")
    _ = decode(Span(strict_bad), False)
    print("edges ok")
