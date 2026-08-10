use strict;
use warnings;
use Test::More;
use FindBin ();
use lib "$FindBin::RealBin/../lib";

use Treegen2::Config qw(new_options apply_attrs parse_bool split_list STYLE_ASCII);

# --- parse_bool ---------------------------------------------------------
for my $truthy (qw(1 true True TRUE yes YES on Y y)) {
    ok(parse_bool($truthy), "parse_bool('$truthy') is true");
}
ok(parse_bool(''), "parse_bool('') is true (bare attribute means present)");
for my $falsy (qw(0 false no off nope)) {
    ok(!parse_bool($falsy), "parse_bool('$falsy') is false");
}

# --- split_list ----------------------------------------------------------
is_deeply(
    [ split_list("a, b,c\nd") ],
    [ 'a', 'b', 'c', 'd' ],
    'split_list handles commas and newlines, trims blanks'
);
is_deeply([ split_list('') ], [], 'split_list of empty string is empty');

# --- new_options defaults -------------------------------------------------
my $defaults = new_options();
is($defaults->{directory}, '.', 'default directory');
is($defaults->{style}, STYLE_ASCII, 'default style is ascii');
is($defaults->{max_depth}, 0, 'default max_depth is 0 (unlimited)');
ok($defaults->{use_gitignore}, 'default use_gitignore is true');
ok($defaults->{open}, 'default open is true');
is($defaults->{color}, 'github', 'default color is github');

# --- apply_attrs: aliases, types, and non-mutation of base ---------------
my $base = new_options();
my $updated = apply_attrs($base, {
    dir          => 'src',
    'max-depth'  => '2',
    'dirs-only'  => 'true',
    colour       => 'green',
    exclude      => 'dist,*.tmp',
});
is($updated->{directory}, 'src', 'dir alias maps to directory');
is($updated->{max_depth}, 2, 'max-depth alias parses to integer');
ok($updated->{dirs_only}, 'dirs-only alias parses boolean');
is($updated->{color}, 'green', 'colour alias maps to color');
is_deeply($updated->{exclude}, ['dist', '*.tmp'], 'exclude alias splits list');
is($base->{directory}, '.', 'apply_attrs does not mutate the base options');
is_deeply($base->{exclude}, [], 'apply_attrs does not mutate the base exclude list');

# exclude is additive across successive apply_attrs calls
my $more = apply_attrs($updated, { ignore => 'node_modules' });
is_deeply($more->{exclude}, ['dist', '*.tmp', 'node_modules'], 'exclude accumulates');

# unknown attribute keys are ignored, not fatal
my $ignored = apply_attrs($base, { 'not-a-real-key' => 'whatever' });
is_deeply($ignored, $base, 'unknown attribute keys are silently ignored');

# a bare attribute (no "=value") means boolean true
my $bare = apply_attrs($base, { collapse => 'true' });
ok($bare->{collapse}, 'collapse=true sets the boolean field');

done_testing();
