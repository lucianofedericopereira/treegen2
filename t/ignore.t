use strict;
use warnings;
use Test::More;
use FindBin ();
use lib "$FindBin::RealBin/../lib";

use Treegen2::Ignore qw(build_matcher is_excluded glob_to_regex);

# --- bare names match at any depth ---------------------------------------
my $m = build_matcher('node_modules', '*.log');
ok(is_excluded($m, 'node_modules', 1), 'bare dir name excluded at root');
ok(is_excluded($m, 'src/node_modules', 1), 'bare dir name excluded at depth');
ok(is_excluded($m, 'debug.log', 0), 'glob *.log excludes matching file');
ok(!is_excluded($m, 'debug.txt', 0), 'debug.txt is not excluded');

# --- trailing slash restricts to directories ------------------------------
my $dir_only = build_matcher('build/');
ok(is_excluded($dir_only, 'build', 1), 'build/ excludes the directory');
ok(!is_excluded($dir_only, 'build', 0), 'build/ does not exclude a file named build');

# --- a rule containing "/" is anchored to the scan root -------------------
my $anchored = build_matcher('src/generated');
ok(is_excluded($anchored, 'src/generated', 1), 'anchored rule excludes exact path');
ok(!is_excluded($anchored, 'other/src/generated', 1),
    'anchored rule does not match at a different depth');
ok(!is_excluded($anchored, 'generated', 1), 'anchored rule does not match bare basename');

# --- negation ---------------------------------------------------------------
my $negated = build_matcher('*.log', '!important.log');
ok(is_excluded($negated, 'debug.log', 0), 'debug.log still excluded');
ok(!is_excluded($negated, 'important.log', 0), 'negation un-excludes important.log');

# --- ** across segments -----------------------------------------------------
my $globstar = build_matcher('**/fixtures/**');
ok(is_excluded($globstar, 'a/b/fixtures/c/d.txt', 0), '**/fixtures/** matches nested fixtures dirs');

# --- comments and blank lines are skipped -----------------------------------
my $with_comments = build_matcher('# a comment', '', '*.tmp');
ok(is_excluded($with_comments, 'x.tmp', 0), 'pattern after a comment/blank line still applies');

# --- default excludes are always present via build() ------------------------
require Treegen2::Ignore;
my $default_rules = Treegen2::Ignore::build(root => '/nonexistent-dir-xyz', extra => [], use_gitignore => 0);
ok(is_excluded($default_rules, '.git', 1), '.git is always excluded by default');
ok(is_excluded($default_rules, 'node_modules', 1), 'node_modules is always excluded by default');

# --- glob_to_regex sanity (used by CLI for --readme "**" patterns) ---------
my $md_body = glob_to_regex('**/*.md');
my $md_re = qr/^$md_body$/;
like('a/b/c.md', $md_re, '**/*.md matches a nested file via glob_to_regex');
like('c.md', $md_re, '**/*.md also matches a top-level file');

done_testing();
