from std.collections import Span
from std.time import perf_counter_ns

from runtime.doc import SmileDoc
from runtime.options import EncodeOptions
from wire.codec import decode, encode


def _sample() -> SmileDoc:
    var doc = SmileDoc()
    var i = 0
    while i < 32:
        var st = doc.start_object()
        doc.add_field(st, doc._text(String("id")), doc.add_i64(i))
        doc.add_field(st, doc._text(String("name")), doc.add_string(String("item")))
        doc.add_top(st)
        i += 1
    return doc^


def main() raises:
    var doc = _sample()
    var opt = EncodeOptions(True, True, True, False, False)
    var n = 200
    var i = 0
    while i < 20:
        _ = encode(doc, opt)
        i += 1
    var t0 = perf_counter_ns()
    i = 0
    while i < n:
        _ = encode(doc, opt)
        i += 1
    var enc_ns = Int(perf_counter_ns() - t0) // n
    var raw = encode(doc, opt)
    i = 0
    while i < 20:
        _ = decode(Span(raw), False)
        i += 1
    t0 = perf_counter_ns()
    i = 0
    while i < n:
        _ = decode(Span(raw), False)
        i += 1
    var dec_ns = Int(perf_counter_ns() - t0) // n
    print("encode_ns", enc_ns)
    print("decode_ns", dec_ns)
    print("bytes", len(raw))
