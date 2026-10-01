from std.collections import List, Span

from runtime.doc import SmileDoc
from runtime.error import DecodeError
from runtime.options import EncodeOptions
from wire.codec import decode, encode


def decode_bytes[origin: ImmOrigin](raw: Span[Byte, origin]) raises DecodeError -> SmileDoc:
    """Decode one Smile section. A missing header defaults to shared names on."""
    return decode(raw, False)


def encode_doc(doc: SmileDoc, options: EncodeOptions) raises DecodeError -> List[Byte]:
    """Encode every top-level value with one header and the caller's layout flags."""
    return encode(doc, options)
