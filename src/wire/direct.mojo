"""Smile cursor for objects, arrays, bools, int64, float64, and strings.

Shared names are on. The first time a key is written it is stored in the
name window; later writes of the same key are a one-byte backref. Each
value's bytes are still written on that call.
"""

from std.collections import List, Span
from std.memory import unsafe_memcpy

from runtime.error import DecodeError


def _span_eq[origin: ImmOrigin](text: String, raw: Span[Byte, origin]) -> Bool:
    var b = text.as_bytes()
    if len(b) != len(raw):
        return False
    var i = 0
    while i < len(b):
        if b[i] != raw[i]:
            return False
        i += 1
    return True


struct SmileBin(Movable):
    var buf: List[Byte]
    var pos: Int
    var names: List[String]

    def __init__(out self, capacity: Int = 256):
        var cap = capacity
        if cap < 64:
            cap = 64
        self.buf = List[Byte](unsafe_uninit_length=cap)
        self.pos = 0
        self.names = List[String]()

    def ensure(mut self, n: Int):
        var need = self.pos + n
        if need > len(self.buf):
            var cap = len(self.buf)
            while cap < need:
                cap = cap * 2
            self.buf.resize(unsafe_uninit_length=cap)

    def put(mut self, b: Int):
        self.ensure(1)
        self.buf[self.pos] = Byte(b & 255)
        self.pos += 1

    def _span[origin: ImmOrigin](mut self, raw: Span[Byte, origin]):
        var n = len(raw)
        if n == 0:
            return
        self.ensure(n)
        unsafe_memcpy(
            dest=self.buf.unsafe_ptr().unsafe_offset(self.pos),
            src=raw.unsafe_ptr(),
            count=n,
        )
        self.pos += n

    def begin(mut self):
        """Header with shared names on, shared values off, raw binary off."""
        self.pos = 0
        self.put(0x3A)
        self.put(0x29)
        self.put(0x0A)
        self.put(0x01)

    def _uvint(mut self, u: UInt64, min_bytes: Int):
        var mag = u >> 6
        var nbytes = 1
        var tmp = mag
        while tmp > 0:
            nbytes += 1
            tmp = tmp >> 7
        if nbytes < min_bytes:
            nbytes = min_bytes
        var i = nbytes - 1
        while i > 0:
            var shift = (i - 1) * 7
            self.put(Int((mag >> UInt64(shift)) & 0x7F))
            i -= 1
        self.put(0x80 | Int(u & 0x3F))

    def key_lit(mut self, key: StaticString):
        var raw = key.as_bytes()
        var i = 0
        while i < len(self.names):
            if _span_eq(self.names[i], raw):
                self.put(0x40 + i)
                return
            i += 1
        var n = len(raw)
        self.put(0x7F + n)
        self._span(raw)
        self.names.append(String(key))

    def start_object(mut self):
        self.put(0xFA)

    def end_object(mut self):
        self.put(0xFB)

    def start_array(mut self):
        self.put(0xF8)

    def end_array(mut self):
        self.put(0xF9)

    def write_bool(mut self, v: Bool):
        if v:
            self.put(0x23)
        else:
            self.put(0x22)

    def write_i64(mut self, v: Int64):
        var u = UInt64(v)
        var sign = UInt64(0)
        if v < 0:
            sign = 0xFFFFFFFFFFFFFFFF
        var z = (u << 1) ^ sign
        self.put(0x25)
        self._uvint(z, 5)

    def write_f64(mut self, v: Float64):
        var bits = UInt64(v.to_bits())
        self.put(0x29)
        self.put(Int((bits >> 63) & 1))
        var shift = 56
        while shift >= 0:
            self.put(Int((bits >> UInt64(shift)) & 0x7F))
            shift -= 7

    def write_span[origin: ImmOrigin](mut self, raw: Span[Byte, origin]):
        var n = len(raw)
        if n == 0:
            self.put(0x20)
            return
        if n <= 64:
            self.put(0x3F + n)
            self._span(raw)
            return
        self.put(0xE0)
        self._span(raw)
        self.put(0xFC)

    def write_str(mut self, text: String):
        self.write_span(text.as_bytes())

    def take(deinit self) -> List[Byte]:
        if self.pos < len(self.buf):
            self.buf.resize(unsafe_uninit_length=self.pos)
        return self.buf^


struct SmileCur[origin: ImmOrigin](Movable):
    var raw: Span[Byte, Self.origin]
    var i: Int
    var names: List[String]

    def __init__(out self, raw: Span[Byte, Self.origin]):
        self.raw = raw
        self.i = 0
        self.names = List[String]()

    def open(mut self) raises DecodeError:
        if len(self.raw) >= 4 and Int(self.raw[0]) == 0x3A:
            if Int(self.raw[1]) != 0x29 or Int(self.raw[2]) != 0x0A:
                raise DecodeError(DecodeError.KIND_SYNTAX, 0)
            self.i = 4

    def _u8(mut self) raises DecodeError -> Int:
        if self.i >= len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var b = Int(self.raw.unsafe_ptr().unsafe_load(self.i))
        self.i += 1
        return b

    def _uvint(mut self) raises DecodeError -> UInt64:
        var acc = UInt64(0)
        var n = 0
        while n < 10:
            var b = self._u8()
            n += 1
            if (b & 0x80) != 0:
                return (acc << 6) | UInt64(b & 0x3F)
            acc = (acc << 7) | UInt64(b)
        raise DecodeError(DecodeError.KIND_RANGE, self.i)

    def _ascii(mut self, n: Int) raises DecodeError -> String:
        if n < 0 or self.i + n > len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var tmp = List[Byte]()
        if n > 0:
            tmp = List[Byte](unsafe_uninit_length=n)
            unsafe_memcpy(
                dest=tmp.unsafe_ptr(),
                src=self.raw.unsafe_ptr().unsafe_offset(self.i),
                count=n,
            )
        self.i += n
        try:
            return String(from_utf8=Span(unsafe_ptr=tmp.unsafe_ptr(), length=len(tmp)))
        except _:
            raise DecodeError(DecodeError.KIND_UTF8, self.i - n)

    def start_object(mut self) raises DecodeError:
        if self._u8() != 0xFA:
            raise DecodeError(DecodeError.KIND_TYPE, self.i - 1)

    def start_array(mut self) raises DecodeError:
        if self._u8() != 0xF8:
            raise DecodeError(DecodeError.KIND_TYPE, self.i - 1)

    def name_is(self, id: Int, lit: StaticString) -> Bool:
        if id < 0 or id >= len(self.names):
            return False
        var raw = lit.as_bytes()
        var got = self.names[id].as_bytes()
        if len(got) != len(raw):
            return False
        var i = 0
        while i < len(got):
            if got[i] != raw[i]:
                return False
            i += 1
        return True

    def next_id(mut self) raises DecodeError -> Int:
        """Name-window index, or -1 at the end of an object."""
        var ch = self._u8()
        if ch == 0xFB:
            return -1
        if ch >= 0x40 and ch <= 0x7F:
            var ix = ch - 0x40
            if ix >= len(self.names):
                raise DecodeError(DecodeError.KIND_SHARED, self.i)
            return ix
        if ch >= 0x80 and ch <= 0xBF:
            var text = self._ascii(1 + (ch & 0x3F))
            self.names.append(text^)
            return len(self.names) - 1
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i - 1)

    def at_array_end(mut self) raises DecodeError -> Bool:
        if self.i >= len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        if Int(self.raw.unsafe_ptr().unsafe_load(self.i)) != 0xF9:
            return False
        self.i += 1
        return True

    def read_bool(mut self) raises DecodeError -> Bool:
        var ch = self._u8()
        if ch == 0x22:
            return False
        if ch == 0x23:
            return True
        raise DecodeError(DecodeError.KIND_TYPE, self.i - 1)

    def read_i64(mut self) raises DecodeError -> Int64:
        var ch = self._u8()
        var u: UInt64
        if ch == 0x25:
            u = self._uvint()
        elif ch >= 0xC0 and ch <= 0xDF:
            u = UInt64(ch & 0x1F)
        elif ch == 0x24:
            u = self._uvint()
        else:
            raise DecodeError(DecodeError.KIND_TYPE, self.i - 1)
        var mag = u >> 1
        if (u & 1) == 0:
            return Int64(mag)
        if mag == 0x7FFFFFFFFFFFFFFF:
            return Int64(-9223372036854775807) - Int64(1)
        return Int64(0) - Int64(mag) - Int64(1)

    def read_f64(mut self) raises DecodeError -> Float64:
        if self._u8() != 0x29:
            raise DecodeError(DecodeError.KIND_TYPE, self.i - 1)
        var b0 = self._u8()
        var bits = UInt64(b0 & 0x01) << 63
        var shift = 56
        while shift >= 0:
            var b = self._u8()
            bits = bits | (UInt64(b & 0x7F) << UInt64(shift))
            shift -= 7
        return Float64(from_bits=bits)

    def read_string(mut self) raises DecodeError -> String:
        var ch = self._u8()
        if ch == 0x20:
            return String()
        if ch >= 0x40 and ch <= 0x7F:
            return self._ascii(ch - 0x3F)
        if ch == 0xE0:
            var tmp = List[Byte]()
            while True:
                var b = self._u8()
                if b == 0xFC:
                    break
                tmp.append(Byte(b))
            try:
                return String(from_utf8=Span(tmp))
            except _:
                raise DecodeError(DecodeError.KIND_UTF8, self.i)
        raise DecodeError(DecodeError.KIND_TYPE, self.i - 1)
