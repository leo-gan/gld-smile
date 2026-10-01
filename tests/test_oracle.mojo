from std.collections import List, Span

from runtime.doc import SmileDoc
from runtime.eq import docs_eq
from runtime.options import EncodeOptions
from runtime.utf8 import string_from_span
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


def from_hex(text: String) -> List[Byte]:
    var raw = text.as_bytes()
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


def check_enc(doc: SmileDoc, options: EncodeOptions, want: String) raises:
    var raw = encode(doc, options)
    var got = hex_of(raw)
    if got != want:
        fail(got + " != " + want)
    var back = decode(Span(raw), False)
    if not docs_eq(doc, back):
        fail("round " + want)


def check_dec(doc: SmileDoc, wire: String) raises:
    var back = decode(Span(from_hex(wire)), False)
    if not docs_eq(doc, back):
        fail("dec " + wire)


def one_byte(b: Int) -> List[Byte]:
    var raw = List[Byte]()
    raw.append(Byte(b))
    return raw^


def bare() -> EncodeOptions:
    return EncodeOptions(False, True, False, False, False)


def main() raises:
    var opt = bare()
    var doc = SmileDoc()
    doc.add_top(doc.add_i32(16))
    check_enc(doc, opt, "24a0")

    doc = SmileDoc()
    doc.add_top(doc.add_i32(1000))
    check_enc(doc, opt, "241f90")

    doc = SmileDoc()
    doc.add_top(doc.add_i32(-2147483648))
    check_enc(doc, opt, "241f7f7f7fbf")

    doc = SmileDoc()
    doc.add_top(doc.add_i32(2147483647))
    check_enc(doc, opt, "241f7f7f7fbe")

    doc = SmileDoc()
    doc.add_top(doc.add_i64(Int(1) << 40))
    check_enc(doc, opt, "2501000000000080")

    doc = SmileDoc()
    doc.add_top(doc.add_i64(Int(UInt64(1) << 63)))
    check_enc(doc, opt, "25037f7f7f7f7f7f7f7fbf")

    doc = SmileDoc()
    doc.add_top(doc.add_f32_bits(0x3F800000))
    check_enc(doc, opt, "28037c000000")

    doc = SmileDoc()
    doc.add_top(doc.add_f32_bits(Int(0xBF800000)))
    check_enc(doc, opt, "280b7c000000")
    check_dec(doc, "287b7c000000")

    doc = SmileDoc()
    doc.add_top(doc.add_f32_bits(Int(0x80000000)))
    check_enc(doc, opt, "280800000000")
    check_dec(doc, "287800000000")

    doc = SmileDoc()
    doc.add_top(doc.add_f64_bits(0x3FF0000000000000))
    check_enc(doc, opt, "29003f7800000000000000")

    doc = SmileDoc()
    doc.add_top(doc.add_f64_bits(0x8000000000000000))
    check_enc(doc, opt, "2901000000000000000000")

    doc = SmileDoc()
    doc.add_top(doc.add_f32_bits(0x7FC00000))
    check_enc(doc, opt, "28077e000000")
    check_dec(doc, "28077e000000")

    doc = SmileDoc()
    doc.add_top(doc.add_f32_bits(0x7F800000))
    check_enc(doc, opt, "28077c000000")

    doc = SmileDoc()
    doc.add_top(doc.add_f64_bits(0x7FF8000000000000))
    check_enc(doc, opt, "29007f7c00000000000000")

    var chars = String()
    var n = 0
    while n < 64:
        chars = chars + "a"
        n += 1
    doc = SmileDoc()
    doc.add_top(doc.add_string(chars))
    var raw = encode(doc, opt)
    if len(raw) != 65 or Int(raw[0]) != 0x7F:
        fail("str64 " + hex_of(raw))
    check_enc(doc, opt, hex_of(raw))

    chars = String()
    n = 0
    while n < 65:
        chars = chars + "b"
        n += 1
    doc = SmileDoc()
    doc.add_top(doc.add_string(chars))
    raw = encode(doc, opt)
    if Int(raw[0]) != 0xE0 or Int(raw[len(raw) - 1]) != 0xFC or len(raw) != 67:
        fail("str65 " + String(len(raw)))
    var back = decode(Span(raw), False)
    if not docs_eq(doc, back):
        fail("str65 round")

    var ub = List[Byte]()
    ub.append(Byte(0xC3))
    ub.append(Byte(0xA9))
    doc = SmileDoc()
    doc.add_top(doc.add_string(string_from_span(Span(ub), 0)))
    check_enc(doc, opt, "80c3a9")

    var bin = List[Byte]()
    bin.append(Byte(0x01))
    bin.append(Byte(0xFF))
    bin.append(Byte(0x00))
    doc = SmileDoc()
    doc.add_top(doc.add_binary(bin^))
    check_enc(doc, opt, "e883007f6000")

    bin = List[Byte]()
    bin.append(Byte(0x01))
    bin.append(Byte(0xFF))
    doc = SmileDoc()
    doc.add_top(doc.add_binary(bin^))
    var raw_opt = EncodeOptions(True, True, False, True, False)
    check_enc(doc, raw_opt, "3a290a05fd8201ff")

    doc = SmileDoc()
    doc.add_top(doc.add_bigint(one_byte(0)))
    check_enc(doc, opt, "26810000")
    doc = SmileDoc()
    doc.add_top(doc.add_bigint(one_byte(1)))
    check_enc(doc, opt, "26810001")
    doc = SmileDoc()
    doc.add_top(doc.add_bigint(one_byte(0xFF)))
    check_enc(doc, opt, "26817f01")

    var mag = one_byte(100)
    doc = SmileDoc()
    doc.add_top(doc.add_decimal(2, mag^))
    check_enc(doc, opt, "2a84813200")
    mag = one_byte(0xF6)
    doc = SmileDoc()
    doc.add_top(doc.add_decimal(1, mag^))
    check_enc(doc, opt, "2a82817b00")

    doc = SmileDoc()
    var obj = doc.start_object()
    doc.add_field(obj, doc._text(String("id")), doc.add_i32(1))
    doc.add_field(obj, doc._text(String("name")), doc.add_string(String("hi")))
    doc.add_top(obj)
    check_enc(doc, opt, "fa816964c2836e616d65416869fb")

    doc = SmileDoc()
    obj = doc.start_object()
    var arr = doc.start_array()
    doc.add_elem(arr, doc.add_i32(1))
    doc.add_elem(arr, doc.add_bool(True))
    doc.add_field(obj, doc._text(String("a")), arr)
    doc.add_top(obj)
    check_enc(doc, opt, "fa8061f8c223f9fb")

    doc = SmileDoc()
    doc.add_top(doc.start_object())
    check_enc(doc, opt, "fafb")
    doc = SmileDoc()
    doc.add_top(doc.start_array())
    check_enc(doc, opt, "f8f9")

    doc = SmileDoc()
    obj = doc.start_object()
    doc.add_field(obj, doc._text(String("a")), doc.add_i32(1))
    doc.add_field(obj, doc._text(String("a")), doc.add_i32(2))
    doc.add_top(obj)
    check_enc(doc, opt, "fa8061c240c4fb")

    var hello = EncodeOptions(True, True, True, False, True)
    doc = SmileDoc()
    doc.add_top(doc.add_string(String("hello")))
    doc.add_top(doc.add_string(String("hello")))
    check_enc(doc, hello, "3a290a034468656c6c6f01ff")

    var longn = String()
    n = 0
    while n < 70:
        longn = longn + "k"
        n += 1
    doc = SmileDoc()
    obj = doc.start_object()
    doc.add_field(obj, doc._text(longn), doc.add_i32(1))
    doc.add_top(obj)
    raw = encode(doc, opt)
    if Int(raw[0]) != 0xFA or Int(raw[1]) != 0x34:
        fail("longname " + hex_of(raw))
    back = decode(Span(raw), False)
    if not docs_eq(doc, back):
        fail("longname round")

    print("oracle ok")
