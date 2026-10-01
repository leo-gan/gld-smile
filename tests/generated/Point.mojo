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

struct Point(Copyable, Movable):
    var x: Int64
    var y: Optional[Int64]
    var label: Optional[String]

    def __init__(out self):
        self.x = 0
        self.y = Optional[Int64]()
        self.label = Optional[String]()

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
        put_i64(doc, obj, "x", Int(self.x))
        if self.y:
            put_i64(doc, obj, "y", Int(self.y.value()))
        if self.label:
            put_str(doc, obj, "label", self.label.value())
        return obj

    def decode_from[origin: ImmOrigin](mut self, raw: Span[Byte, origin]) raises DecodeError:
        var doc = decode(raw, False)
        if len(doc.top) != 1:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        self.read_value(doc, doc.top[0])

    def read_value(mut self, doc: SmileDoc, id: Int) raises DecodeError:
        if doc.nodes[id].kind != K_OBJECT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var _f_x = find_field(doc, id, "x")
        if _f_x < 0 or is_null(doc, _f_x):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var _g_f_x = Int64(read_i64(doc, _f_x))
        self.x = _g_f_x
        var _f_y = find_field(doc, id, "y")
        if _f_y < 0 or is_null(doc, _f_y):
            self.y = Optional[Int64]()
        else:
            var _g_f_y = Int64(read_i64(doc, _f_y))
            self.y = Optional[Int64](_g_f_y)
        var _f_label = find_field(doc, id, "label")
        if _f_label < 0 or is_null(doc, _f_label):
            self.label = Optional[String]()
        else:
            var _g_f_label = read_str(doc, _f_label)
            self.label = Optional[String](_g_f_label^)
            var _ok = False
            if self.label.value() == "a":
                _ok = True
            if self.label.value() == "b":
                _ok = True
            if not _ok:
                raise DecodeError(DecodeError.KIND_SCHEMA, 0)
