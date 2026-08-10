use strict;
use warnings;
use Test::More tests => 7;
use File::Temp qw(tempdir);
use FindBin ();
use lib "$FindBin::RealBin/../lib";

use Treegen2::Descriptions qw(load_descriptions get_description);

my $dir = tempdir(CLEANUP => 1);

is_deeply(load_descriptions(undef, $dir), {}, 'no path given -> empty mapping');
is_deeply(load_descriptions('missing.json', $dir), {}, 'nonexistent file -> empty mapping');

open my $fh, '>:encoding(UTF-8)', "$dir/tree.json" or die $!;
print $fh <<'JSON';
{
  "brand-identity": "Core visual brand elements",
  "brand-identity/logos/": "Trailing slash is ignored"
}
JSON
close $fh;

my $map = load_descriptions('tree.json', $dir);
is(get_description($map, 'brand-identity'), 'Core visual brand elements', 'plain key lookup');
is(get_description($map, 'brand-identity/logos'), 'Trailing slash is ignored',
    'key with trailing slash normalizes to match a slash-less lookup');
is(get_description($map, '/brand-identity/'), 'Core visual brand elements',
    'lookup path with slashes is also normalized');
is(get_description($map, 'nope'), undef, 'missing path returns undef');

open my $bad_fh, '>:encoding(UTF-8)', "$dir/bad.json" or die $!;
print $bad_fh '["not", "an", "object"]';
close $bad_fh;
eval { load_descriptions('bad.json', $dir) };
like($@, qr/treegen2/, 'a JSON array (not object) at the top level dies');
