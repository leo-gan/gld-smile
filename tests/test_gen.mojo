from std.collections import List, Optional, Span

from runtime.doc import K_STRING
from runtime.options import EncodeOptions
from Message import Message
from Meta import Meta
from Point import Point
from Token import Token


def fail(msg: String) raises:
    print(msg)
    raise Error(msg)


def main() raises:
    var opt = EncodeOptions()
    var p = Point()
    p.x = 3
    p.y = Optional[Int64](Int64(4))
    p.label = Optional[String](String("a"))
    var raw = p.to_bytes(opt)
    if p.encoded_len(opt) != len(raw):
        fail("len")
    var buf = List[Byte]()
    p.encode_to(buf, opt)
    if len(buf) != len(raw):
        fail("encode_to")
    var back = Point()
    back.decode_from(Span(raw))
    if back.x != 3 or not back.y or back.y.value() != 4:
        fail("point")
    if not back.label or back.label.value() != "a":
        fail("label")

    var m = Message()
    var meta = Meta()
    meta.region = String("us")
    m.meta = meta^
    m.tags = List[Int64]()
    m.tags.append(Int64(1))
    m.tags.append(Int64(2))
    m.blob = List[Byte]()
    m.blob.append(Byte(9))
    m.n = String("255")
    m.amount = String("1.00")
    m.ok = True
    m.score = Optional[Float64](Float64(1.5))
    raw = m.to_bytes(opt)
    var mb = Message()
    mb.decode_from(Span(raw))
    if mb.meta.region != "us" or len(mb.tags) != 2 or mb.tags[1] != 2:
        fail("message")
    if len(mb.blob) != 1 or Int(mb.blob[0]) != 9:
        fail("blob")
    if mb.n != "255" or mb.amount != "1.00" or not mb.ok:
        fail("nums " + mb.n + " " + mb.amount)
    if not mb.score or mb.score.value() != 1.5:
        fail("score")

    var tok = Token()
    tok.tag = 0
    tok.arm0 = String("hi")
    raw = tok.to_bytes(opt)
    var tb = Token()
    tb.decode_from(Span(raw))
    if tb.tag != 0 or tb.arm0 != "hi":
        fail("token str")
    tok.tag = 1
    tok.arm1 = 9
    raw = tok.to_bytes(opt)
    tb.decode_from(Span(raw))
    if tb.tag != 1 or tb.arm1 != 9:
        fail("token int")
    _ = K_STRING
    print("gen ok")
