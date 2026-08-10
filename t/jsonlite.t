use strict;
use warnings;
use Test::More;
use FindBin ();
use lib "$FindBin::RealBin/../lib";

use Treegen2::JSONLite qw(decode_json_lite);

is_deeply(
    decode_json_lite('{"a": "b", "c": "d"}'),
    { a => 'b', c => 'd' },
    'flat object of strings'
);

is_deeply(
    decode_json_lite('{}'),
    {},
    'empty object'
);

is_deeply(
    decode_json_lite('[]'),
    [],
    'empty array'
);

is_deeply(
    decode_json_lite('[1, 2.5, -3, "x", true, false, null]'),
    [1, 2.5, -3, 'x', 1, 0, undef],
    'array of mixed scalar types'
);

is_deeply(
    decode_json_lite('{"nested": {"a": [1,2,3]}}'),
    { nested => { a => [1, 2, 3] } },
    'nested objects and arrays'
);

is(
    decode_json_lite('"line1\nline2\ttabbed \"quoted\" \\\\backslash"'),
    "line1\nline2\ttabbed \"quoted\" \\backslash",
    'string escapes: \\n \\t \\" \\\\'
);

is(decode_json_lite(q{"\u00e9"}), "\x{e9}", q{\\uXXXX escape decodes to the right codepoint});

is_deeply(
    decode_json_lite(" \n  { \"a\" : 1 }  \n"),
    { a => 1 },
    'leading/trailing whitespace around the document is ignored'
);

eval { decode_json_lite('{not valid json') };
like($@, qr/treegen2/, 'malformed JSON dies with a treegen2-prefixed error');

done_testing();
