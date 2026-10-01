from std.collections import Span

from runtime.doc import SmileDoc
from runtime.options import EncodeOptions
from smile import decode_bytes, encode_doc


def main() raises:
    var doc = SmileDoc()
    var obj = doc.start_object()
    doc.add_field(obj, doc._text(String("id")), doc.add_i32(7))
    doc.add_field(obj, doc._text(String("name")), doc.add_string(String("smile")))
    doc.add_top(obj)
    var raw = encode_doc(doc, EncodeOptions())
    var back = decode_bytes(Span(raw))
    print("values", len(back.top), "bytes", len(raw))
