from std.collections import List, Span

from runtime.doc import (
    K_ARRAY,
    K_BIGINT,
    K_BINARY,
    K_BOOL,
    K_DECIMAL,
    K_F32,
    K_F64,
    K_I32,
    K_I64,
    K_NULL,
    K_OBJECT,
    K_STRING,
    MAX_BLOB,
    MAX_DEPTH,
    I32_MAX,
    I32_MIN,
    SmileDoc,
)
from runtime.error import DecodeError
from runtime.options import EncodeOptions
from runtime.utf8 import string_from_span


comptime SHARE_LIMIT = 1024


def zz32(v: Int) -> UInt64:
    """Zigzag of a 32-bit signed value, zero-extended."""
    var u = UInt64(v) & 0xFFFFFFFF
    var shifted = (u << 1) & 0xFFFFFFFF
    var sign = UInt64(0)
    if (u & 0x80000000) != 0:
        sign = 0xFFFFFFFF
    return shifted ^ sign


def zz64(v: Int) -> UInt64:
    var u = UInt64(v)
    var sign = UInt64(0)
    if v < 0:
        sign = 0xFFFFFFFFFFFFFFFF
    return (u << 1) ^ sign


def zz_dec32(u: UInt64) -> Int:
    var x = u & 0xFFFFFFFF
    var mag = x >> 1
    if (x & 1) == 0:
        return Int(mag)
    return -Int(mag) - 1


def zz_dec64(u: UInt64) -> Int:
    var mag = u >> 1
    if (u & 1) == 0:
        return Int(mag)
    if mag == 0x7FFFFFFFFFFFFFFF:
        return Int(UInt64(1) << 63)
    return -Int(mag) - 1


def _shl_fits(acc: UInt64, k: Int) -> Bool:
    if acc == 0:
        return True
    if k <= 0:
        return True
    if k >= 64:
        return False
    var limit = UInt64(0xFFFFFFFFFFFFFFFF) >> UInt64(k)
    return acc <= limit


def encode_7bit(data: List[Byte], at: Int, n: Int) -> List[Byte]:
    """7-bit safe binary. The last byte keeps data in its low bits."""
    var out = List[Byte]()
    if n == 0:
        return out^
    var acc = UInt64(0)
    var nbits = 0
    var i = 0
    while i < n:
        acc = (acc << 8) | UInt64(data[at + i])
        nbits += 8
        while nbits >= 7:
            nbits -= 7
            out.append(Byte(Int((acc >> UInt64(nbits)) & 0x7F)))
            if nbits == 0:
                acc = 0
            else:
                acc = acc & ((UInt64(1) << UInt64(nbits)) - 1)
        i += 1
    if nbits > 0:
        out.append(Byte(Int(acc & ((UInt64(1) << UInt64(nbits)) - 1))))
    return out^


def decode_7bit(enc: List[Int], raw_n: Int, strict: Bool, offset: Int) raises DecodeError -> List[Byte]:
    var out = List[Byte]()
    if raw_n == 0:
        if len(enc) != 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, offset)
        return out^
    var bits = raw_n * 8
    var need = (bits + 6) // 7
    if len(enc) != need:
        raise DecodeError(DecodeError.KIND_SYNTAX, offset)
    var acc = UInt64(0)
    var got = 0
    var seen = 0
    var j = 0
    while j < need:
        var left = bits - seen
        var take = 7
        if left < 7:
            take = left
        var mask = (1 << take) - 1
        var b = enc[j]
        if (b & 0x80) != 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, offset)
        if strict and take < 7 and (b >> take) != 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, offset)
        acc = (acc << UInt64(take)) | UInt64(b & mask)
        got += take
        seen += take
        while got >= 8:
            got -= 8
            out.append(Byte(Int((acc >> UInt64(got)) & 0xFF)))
            if got == 0:
                acc = 0
            else:
                acc = acc & ((UInt64(1) << UInt64(got)) - 1)
        j += 1
    if len(out) != raw_n:
        raise DecodeError(DecodeError.KIND_SYNTAX, offset)
    return out^


def _ascii_bytes(s: String) -> List[Byte]:
    var raw = s.as_bytes()
    var out = List[Byte]()
    var i = 0
    while i < len(raw):
        out.append(raw[i])
        i += 1
    return out^


def _is_ascii(raw: List[Byte]) -> Bool:
    var i = 0
    while i < len(raw):
        if Int(raw[i]) >= 0x80:
            return False
        i += 1
    return True


def _find_share(buf: List[String], s: String) -> Int:
    var i = 0
    while i < len(buf):
        if (i & 0xFF) < 0xFE and buf[i] == s:
            return i
        i += 1
    return -1


struct Writer:
    var buf: List[Byte]
    var names_on: Bool
    var values_on: Bool
    var raw_bin: Bool
    var names: List[String]
    var values: List[String]

    def __init__(out self, options: EncodeOptions):
        self.buf = List[Byte]()
        self.names_on = options.shared_names
        # Without a header the spec forces shared values off and raw binary off.
        if options.header:
            self.values_on = options.shared_values
            self.raw_bin = options.raw_binary
        else:
            self.values_on = False
            self.raw_bin = False
        self.names = List[String]()
        self.values = List[String]()

    def put(mut self, b: Int):
        self.buf.append(Byte(b & 0xFF))

    def take(mut self) -> List[Byte]:
        var empty = List[Byte]()
        var out = self.buf^
        self.buf = empty^
        return out^

    def puts(mut self, raw: List[Byte]):
        var i = 0
        while i < len(raw):
            self.buf.append(raw[i])
            i += 1

    def write_uvint(mut self, u: UInt64, min_bytes: Int):
        var rev = List[Int]()
        var x = u
        rev.append(0x80 | Int(x & 0x3F))
        x = x >> 6
        while x > 0:
            rev.append(Int(x & 0x7F))
            x = x >> 7
        while len(rev) < min_bytes:
            rev.append(0)
        var i = len(rev) - 1
        while i >= 0:
            self.put(rev[i])
            i -= 1

    def _ref_value(mut self, ix: Int):
        if ix < 31:
            self.put(1 + ix)
            return
        self.put(0xEC + (ix >> 8))
        self.put(ix & 0xFF)

    def _ref_name(mut self, ix: Int):
        if ix < 64:
            self.put(0x40 + ix)
            return
        self.put(0x30 + (ix >> 8))
        self.put(ix & 0xFF)

    def write_key(mut self, s: String):
        var raw = _ascii_bytes(s)
        var n = len(raw)
        if n == 0:
            self.put(0x20)
            return
        if self.names_on:
            var ix = _find_share(self.names, s)
            if ix >= 0:
                self._ref_name(ix)
                return
        var ascii = _is_ascii(raw)
        if ascii and n <= 64:
            self.put(0x7F + n)
            self.puts(raw)
        elif (not ascii) and n >= 2 and n <= 57:
            self.put(0xBE + n)
            self.puts(raw)
        else:
            self.put(0x34)
            self.puts(raw)
            self.put(0xFC)
        if self.names_on:
            self._push_name(s)

    def _push_name(mut self, s: String):
        # Slots whose low byte is 0xFE or 0xFF stay in the window so indexes match
        # the decoder, and _find_share refuses to emit those references.
        if len(self.names) == SHARE_LIMIT:
            self.names = List[String]()
        self.names.append(s)

    def _push_value(mut self, s: String):
        if len(self.values) == SHARE_LIMIT:
            self.values = List[String]()
        self.values.append(s)

    def write_string(mut self, s: String):
        var raw = _ascii_bytes(s)
        var n = len(raw)
        if n == 0:
            self.put(0x20)
            return
        var ascii = _is_ascii(raw)
        var short = False
        if ascii and n <= 64:
            short = True
        if (not ascii) and n >= 2 and n <= 64:
            short = True
        if short and self.values_on:
            var ix = _find_share(self.values, s)
            if ix >= 0:
                self._ref_value(ix)
                return
        if short and ascii:
            self.put(0x3F + n)
            self.puts(raw)
        elif short:
            self.put(0x7E + n)
            self.puts(raw)
        else:
            if ascii:
                self.put(0xE0)
            else:
                self.put(0xE4)
            self.puts(raw)
            self.put(0xFC)
        if short and self.values_on:
            self._push_value(s)

    def write_binary_bytes(mut self, raw: List[Byte]):
        var n = len(raw)
        if self.raw_bin:
            self.put(0xFD)
            self.write_uvint(UInt64(n), 1)
            self.puts(raw)
            return
        self.put(0xE8)
        self.write_uvint(UInt64(n), 1)
        var enc = encode_7bit(raw, 0, n)
        self.puts(enc)

    def write_mag(mut self, token: Int, raw: List[Byte]):
        self.put(token)
        self.write_uvint(UInt64(len(raw)), 1)
        var enc = encode_7bit(raw, 0, len(raw))
        self.puts(enc)

    def write_f32_bits(mut self, bits: Int):
        var u = UInt32(bits)
        self.put(0x28)
        self.put(Int((u >> 28) & 0x7F))
        self.put(Int((u >> 21) & 0x7F))
        self.put(Int((u >> 14) & 0x7F))
        self.put(Int((u >> 7) & 0x7F))
        self.put(Int(u & 0x7F))

    def write_f64_bits(mut self, bits: UInt64):
        self.put(0x29)
        self.put(Int((bits >> 63) & 1))
        var shift = 56
        while shift >= 0:
            self.put(Int((bits >> UInt64(shift)) & 0x7F))
            shift -= 7

    def write_value(mut self, doc: SmileDoc, id: Int) raises DecodeError:
        var n = doc.nodes[id]
        if n.kind == K_NULL:
            self.put(0x21)
            return
        if n.kind == K_BOOL:
            if n.a == 0:
                self.put(0x22)
            else:
                self.put(0x23)
            return
        if n.kind == K_I32:
            if n.a < I32_MIN or n.a > I32_MAX:
                raise DecodeError(DecodeError.KIND_RANGE, len(self.buf))
            var z = zz32(n.a)
            if z <= 0x1F:
                self.put(0xC0 + Int(z))
                return
            self.put(0x24)
            self.write_uvint(z, 1)
            return
        if n.kind == K_I64:
            self.put(0x25)
            self.write_uvint(zz64(n.a), 5)
            return
        if n.kind == K_F32:
            self.write_f32_bits(n.a)
            return
        if n.kind == K_F64:
            self.write_f64_bits(doc.f64s[n.a])
            return
        if n.kind == K_STRING:
            self.write_string(doc.texts[n.a])
            return
        if n.kind == K_BINARY:
            self.write_binary_bytes(doc.slice_copy(n.a))
            return
        if n.kind == K_BIGINT:
            self.write_mag(0x26, doc.slice_copy(n.a))
            return
        if n.kind == K_DECIMAL:
            self.put(0x2A)
            self.write_uvint(zz32(n.a), 1)
            var mag = doc.slice_copy(n.b)
            self.write_uvint(UInt64(len(mag)), 1)
            self.puts(encode_7bit(mag, 0, len(mag)))
            return
        if n.kind == K_ARRAY:
            self.put(0xF8)
            var i = 0
            while i < n.nchild:
                self.write_value(doc, doc.edges[n.child + i].val)
                i += 1
            self.put(0xF9)
            return
        if n.kind == K_OBJECT:
            self.put(0xFA)
            var i = 0
            while i < n.nchild:
                var e = doc.edges[n.child + i]
                self.write_key(doc.texts[e.key])
                self.write_value(doc, e.val)
                i += 1
            self.put(0xFB)
            return
        raise DecodeError(DecodeError.KIND_TYPE, len(self.buf))


struct Reader[origin: ImmOrigin]:
    var raw: Span[Byte, Self.origin]
    var i: Int
    var names_on: Bool
    var values_on: Bool
    var raw_bin: Bool
    var strict: Bool
    var names: List[String]
    var values: List[String]
    var depth: Int

    def __init__(out self, raw: Span[Byte, Self.origin], strict: Bool):
        self.raw = raw
        self.i = 0
        self.names_on = True
        self.values_on = False
        self.raw_bin = False
        self.strict = strict
        self.names = List[String]()
        self.values = List[String]()
        self.depth = 0

    def _b(mut self) raises DecodeError -> Int:
        if self.i >= len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var c = Int(self.raw[self.i])
        self.i += 1
        return c

    def _remain(self) -> Int:
        return len(self.raw) - self.i

    def _uvint(mut self, max_bytes: Int) raises DecodeError -> UInt64:
        var acc = UInt64(0)
        var n = 0
        while True:
            var b = self._b()
            n += 1
            if n > max_bytes:
                raise DecodeError(DecodeError.KIND_RANGE, self.i - 1)
            if (b & 0x80) != 0:
                if self.strict and (b & 0x40) != 0:
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 1)
                if not _shl_fits(acc, 6):
                    raise DecodeError(DecodeError.KIND_RANGE, self.i - 1)
                return (acc << 6) | UInt64(b & 0x3F)
            if not _shl_fits(acc, 7):
                raise DecodeError(DecodeError.KIND_RANGE, self.i - 1)
            acc = (acc << 7) | UInt64(b & 0x7F)

    def _try_header(mut self) raises DecodeError -> Bool:
        if self._remain() < 4:
            return False
        if Int(self.raw[self.i]) != 0x3A:
            return False
        if Int(self.raw[self.i + 1]) != 0x29 or Int(self.raw[self.i + 2]) != 0x0A:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var flags = Int(self.raw[self.i + 3])
        if ((flags >> 4) & 0xF) != 0:
            raise DecodeError(DecodeError.KIND_VERSION, self.i)
        if self.strict and (flags & 0x08) != 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i + 3)
        self.names_on = (flags & 0x01) != 0
        self.values_on = (flags & 0x02) != 0
        self.raw_bin = (flags & 0x04) != 0
        self.names = List[String]()
        self.values = List[String]()
        self.i += 4
        return True

    def _take(mut self, n: Int, ascii: Bool) raises DecodeError -> String:
        if n < 0 or n > MAX_BLOB:
            raise DecodeError(DecodeError.KIND_RANGE, self.i)
        var tmp = List[Byte]()
        var k = 0
        while k < n:
            var b = self._b()
            if ascii and b >= 0x80:
                raise DecodeError(DecodeError.KIND_UTF8, self.i - 1)
            if (not ascii) and b >= 0xF8:
                raise DecodeError(DecodeError.KIND_UTF8, self.i - 1)
            tmp.append(Byte(b))
            k += 1
        return string_from_span(Span(tmp), self.i - n)

    def _long_string(mut self, ascii: Bool) raises DecodeError -> String:
        var tmp = List[Byte]()
        while True:
            if len(tmp) > MAX_BLOB:
                raise DecodeError(DecodeError.KIND_RANGE, self.i)
            var b = self._b()
            if b == 0xFC:
                break
            if b >= 0xFD:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 1)
            if ascii and b >= 0x80:
                raise DecodeError(DecodeError.KIND_UTF8, self.i - 1)
            tmp.append(Byte(b))
        var start = self.i - len(tmp) - 1
        return string_from_span(Span(tmp), start)

    def _read_7bit(mut self) raises DecodeError -> List[Byte]:
        var n64 = self._uvint(5)
        if n64 > UInt64(MAX_BLOB):
            raise DecodeError(DecodeError.KIND_RANGE, self.i)
        var n = Int(n64)
        var bits = n * 8
        var enc_n = 0
        if n > 0:
            enc_n = (bits + 6) // 7
        var enc = List[Int]()
        var j = 0
        while j < enc_n:
            var b = self._b()
            enc.append(b)
            j += 1
        return decode_7bit(enc^, n, self.strict, self.i)

    def _shared_value(mut self, mut doc: SmileDoc, ix: Int) raises DecodeError -> Int:
        if not self.values_on or ix < 0 or ix >= len(self.values):
            raise DecodeError(DecodeError.KIND_SHARED, self.i)
        var s = self.values[ix]
        return doc.add_string(s^)

    def _push_value(mut self, s: String):
        if len(self.values) == SHARE_LIMIT:
            self.values = List[String]()
        self.values.append(s)

    def _push_name(mut self, s: String):
        if len(self.names) == SHARE_LIMIT:
            self.names = List[String]()
        self.names.append(s)

    def _literal_string(mut self, mut doc: SmileDoc, var s: String, share: Bool) raises DecodeError -> Int:
        if share and self.values_on:
            self._push_value(s)
        return doc.add_string(s^)

    def _value(mut self, mut doc: SmileDoc) raises DecodeError -> Int:
        var ch = self._b()
        if ch >= 0x01 and ch <= 0x1F:
            return self._shared_value(doc, ch - 1)
        if ch == 0x20:
            return doc.add_string(String())
        if ch == 0x21:
            return doc.add_null()
        if ch == 0x22:
            return doc.add_bool(False)
        if ch == 0x23:
            return doc.add_bool(True)
        if ch == 0x24:
            var u = self._uvint(5)
            if u > 0xFFFFFFFF:
                raise DecodeError(DecodeError.KIND_RANGE, self.i)
            return doc.add_i32(zz_dec32(u))
        if ch == 0x25:
            var start = self.i
            var u = self._uvint(10)
            if self.strict and self.i - start < 5:
                raise DecodeError(DecodeError.KIND_SYNTAX, start)
            return doc.add_i64(zz_dec64(u))
        if ch == 0x26:
            return doc.add_bigint(self._read_7bit())
        if ch == 0x28:
            return doc.add_f32_bits(Int(self._f32()))
        if ch == 0x29:
            return doc.add_f64_bits(self._f64())
        if ch == 0x2A:
            var scale_u = self._uvint(5)
            if scale_u > 0xFFFFFFFF:
                raise DecodeError(DecodeError.KIND_RANGE, self.i)
            var mag = self._read_7bit()
            return doc.add_decimal(zz_dec32(scale_u), mag^)
        if ch >= 0x40 and ch <= 0x7F:
            var s = self._take(1 + (ch & 0x3F), True)
            return self._literal_string(doc, s^, True)
        if ch >= 0x80 and ch <= 0xBF:
            var s = self._take(2 + (ch & 0x3F), False)
            return self._literal_string(doc, s^, True)
        if ch >= 0xC0 and ch <= 0xDF:
            var z = ch & 0x1F
            var mag = z >> 1
            var v = mag
            if (z & 1) != 0:
                v = -mag - 1
            return doc.add_i32(v)
        if ch == 0xE0:
            var s = self._long_string(True)
            return doc.add_string(s^)
        if ch == 0xE4:
            var s = self._long_string(False)
            return doc.add_string(s^)
        if ch == 0xE8:
            return doc.add_binary(self._read_7bit())
        if ch >= 0xEC and ch <= 0xEF:
            var b2 = self._b()
            if self.strict and (b2 == 0xFE or b2 == 0xFF):
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 1)
            var ix = ((ch & 0x3) << 8) | b2
            if self.strict and ix < 31:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 2)
            return self._shared_value(doc, ix)
        if ch == 0xF8:
            return self._array(doc)
        if ch == 0xFA:
            return self._object(doc)
        if ch == 0xFD:
            if not self.raw_bin:
                raise DecodeError(DecodeError.KIND_TYPE, self.i - 1)
            var n64 = self._uvint(5)
            if n64 > UInt64(MAX_BLOB):
                raise DecodeError(DecodeError.KIND_RANGE, self.i)
            var tmp = List[Byte]()
            var k = 0
            var n = Int(n64)
            while k < n:
                tmp.append(Byte(self._b()))
                k += 1
            return doc.add_binary(tmp^)
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 1)

    def _f32(mut self) raises DecodeError -> UInt32:
        var b0 = self._b()
        var b1 = self._b()
        var b2 = self._b()
        var b3 = self._b()
        var b4 = self._b()
        if ((b0 | b1 | b2 | b3 | b4) & 0x80) != 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 5)
        if self.strict and (b0 & 0x70) != 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 5)
        var bits = UInt32(b0 & 0x0F) << 28
        bits = bits | (UInt32(b1 & 0x7F) << 21)
        bits = bits | (UInt32(b2 & 0x7F) << 14)
        bits = bits | (UInt32(b3 & 0x7F) << 7)
        bits = bits | UInt32(b4 & 0x7F)
        return bits

    def _f64(mut self) raises DecodeError -> UInt64:
        var raw = List[Int]()
        var k = 0
        while k < 10:
            var b = self._b()
            if (b & 0x80) != 0:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 1)
            raw.append(b)
            k += 1
        if self.strict and (raw[0] & 0x7E) != 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 10)
        var bits = UInt64(raw[0] & 0x01) << 63
        var shift = 56
        var j = 1
        while j < 10:
            bits = bits | (UInt64(raw[j] & 0x7F) << UInt64(shift))
            shift -= 7
            j += 1
        return bits

    def _array(mut self, mut doc: SmileDoc) raises DecodeError -> Int:
        self.depth += 1
        if self.depth > MAX_DEPTH:
            raise DecodeError(DecodeError.KIND_DEPTH, self.i)
        var id = doc.start_array()
        while True:
            if self._remain() == 0:
                raise DecodeError(DecodeError.KIND_EOF, self.i)
            if Int(self.raw[self.i]) == 0xF9:
                self.i += 1
                break
            var v = self._value(doc)
            doc.add_elem(id, v)
        self.depth -= 1
        return id

    def _name_text(mut self, mut doc: SmileDoc, var s: String, share: Bool) -> Int:
        if share and self.names_on:
            self._push_name(s)
        return doc._text(s^)

    def _shared_name(mut self, mut doc: SmileDoc, ix: Int) raises DecodeError -> Int:
        if not self.names_on or ix < 0 or ix >= len(self.names):
            raise DecodeError(DecodeError.KIND_SHARED, self.i)
        var s = self.names[ix]
        return doc._text(s^)

    def _key(mut self, mut doc: SmileDoc) raises DecodeError -> Int:
        """Return a text index, or -1 at the end of an object."""
        var ch = self._b()
        if ch == 0xFB:
            return -1
        if ch == 0x20:
            return doc._text(String())
        if ch >= 0x30 and ch <= 0x33:
            var b2 = self._b()
            if self.strict and (b2 == 0xFE or b2 == 0xFF):
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 1)
            var ix = ((ch & 0x3) << 8) | b2
            if self.strict and ix < 64:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 2)
            return self._shared_name(doc, ix)
        if ch == 0x34:
            var s = self._long_string(False)
            return self._name_text(doc, s^, True)
        if ch >= 0x40 and ch <= 0x7F:
            return self._shared_name(doc, ch - 0x40)
        if ch >= 0x80 and ch <= 0xBF:
            var s = self._take(1 + (ch & 0x3F), True)
            return self._name_text(doc, s^, True)
        if ch >= 0xC0 and ch <= 0xF7:
            var low = ch & 0x3F
            if low > 0x37:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 1)
            var s = self._take(low + 2, False)
            return self._name_text(doc, s^, True)
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 1)

    def _object(mut self, mut doc: SmileDoc) raises DecodeError -> Int:
        self.depth += 1
        if self.depth > MAX_DEPTH:
            raise DecodeError(DecodeError.KIND_DEPTH, self.i)
        var id = doc.start_object()
        while True:
            var key = self._key(doc)
            if key < 0:
                break
            var v = self._value(doc)
            doc.add_field(id, key, v)
        self.depth -= 1
        return id

    def read_doc(mut self) raises DecodeError -> SmileDoc:
        var doc = SmileDoc()
        if self._remain() == 0:
            return doc^
        if Int(self.raw[self.i]) == 0x3A:
            _ = self._try_header()
        while self._remain() > 0:
            var c = Int(self.raw[self.i])
            if c == 0xFF:
                self.i += 1
                if self._remain() != 0:
                    raise DecodeError(DecodeError.KIND_TRAILING, self.i)
                break
            if c == 0x3A:
                _ = self._try_header()
                continue
            var id = self._value(doc)
            doc.add_top(id)
        return doc^


def encode(doc: SmileDoc, options: EncodeOptions) raises DecodeError -> List[Byte]:
    var w = Writer(options)
    if options.header:
        w.put(0x3A)
        w.put(0x29)
        w.put(0x0A)
        var flags = 0
        if options.shared_names:
            flags |= 0x01
        if options.shared_values:
            flags |= 0x02
        if options.raw_binary:
            flags |= 0x04
        w.put(flags)
    var i = 0
    while i < len(doc.top):
        w.write_value(doc, doc.top[i])
        i += 1
    if options.end_marker:
        w.put(0xFF)
    return w.take()


def decode[origin: ImmOrigin](raw: Span[Byte, origin], strict: Bool) raises DecodeError -> SmileDoc:
    var r = Reader(raw, strict)
    return r.read_doc()
