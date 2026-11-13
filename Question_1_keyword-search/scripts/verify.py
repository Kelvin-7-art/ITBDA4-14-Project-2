#!/usr/bin/env python3
"""Independent standard-library oracle: compare every Hadoop occurrence."""
import collections
import pathlib
import re
import sys
import unicodedata

source, output, keyword = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
def word(c):
    return c == '_' or unicodedata.category(c)[0] in 'LMN'
expected = []
for f in sorted(source.rglob('*.txt')):
    # Only CR/LF delimit lines, like Hadoop; blank lines retain their numbers.
    lines = re.split(r'\r\n|\r|\n', f.read_bytes().decode('utf-8-sig'))
    for row, line in enumerate(lines, 1):
        for m in re.finditer(re.escape(keyword), line, re.IGNORECASE):
            if (m.start() == 0 or not word(line[m.start()-1])) and (m.end() == len(line) or not word(line[m.end()])):
                expected.append((f.name, row, m.start()+1))
actual = []
for part in sorted(output.glob('part-r-*')):
    for line in part.read_text().splitlines():
        name, row, col = line.split('\t')
        actual.append((pathlib.PurePosixPath(name).name, int(row), int(col)))
assert (output / '_SUCCESS').exists(), 'Hadoop success marker missing'
assert collections.Counter(expected) == collections.Counter(actual), (expected, actual)
print(f'PASS: {keyword!r}: {len(actual)} occurrences; every document, row and column agrees.')
for name, count in sorted(collections.Counter(x[0] for x in actual).items()):
    print(f'{name}: {count}')
