from wire.codec import decode
from wire.direct import SmileBin, SmileCur


def fail(msg: String) raises:
    print(msg)
    raise Error(msg)


def main() raises:
    var bin = SmileBin(capacity=128)
    bin.begin()
    bin.start_array()
    var r = 0
    while r < 2:
        bin.start_object()
        bin.key_lit("a")
        bin.write_i64(1)
        bin.key_lit("b")
        bin.write_str(String("hi"))
        bin.key_lit("c")
        bin.write_f64(1.5)
        bin.key_lit("d")
        bin.write_bool(True)
        bin.end_object()
        r += 1
    bin.end_array()
    var raw = bin^.take()
    var doc = decode(Span(raw), False)
    if len(doc.top) != 1:
        fail("top")
    var cur = SmileCur(Span(raw))
    cur.open()
    cur.start_array()
    r = 0
    while r < 2:
        cur.start_object()
        if cur.next_id() != 0 or cur.read_i64() != 1:
            fail("a")
        if cur.next_id() != 1 or cur.read_string() != "hi":
            fail("b")
        if cur.next_id() != 2 or cur.read_f64() != 1.5:
            fail("c")
        if cur.next_id() != 3 or cur.read_bool() != True:
            fail("d")
        if cur.next_id() != -1:
            fail("end obj")
        r += 1
    if not cur.at_array_end():
        fail("end arr")
    print("ok")
