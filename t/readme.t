use strict;
use warnings;
use Test::More tests => 24;
use File::Temp qw(tempdir);
use File::Path qw(mkpath);
use FindBin ();
use lib "$FindBin::RealBin/../lib";

use Treegen2::Config qw(new_options);
use Treegen2::Readme qw(parse_attributes process_text has_markers);

# --- parse_attributes ------------------------------------------------------
is_deeply(
    parse_attributes(q{dir="src" style=svg collapse max-depth='2'}),
    { dir => 'src', style => 'svg', collapse => 'true', 'max-depth' => '2' },
    'quoted, bare, and flag-only attributes all parse'
);

# --- fixture --------------------------------------------------------------
my $dir = tempdir(CLEANUP => 1);
mkpath("$dir/src");
open my $fh, '>', "$dir/src/main.py" or die $!;
close $fh;

my $ctx = { base => $dir, readme_path => "$dir/README.md" };
my $options = new_options();

# --- placeholder expansion --------------------------------------------------
{
    my $text = qq{# Title\n\n[[files dir="src"]]\n};
    my $result = process_text($text, $options, $ctx, 'files', 1);
    is($result->{blocks}, 1, 'one block rendered');
    ok($result->{changed}, 'text changed');
    like($result->{text}, qr/<!-- filetree:start dir="src" -->/, 'placeholder expands into a start marker');
    like($result->{text}, qr/<!-- filetree:end -->/, 'and an end marker');
    like($result->{text}, qr/main\.py/, 'tree content is present');
}

# --- idempotency: running twice on the already-expanded text is a no-op ----
{
    my $text = qq{# Title\n\n[[files dir="src"]]\n};
    my $once = process_text($text, $options, $ctx, 'files', 1);
    my $twice = process_text($once->{text}, $options, $ctx, 'files', 1);
    is($twice->{text}, $once->{text}, 'second pass produces byte-identical output');
    ok(!$twice->{changed}, 'second pass reports unchanged');
    is($twice->{blocks}, 1, 'marker block is still recognized and re-rendered in place');
}

# --- fence-awareness: markers/placeholders inside fenced code are untouched -
{
    my $text = "Docs:\n\n````markdown\n[[files dir=\"src\"]]\n<!-- filetree:start -->\n<!-- filetree:end -->\n````\n\nReal one: [[files dir=\"src\"]]\n";
    my $result = process_text($text, $options, $ctx, 'files', 1);
    is($result->{blocks}, 1, 'only the marker outside the fence is rendered');
    like($result->{text}, qr/````markdown\n\[\[files dir="src"\]\]/, 'placeholder inside the fence survives verbatim');
    unlike($result->{text}, qr/main\.py.*````/s, 'tree content was not injected inside the fence');
}

# --- fence-awareness: inline code spans are also left alone -----------------
{
    my $text = qq{Use \`[[files]]\` to insert a tree. Real one: [[files dir="src"]]\n};
    my $result = process_text($text, $options, $ctx, 'files', 1);
    is($result->{blocks}, 1, 'only the placeholder outside inline code is rendered');
    like($result->{text}, qr/`\[\[files\]\]`/, 'inline-code placeholder is untouched');
}

# --- marker block attrs are preserved and content is regenerated -----------
{
    my $existing = qq{<!-- filetree:start dir="src" style="ascii" -->\nSTALE CONTENT\n<!-- filetree:end -->\n};
    my $result = process_text($existing, $options, $ctx, 'files', 1);
    unlike($result->{text}, qr/STALE CONTENT/, 'stale body between markers is replaced');
    like($result->{text}, qr/dir="src" style="ascii"/, 'start marker attributes are preserved');
    like($result->{text}, qr/main\.py/, 'fresh tree content is present');
}

# --- disabling placeholder expansion leaves [[...]] tokens alone but still
#     regenerates explicit marker blocks (used for docs pages) --------------
{
    my $text = qq{[[files dir="src"]]\n\n<!-- filetree:start dir="src" -->\nold\n<!-- filetree:end -->\n};
    my $result = process_text($text, $options, $ctx, 'files', 0);
    is($result->{blocks}, 1, 'only the explicit marker block counts as a rendered block');
    like($result->{text}, qr/^\[\[files dir="src"\]\]/m, 'the literal placeholder token is left alone');
    like($result->{text}, qr/main\.py/, 'the explicit marker block was still regenerated');
}

# --- custom placeholder name -------------------------------------------------
{
    my $text = qq{[[tree dir="src"]]\n};
    my $result = process_text($text, $options, $ctx, 'tree', 1);
    is($result->{blocks}, 1, 'custom placeholder token name is recognized');
}

# --- has_markers --------------------------------------------------------------
ok(has_markers(qq{[[files]]\n}), 'has_markers detects a placeholder token');
ok(has_markers(qq{<!-- filetree:start -->\n<!-- filetree:end -->\n}), 'has_markers detects a marker block');
ok(!has_markers(qq{Nothing to see here.\n}), 'has_markers is false when there is nothing to expand');
