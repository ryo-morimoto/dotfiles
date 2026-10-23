"""Build a hazkey user dictionary that offers emoji as conversion candidates.

hazkey-server loads azooKey user-dictionary files (user.louds, user.loudschars2,
user<N>.loudstxt3) from $XDG_CACHE_HOME/hazkey/shared. The writer below is a port of
AzooKeyKanaKanjiConverter's DictionaryBuilder.exportDictionary(baseName: "user",
shardByFirstCharacter: false) and produces byte-identical files.

usage: build.py <azooKey emoji dir> <frequency.tsv> <overrides.tsv> <charID.chid> <out dir>
"""

import math
import re
import struct
import sys
from collections import defaultdict
from pathlib import Path

HIRAGANA = re.compile(r"^[ぁ-ゖー]+$")
VS16 = "️"
SHARD_SHIFT = 11
ENTRIES_PER_SHARD = 1 << SHARD_SHIFT
CID_SYMBOL, MID_GENERAL = 5, 501
BASE_COST, OVERRIDE_COST = -12.0, -12.0


def latest_emoji_table(directory):
    tables = Path(directory, "EmojiDictionary").glob("emoji_all_E*.txt")
    return max(tables, key=lambda p: tuple(int(n) for n in re.findall(r"\d+", p.stem)))


def read_tsv(path):
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if line and not line.startswith("#"):
            yield line.split("\t")


def score_entries(emoji_table, frequency, overrides):
    # Emoji in the azooKey table are already fully qualified; frequency keys drop VS16.
    readings = {
        cols[0]: {k for k in cols[1].split(",") if HIRAGANA.match(k)}
        for cols in read_tsv(emoji_table)
    }
    tiers = {e: int(t) for e, t in read_tsv(frequency)}
    emoji_per_reading = defaultdict(int)
    for rs in readings.values():
        for r in rs:
            emoji_per_reading[r] += 1

    entries = {}
    for emoji, rs in readings.items():
        tier = tiers.get(emoji.replace(VS16, ""))
        popularity = (9 - min(tier, 9)) * 0.3 if tier is not None else 0.0
        specificity = -min(0.2 * (len(rs) - 1), 1.5)
        for r in rs:
            generic = -min(0.5 * math.log2(emoji_per_reading[r]), 3.0)
            entries[r, emoji] = BASE_COST + popularity + specificity + generic
    for reading, emoji, *cost in read_tsv(overrides):
        entries[reading, emoji] = float(cost[0]) if cost else OVERRIDE_COST
    return entries


def to_katakana(s):
    return "".join(chr(ord(c) + 0x60) if "ぁ" <= c <= "ゖ" else c for c in s)


def build_louds(keys):
    trie = {}
    for key in keys:
        node = trie
        for c in key:
            node = node.setdefault(c, {})
    bits, chars, index = [True, False], [0, 0], {}
    current = [((c,), trie[c]) for c in sorted(trie)]
    bits += [True] * len(current) + [False]
    while current:
        nxt = []
        for path, node in current:
            index[path] = len(chars)
            chars.append(path[-1])
            children = sorted(node)
            bits += [True] * len(children) + [False]
            nxt += [(path + (c,), node[c]) for c in children]
        current = nxt
    return bits, chars, index


def louds_bytes(bits):
    bits = bits + [True] * (-len(bits) % 64)
    out = bytearray()
    for i in range(0, len(bits), 64):
        word = sum(1 << (63 - j) for j, b in enumerate(bits[i : i + 64]) if b)
        out += struct.pack("<Q", word)
    return bytes(out)


def loudstxt3(items):
    payloads = [struct.pack("<H", 0)] * ENTRIES_PER_SHARD
    for local, ruby, rows in items:
        payload = struct.pack("<H", len(rows))
        for _, cost in rows:
            payload += struct.pack("<HHHf", CID_SYMBOL, CID_SYMBOL, MID_GENERAL, cost)
        payload += "\t".join([ruby] + [w for w, _ in rows]).encode()
        payloads[local] = payload
    out = bytearray(struct.pack("<H", ENTRIES_PER_SHARD))
    offset = 2 + 4 * ENTRIES_PER_SHARD
    for p in payloads:
        out += struct.pack("<I", offset)
        offset += len(p)
    return bytes(out) + b"".join(payloads)


def write_user_dictionary(entries, charid, out):
    char2id = {c: i for i, c in enumerate(Path(charid).read_text(encoding="utf-8"))}
    grouped = defaultdict(list)
    for (reading, emoji), cost in sorted(entries.items()):
        ruby = to_katakana(reading)
        if all(c in char2id for c in ruby):
            grouped[ruby].append((emoji, cost))
    keys = {ruby: tuple(char2id[c] for c in ruby) for ruby in grouped}
    bits, chars, index = build_louds(keys.values())
    out.mkdir(parents=True, exist_ok=True)
    (out / "user.louds").write_bytes(louds_bytes(bits))
    (out / "user.loudschars2").write_bytes(bytes(chars))
    shards = defaultdict(list)
    for ruby, rows in grouped.items():
        node = index[keys[ruby]]
        shards[node >> SHARD_SHIFT].append((node & (ENTRIES_PER_SHARD - 1), ruby, rows))
    for shard, items in shards.items():
        (out / f"user{shard}.loudstxt3").write_bytes(loudstxt3(items))
    return sum(len(rows) for rows in grouped.values())


def main(emoji_dir, frequency, overrides, charid, out):
    table = latest_emoji_table(emoji_dir)
    count = write_user_dictionary(score_entries(table, frequency, overrides), charid, Path(out))
    print(f"{table.name}: {count} entries")


if __name__ == "__main__":
    main(*sys.argv[1:])
