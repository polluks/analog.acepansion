#!/usr/bin/env python3
"""Create Amstrad CPC AMSDOS DSK disk image."""

import struct, os, sys

TRACKS, SIDES, SPT, SECSIZE = 40, 2, 9, 512
BLOCK_SIZE = 1024
SECS_PER_BLOCK = BLOCK_SIZE // SECSIZE
TOTAL_SECS = TRACKS * SIDES * SPT
TOTAL_BLOCKS = TOTAL_SECS // SECS_PER_BLOCK

DIR_SECS = 4
MAX_DIR = DIR_SECS * SECSIZE // 32
DATA_START_BLOCK = 3  # boot(1) + dir(4sectors=2blocks) = 3

# CPC BASIC primary tokens (single byte, &80..&FE)
_PRIMARY = {
    'AFTER': 0x80, 'AUTO': 0x81, 'BORDER': 0x82, 'CALL': 0x83,
    'CAT': 0x84, 'CHAIN': 0x85, 'CLEAR': 0x86, 'CLG': 0x87,
    'CLOSEIN': 0x88, 'CLOSEOUT': 0x89, 'CLS': 0x8A, 'CONT': 0x8B,
    'DATA': 0x8C, 'DEF': 0x8D, 'DEFINT': 0x8E, 'DEFREAL': 0x8F,
    'DEFSTR': 0x90, 'DEG': 0x91, 'DELETE': 0x92, 'DIM': 0x93,
    'DRAW': 0x94, 'DRAWR': 0x95, 'EDIT': 0x96, 'ELSE': 0x97,
    'END': 0x98, 'ENT': 0x99, 'ENV': 0x9A, 'ERASE': 0x9B,
    'ERROR': 0x9C, 'EVERY': 0x9D, 'FOR': 0x9E, 'GOSUB': 0x9F,
    'GOTO': 0xA0, 'IF': 0xA1, 'INK': 0xA2, 'INPUT': 0xA3,
    'KEY': 0xA4, 'LET': 0xA5, 'LINE': 0xA6, 'LIST': 0xA7,
    'LOAD': 0xA8, 'LOCATE': 0xA9, 'MEMORY': 0xAA, 'MERGE': 0xAB,
    'MID$': 0xAC, 'MODE': 0xAD, 'MOVE': 0xAE, 'MOVER': 0xAF,
    'NEXT': 0xB0, 'NEW': 0xB1, 'ON': 0xB2, 'OPENIN': 0xB6,
    'OPENOUT': 0xB7, 'ORIGIN': 0xB8, 'OUT': 0xB9, 'PAPER': 0xBA,
    'PEN': 0xBB, 'PLOT': 0xBC, 'PLOTR': 0xBD, 'POKE': 0xBE,
    'PRINT': 0xBF, 'RAD': 0xC1, 'RANDOMIZE': 0xC2, 'READ': 0xC3,
    'RELEASE': 0xC4, 'REM': 0xC5, 'RENUM': 0xC6, 'RESTORE': 0xC7,
    'RESUME': 0xC8, 'RETURN': 0xC9, 'RUN': 0xCA, 'SAVE': 0xCB,
    'SOUND': 0xCC, 'SPEED': 0xCD, 'STOP': 0xCE, 'SYMBOL': 0xCF,
    'TAG': 0xD0, 'TAGOFF': 0xD1, 'TROFF': 0xD2, 'TRON': 0xD3,
    'WAIT': 0xD4, 'WEND': 0xD5, 'WHILE': 0xD6, 'WIDTH': 0xD7,
    'WINDOW': 0xD8, 'WRITE': 0xD9, 'ZONE': 0xDA, 'DI': 0xDB,
    'EI': 0xDC, 'FILL': 0xDD, 'GRAPHICS': 0xDE, 'MASK': 0xDF,
    'FRAME': 0xE0, 'CURSOR': 0xE1, 'ERL': 0xE3, 'FN': 0xE4,
    'SPC': 0xE5, 'STEP': 0xE6, 'SWAP': 0xE7, 'TAB': 0xEA,
    'THEN': 0xEB, 'TO': 0xEC, 'USING': 0xED, 'AND': 0xFA,
    'MOD': 0xFB, 'OR': 0xFC, 'XOR': 0xFD, 'NOT': 0xFE,
}

# CPC BASIC secondary tokens (prefixed with &FF)
_SECONDARY = {
    'ABS': 0x00, 'ASC': 0x01, 'ATN': 0x02, 'CHR$': 0x03,
    'CINT': 0x04, 'COS': 0x05, 'CREAL': 0x06, 'EXP': 0x07,
    'FIX': 0x08, 'FRE': 0x09, 'INKEY': 0x0A, 'INP': 0x0B,
    'INT': 0x0C, 'JOY': 0x0D, 'LEN': 0x0E, 'LOG': 0x0F,
    'LOG10': 0x10, 'LOWER$': 0x11, 'PEEK': 0x12, 'REMAIN': 0x13,
    'SGN': 0x14, 'SIN': 0x15, 'SPACE$': 0x16, 'SQ': 0x17,
    'SQR': 0x18, 'STR$': 0x19, 'TAN': 0x1A, 'UNT': 0x1B,
    'UPPER$': 0x1C, 'VAL': 0x1D, 'EOF': 0x40, 'ERR': 0x41,
    'HIMEM': 0x42, 'INKEY$': 0x43, 'PI': 0x44, 'RND': 0x45,
    'TIME': 0x46, 'XPOS': 0x47, 'YPOS': 0x48, 'DERR': 0x49,
    'BIN$': 0x71, 'DEC$': 0x72, 'HEX$': 0x73, 'INSTR': 0x74,
    'LEFT$': 0x75, 'MAX': 0x76, 'MIN': 0x77, 'POS': 0x78,
    'RIGHT$': 0x79, 'ROUND': 0x7A, 'STRING$': 0x7B, 'TEST': 0x7C,
    'TESTR': 0x7D, 'COPYCHR$': 0x7E, 'VPOS': 0x7F,
}

# Build unified token map: name -> token_bytes
_TOKENS = {}
for kw, v in _PRIMARY.items():
    _TOKENS[kw] = bytes([v])
for kw, v in _SECONDARY.items():
    _TOKENS[kw] = bytes([0xFF, v])

# Operator tokens are purely symbolic, keyword tokens are alphabetic
_OPERATORS = {
    '>=': 0xF0, '<>': 0xF2, '<=': 0xF3, '><': 0xF2, '=<': 0xF3,
    '>': 0xEE, '=': 0xEF, '<': 0xF1,
    '+': 0xF4, '-': 0xF5, '*': 0xF6, '/': 0xF7, '^': 0xF8, '\\': 0xF9,
}
for kw, v in _OPERATORS.items():
    _TOKENS[kw] = bytes([v])

# Sorted longest-first for greedy matching
_TOKEN_NAMES = sorted(_TOKENS.keys(), key=lambda n: -len(n))


def dsk_create(files, out_path):
    buf = bytearray(TOTAL_SECS * SECSIZE)
    for i in range(len(buf)):
        buf[i] = 0xE5

    # Boot sector (linear sector 0)
    boot = bytearray(SECSIZE)
    boot[0] = 0x00
    buf[0:SECSIZE] = boot

    # Bitmap: 1=free, 0=used
    bitmap = [1] * TOTAL_BLOCKS
    for b in range(DATA_START_BLOCK):
        bitmap[b] = 0

    dir_bytes = bytearray(MAX_DIR * 32)
    for i in range(MAX_DIR):
        dir_bytes[i*32] = 0xE5

    entry_idx = 0

    for fname, fext, fdata in files:
        name8 = fname.upper().ljust(8)[:8].encode('ascii')
        ext3  = fext.upper().ljust(3)[:3].encode('ascii')
        fsize = len(fdata)

        extent = 0
        offset = 0
        remaining = fsize

        while remaining > 0:
            if entry_idx >= MAX_DIR:
                raise RuntimeError("Directory full")

            blocks_this = min(16, (remaining + BLOCK_SIZE - 1) // BLOCK_SIZE)
            bytes_this = min(remaining, blocks_this * BLOCK_SIZE)
            records_this = (bytes_this + 127) // 128

            entry = bytearray(32)
            entry[0] = 0
            entry[1:9] = name8
            entry[9:12] = ext3
            entry[12] = extent & 0xFF
            entry[13] = (extent >> 8) & 0x7F
            if remaining <= blocks_this * BLOCK_SIZE:
                entry[13] |= 0x80

            if records_this > 128:
                entry[14] = 0x80
                entry[15] = records_this - 128
            else:
                entry[14] = records_this
                entry[15] = 0

            for bi in range(blocks_this):
                blk = -1
                for b in range(DATA_START_BLOCK, TOTAL_BLOCKS):
                    if bitmap[b]:
                        blk = b
                        bitmap[b] = 0
                        break
                if blk < 0:
                    raise RuntimeError("Disk full")

                entry[16 + bi*2]     = blk & 0xFF
                entry[16 + bi*2 + 1] = (blk >> 8) & 0xFF

                for si in range(SECS_PER_BLOCK):
                    sec_idx = blk * SECS_PER_BLOCK + si
                    if sec_idx >= TOTAL_SECS:
                        break
                    chunk = fdata[offset:offset + SECSIZE]
                    chunk = chunk.ljust(SECSIZE, b'\x00')
                    buf[sec_idx * SECSIZE:(sec_idx + 1) * SECSIZE] = chunk
                    offset += len(chunk)
                    if offset >= fsize:
                        break

            dir_bytes[entry_idx * 32:(entry_idx + 1) * 32] = entry
            entry_idx += 1
            extent += 1
            remaining -= bytes_this

    # Write directory sectors (linear sectors 1-4)
    for i in range(4):
        sec_data = dir_bytes[i*SECSIZE:(i+1)*SECSIZE]
        sec_data = sec_data.ljust(SECSIZE, b'\x00')
        buf[(i + 1) * SECSIZE:(i + 2) * SECSIZE] = sec_data

    # Build DSK header + track data
    dsk = bytearray()
    hdr = bytearray(256)
    hdr[0:16] = b'EXTENDED CPC DSK'
    hdr[16] = 0x0D
    hdr[17] = 0x0A
    track_sz = 256 + SPT * 8 + SPT * SECSIZE
    hdr[0x30] = TRACKS & 0xFF
    hdr[0x32] = SIDES & 0xFF
    hdr[0x34] = track_sz & 0xFF
    hdr[0x35] = (track_sz >> 8) & 0xFF
    dsk.extend(hdr)

    for track in range(TRACKS):
        for side in range(SIDES):
            info = bytearray(256)
            info[0] = track
            info[1] = side
            info[4] = SPT
            info[5] = 0x4E
            dsk.extend(info)
            for sec in range(SPT):
                dsk.extend(bytes([track, side, sec + 1, 2, 0, track, side, sec + 1]))
            for sec in range(SPT):
                lin_sec = (track * SIDES + side) * SPT + sec
                off = lin_sec * SECSIZE
                sd = buf[off:off + SECSIZE]
                sd = sd.ljust(SECSIZE, b'\x00')
                dsk.extend(sd)

    with open(out_path, 'wb') as f:
        f.write(dsk)

    total = sum(len(d) for _, _, d in files)
    used = sum(1 for b in bitmap if b == 0)
    names = ', '.join(f'{n}.{e}' for n, e, _ in files)
    print(f"DSK: {out_path} ({len(dsk)}b, {used}/{TOTAL_BLOCKS} blocks used) - {names} ({total}b data)")


def tokenize_basic(text):
    """Tokenize CPC BASIC source text into internal format.

    Keywords become single-byte (&80..&FE) or double-byte (&FF ..) tokens.
    Operators (+, -, =, etc.) become single-byte tokens.
    Colons become &01.  Quoted strings and REM comments are literal.
    Everything else stays as ASCII text.
    """
    # Set of purely-symbolic tokens (operators) that always match
    _SYM_NAMES = {kw for kw in _TOKEN_NAMES
                  if all(not c.isalpha() and not c.isdigit() for c in kw)}

    result = bytearray()
    for raw_line in text.split('\n'):
        line = raw_line.rstrip('\r').strip()
        if not line:
            continue
        parts = line.split(' ', 1)
        ln = int(parts[0])
        rest = parts[1] if len(parts) > 1 else ''

        tl = bytearray()
        i = 0
        in_string = False
        in_rem = False

        while i < len(rest):
            ch = rest[i]

            # After REM, everything is literal till end of line
            if in_rem:
                tl.append(ord(ch))
                i += 1
                continue

            # Toggle string state
            if ch == '"':
                in_string = not in_string
                tl.append(0x22)
                i += 1
                continue

            # Statement separator (not inside strings)
            if ch == ':' and not in_string:
                tl.append(0x01)
                i += 1
                continue

            # Inside string: copy literally
            if in_string:
                tl.append(ord(ch))
                i += 1
                continue

            # Try token match (greedy, longest first)
            matched = False
            upper = rest[i:].upper()
            for kw in _TOKEN_NAMES:
                if upper.startswith(kw):
                    nxt = i + len(kw)
                    # Symbolic tokens always match; keywords need non-alpha after
                    if kw in _SYM_NAMES or nxt >= len(rest) or not rest[nxt].isalpha():
                        tl.extend(_TOKENS[kw])
                        i += len(kw)
                        matched = True
                        if kw == 'REM':
                            in_rem = True
                        break
            if matched:
                continue

            # Default: copy character as-is
            tl.append(ord(ch))
            i += 1

        ll = len(tl) + 1  # body + terminating &0D
        result.extend(struct.pack('>H', ln))   # line number (BE)
        result.extend(struct.pack('<H', ll))   # line length (LE)
        result.extend(tl)
        result.append(0x0D)                    # end of line marker

    result.append(0x1A)  # end of program marker
    return bytes(result)


if __name__ == '__main__':
    base = os.getcwd() if len(sys.argv) < 2 else sys.argv[1]

    bin_path = os.path.join(base, 'driver/analog_driver.bin')
    bas_path = os.path.join(base, 'driver/analog_demo.bas')
    out_path = os.path.join(base, 'driver/analog.dsk')

    with open(bin_path, 'rb') as f:
        bin_data = f.read()
    with open(bas_path, 'rb') as f:
        bas_text = f.read()

    bas_tok = tokenize_basic(bas_text.decode('ascii', errors='replace'))

    readme = b"Analog ACEpansion - Analog Joystick Driver for Amstrad CPC/GX4000\r\n"
    readme += b"\r\n"
    readme += b"LOAD \"DRIVER.BIN\", &A000    :REM Load driver at &A000\r\n"
    readme += b"CALL &A000                     :REM Initialize driver\r\n"
    readme += b"CALL &A003                     :REM Read joystick\r\n"
    readme += b"PEEK(&A006) = joystick state   :REM bit0=up,1=dn,2=left,3=right,4=fire\r\n"
    readme += b"PEEK(&A007) = X-axis raw (0-63)\r\n"
    readme += b"PEEK(&A008) = Y-axis raw (0-63)\r\n"
    readme += b"PEEK(&A009) = fire button (0=release, 1=press)\r\n"
    readme += b"\r\n"
    readme += b"Or just RUN\"DEMO\" for the interactive demo.\r\n"
    readme += b"\r\n"
    readme += b"Based on Tennis Cup 2 analog joystick ADC routine.\r\n"

    files = [
        ('DRIVER', 'BIN', bin_data),
        ('DEMO', 'BAS', bas_tok),
        ('README', 'TXT', readme),
    ]

    dsk_create(files, out_path)
