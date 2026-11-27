class_name WIInflate
extends RefCounted
## Quiet, bounded gzip reader for attacker-controlled bytes. The engine's own
## decompress prints ERROR/WARNING on a bad or oversized stream; this returns
## an empty array instead and never produces more than `max_output` bytes.
## Only single-member gzip with no optional header fields is accepted.

const _LEN_BASE: Array[int] = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
const _LEN_EXTRA: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
const _DIST_BASE: Array[int] = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
const _DIST_EXTRA: Array[int] = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
const _CODE_ORDER: Array[int] = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

static var _crc_table := PackedInt64Array()

var _src := PackedByteArray()
var _pos := 0
var _bit_buffer := 0
var _bit_count := 0
var _out := PackedByteArray()
var _max := 0
var _failed := false


## `{ok: bool, data: PackedByteArray}`; ok=false for anything but a complete,
## checksum-verified stream within the cap.
static func gunzip(bytes: PackedByteArray, max_output: int) -> Dictionary:
	var failed := {"ok": false, "data": PackedByteArray()}
	if bytes.size() < 18 or bytes[0] != 0x1f or bytes[1] != 0x8b or bytes[2] != 8 or bytes[3] != 0:
		return failed
	var reader := WIInflate.new()
	reader._src = bytes
	reader._pos = 10
	reader._max = max_output
	reader._inflate()
	if reader._failed or reader._pos + 8 != bytes.size():
		return failed
	var out := reader._out
	if _u32(bytes, reader._pos + 4) != out.size() or _u32(bytes, reader._pos) != crc32(out):
		return failed
	return {"ok": true, "data": out}


static func crc32(bytes: PackedByteArray) -> int:
	if _crc_table.is_empty():
		_crc_table.resize(256)
		for n in 256:
			var c := n
			for _k in 8:
				c = (0xedb88320 ^ (c >> 1)) if (c & 1) == 1 else (c >> 1)
			_crc_table[n] = c
	var crc := 0xffffffff
	for b: int in bytes:
		crc = _crc_table[(crc ^ b) & 0xff] ^ (crc >> 8)
	return crc ^ 0xffffffff


static func _u32(bytes: PackedByteArray, at: int) -> int:
	return bytes[at] | (bytes[at + 1] << 8) | (bytes[at + 2] << 16) | (bytes[at + 3] << 24)


func _bit() -> int:
	if _bit_count == 0:
		if _pos >= _src.size():
			_failed = true
			return 0
		_bit_buffer = _src[_pos]
		_pos += 1
		_bit_count = 8
	var b := _bit_buffer & 1
	_bit_buffer >>= 1
	_bit_count -= 1
	return b


func _bits(count: int) -> int:
	var value := 0
	for i in count:
		value |= _bit() << i
	return value


func _inflate() -> void:
	while not _failed:
		var last := _bit()
		var kind := _bits(2)
		if _failed:
			return
		match kind:
			0:
				_stored()
			1:
				_fixed()
			2:
				_dynamic()
			_:
				_failed = true
		if last == 1:
			return


func _stored() -> void:
	_bit_count = 0
	if _pos + 4 > _src.size():
		_failed = true
		return
	var length := _src[_pos] | (_src[_pos + 1] << 8)
	var check := _src[_pos + 2] | (_src[_pos + 3] << 8)
	_pos += 4
	if length != (~check & 0xffff) or _pos + length > _src.size() or _out.size() + length > _max:
		_failed = true
		return
	_out.append_array(_src.slice(_pos, _pos + length))
	_pos += length


func _fixed() -> void:
	var lengths: Array[int] = []
	lengths.resize(288)
	for i in 288:
		lengths[i] = 8 if i < 144 else 9 if i < 256 else 7 if i < 280 else 8
	var distances: Array[int] = []
	distances.resize(30)
	distances.fill(5)
	_codes(_table(lengths), _table(distances))


func _dynamic() -> void:
	var literal_count := _bits(5) + 257
	var distance_count := _bits(5) + 1
	var code_count := _bits(4) + 4
	if _failed or literal_count > 286 or distance_count > 30:
		_failed = true
		return
	var code_lengths: Array[int] = []
	code_lengths.resize(19)
	code_lengths.fill(0)
	for i in code_count:
		code_lengths[_CODE_ORDER[i]] = _bits(3)
	var code_table := _table(code_lengths)
	var lengths: Array[int] = []
	while lengths.size() < literal_count + distance_count and not _failed:
		var symbol := _decode(code_table)
		if symbol < 16:
			lengths.append(symbol)
			continue
		var repeated := 0
		var times := 0
		if symbol == 16:
			if lengths.is_empty():
				_failed = true
				return
			repeated = lengths[-1]
			times = 3 + _bits(2)
		elif symbol == 17:
			times = 3 + _bits(3)
		else:
			times = 11 + _bits(7)
		if lengths.size() + times > literal_count + distance_count:
			_failed = true
			return
		for _i in times:
			lengths.append(repeated)
	if _failed or lengths[256] == 0:
		_failed = true
		return
	_codes(_table(lengths.slice(0, literal_count)), _table(lengths.slice(literal_count)))


## Canonical Huffman table as [counts per length, symbols by code]. An
## over-subscribed set fails here; an incomplete one fails at the unused code.
func _table(lengths: Array[int]) -> Array:
	var counts: Array[int] = []
	counts.resize(16)
	counts.fill(0)
	for length: int in lengths:
		counts[length] += 1
	var left := 1
	for length in range(1, 16):
		left = (left << 1) - counts[length]
		if left < 0:
			_failed = true
	var offsets: Array[int] = []
	offsets.resize(16)
	offsets.fill(0)
	for length in range(1, 15):
		offsets[length + 1] = offsets[length] + counts[length]
	var symbols: Array[int] = []
	symbols.resize(lengths.size())
	symbols.fill(0)
	for symbol in lengths.size():
		if lengths[symbol] != 0:
			symbols[offsets[lengths[symbol]]] = symbol
			offsets[lengths[symbol]] += 1
	return [counts, symbols]


func _decode(table: Array) -> int:
	var counts: Array[int] = table[0]
	var symbols: Array[int] = table[1]
	var code := 0
	var first := 0
	var index := 0
	for length in range(1, 16):
		code |= _bit()
		if _failed:
			return 0
		var count := counts[length]
		if code - count < first:
			return symbols[index + (code - first)]
		index += count
		first = (first + count) << 1
		code <<= 1
	_failed = true
	return 0


func _codes(literals: Array, distances: Array) -> void:
	while not _failed:
		var symbol := _decode(literals)
		if _failed:
			return
		if symbol < 256:
			if _out.size() >= _max:
				_failed = true
				return
			_out.append(symbol)
			continue
		if symbol == 256:
			return
		symbol -= 257
		if symbol >= 29:
			_failed = true
			return
		var length := _LEN_BASE[symbol] + _bits(_LEN_EXTRA[symbol])
		var distance_symbol := _decode(distances)
		if _failed or distance_symbol >= 30:
			_failed = true
			return
		var distance := _DIST_BASE[distance_symbol] + _bits(_DIST_EXTRA[distance_symbol])
		if _failed or distance > _out.size() or _out.size() + length > _max:
			_failed = true
			return
		var start := _out.size() - distance
		if distance >= length:
			_out.append_array(_out.slice(start, start + length))
		else:
			for i in length:
				_out.append(_out[start + i])
