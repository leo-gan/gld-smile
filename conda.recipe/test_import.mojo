from std.collections import List, Span

from smile import DecodeError, decode_bytes


def main() raises:
    var raw = List[Byte]()
    raw.append(Byte(0x21))
    var doc = decode_bytes(Span(raw))
    if len(doc.top) != 1:
        raise Error("import decode failed")
    print("smile import ok", DecodeError.KIND_EOF)
