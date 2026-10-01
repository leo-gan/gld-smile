from std.collections import List

from runtime.numtext import dec_to_tc, format_decimal, parse_decimal, parse_decimal_scale, tc_to_dec


def fail(msg: String) raises:
    print(msg)
    raise Error(msg)


def hex_of(raw: List[Byte]) -> String:
    var digits = "0123456789abcdef"
    var db = digits.as_bytes()
    var out = String()
    var i = 0
    while i < len(raw):
        var b = Int(raw[i])
        out = out + chr(Int(db[b >> 4]))
        out = out + chr(Int(db[b & 0xF]))
        i += 1
    return out


def check_tc(text: String, want: String) raises:
    var raw = dec_to_tc(text)
    var got = hex_of(raw)
    if got != want:
        fail(text + " -> " + got + " != " + want)
    var back = tc_to_dec(raw)
    if back != text and not (text == "-0" or (text == "0" and back == "0")):
        if back != text:
            fail("back " + text + " -> " + back)


def main() raises:
    check_tc("0", "00")
    check_tc("1", "01")
    check_tc("-1", "ff")
    check_tc("127", "7f")
    check_tc("128", "0080")
    check_tc("255", "00ff")
    check_tc("256", "0100")
    check_tc("-10", "f6")
    check_tc("-128", "80")
    check_tc("-129", "ff7f")
    var raw = dec_to_tc("100")
    var shown = format_decimal(2, raw)
    if shown != "1.00":
        fail(shown)
    if parse_decimal_scale("1.00") != 2:
        fail("scale")
    var back = parse_decimal("1.00")
    if hex_of(back) != "64":
        fail("unscaled " + hex_of(back))
    if format_decimal(-2, dec_to_tc("1")) != "1E+2":
        fail(format_decimal(-2, dec_to_tc("1")))
    if parse_decimal_scale("1E+2") != -2:
        fail("exp scale")
    print("num ok")
