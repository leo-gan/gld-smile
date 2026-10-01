from std.collections import List, Optional, Span

from Meta import Meta

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

struct Message(Copyable, Movable):
    var meta: Meta
    var tags: List[Int64]
    var blob: List[Byte]
    var n: String
    var amount: String
    var ok: Bool
    var score: Optional[Float64]

    def __init__(out self):
        self.meta = Meta()
        self.tags = List[Int64]()
        self.blob = List[Byte]()
        self.n = String()
        self.amount = String()
        self.ok = False
        self.score = Optional[Float64]()

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
        var _child = self.meta.to_node(doc)
        doc.add_field(obj, doc._text(String("meta")), _child)
        var _arr = doc.start_array()
        var _i = 0
        while _i < len(self.tags):
            doc.add_elem(_arr, doc.add_i64(Int(self.tags[_i])))
            _i += 1
        doc.add_field(obj, doc._text(String("tags")), _arr)
        put_bytes(doc, obj, "blob", self.blob)
        put_bigint(doc, obj, "n", self.n)
        put_decimal(doc, obj, "amount", self.amount)
        put_bool(doc, obj, "ok", self.ok)
        if self.score:
            put_f64(doc, obj, "score", Float64(self.score.value()))
        return obj

    def decode_from[origin: ImmOrigin](mut self, raw: Span[Byte, origin]) raises DecodeError:
        var doc = decode(raw, False)
        if len(doc.top) != 1:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        self.read_value(doc, doc.top[0])

    def read_value(mut self, doc: SmileDoc, id: Int) raises DecodeError:
        if doc.nodes[id].kind != K_OBJECT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var _f_meta = find_field(doc, id, "meta")
        if _f_meta < 0 or is_null(doc, _f_meta):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var _c_f_meta = Meta()
        _c_f_meta.read_value(doc, _f_meta)
        self.meta = _c_f_meta^
        var _f_tags = find_field(doc, id, "tags")
        if _f_tags < 0 or is_null(doc, _f_tags):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        if doc.nodes[_f_tags].kind != K_ARRAY:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var _items = List[Int64]()
        var _i = 0
        while _i < array_len(doc, _f_tags):
            var _el = array_at(doc, _f_tags, _i)
            _items.append(Int64(read_i64(doc, _el)))
            _i += 1
        self.tags = _items^
        var _f_blob = find_field(doc, id, "blob")
        if _f_blob < 0 or is_null(doc, _f_blob):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var _g_f_blob = read_bytes(doc, _f_blob)
        self.blob = _g_f_blob^
        var _f_n = find_field(doc, id, "n")
        if _f_n < 0 or is_null(doc, _f_n):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var _g_f_n = read_bigint(doc, _f_n)
        self.n = _g_f_n^
        var _f_amount = find_field(doc, id, "amount")
        if _f_amount < 0 or is_null(doc, _f_amount):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var _g_f_amount = read_decimal(doc, _f_amount)
        self.amount = _g_f_amount^
        var _f_ok = find_field(doc, id, "ok")
        if _f_ok < 0 or is_null(doc, _f_ok):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var _g_f_ok = read_bool(doc, _f_ok)
        self.ok = _g_f_ok
        var _f_score = find_field(doc, id, "score")
        if _f_score < 0 or is_null(doc, _f_score):
            self.score = Optional[Float64]()
        else:
            var _g_f_score = read_f64(doc, _f_score)
            self.score = Optional[Float64](_g_f_score)
