from std.collections import List, Optional, Span

from runtime.bind import (
    array_at,
    array_len,
    find_field,
    is_null,
    put_bigint,
    put_bool,
    put_bytes,
    put_decimal,
    put_f64,
    put_i64,
    put_str,
    read_bigint,
    read_bool,
    read_bytes,
    read_decimal,
    read_f64,
    read_i64,
    read_str,
)
from runtime.doc import K_ARRAY, K_BIGINT, K_BINARY, K_BOOL, K_DECIMAL, K_F32, K_F64, K_I32, K_I64, K_OBJECT, K_STRING, SmileDoc
from runtime.error import DecodeError
from runtime.options import EncodeOptions
from wire.codec import decode, encode

struct Meta(Copyable, Movable):
    var region: String

    def __init__(out self):
        self.region = String()

    def encoded_len(self, options: EncodeOptions) raises DecodeError -> Int:
        return len(self.to_bytes(options))

    def encode_to(self, mut buf: List[Byte], options: EncodeOptions) raises DecodeError:
        var raw = self.to_bytes(options)
        var i = 0
        while i < len(raw):
            buf.append(raw[i])
            i += 1

    def to_bytes(self, options: EncodeOptions) raises DecodeError -> List[Byte]:
        var doc = SmileDoc()
        doc.add_top(self.to_node(doc))
        return encode(doc, options)

    def to_node(self, mut doc: SmileDoc) raises DecodeError -> Int:
        var obj = doc.start_object()
        put_str(doc, obj, "region", self.region)
        return obj

    def decode_from[origin: ImmOrigin](mut self, raw: Span[Byte, origin]) raises DecodeError:
        var doc = decode(raw, False)
        if len(doc.top) != 1:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        self.read_value(doc, doc.top[0])

    def read_value(mut self, doc: SmileDoc, id: Int) raises DecodeError:
        if doc.nodes[id].kind != K_OBJECT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var _f_region = find_field(doc, id, "region")
        if _f_region < 0 or is_null(doc, _f_region):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var _g_f_region = read_str(doc, _f_region)
        self.region = _g_f_region^
