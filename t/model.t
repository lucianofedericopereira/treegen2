use strict;
use warnings;
use Test::More;
use FindBin ();
use lib "$FindBin::RealBin/../lib";

use Treegen2::Model qw(new_node sorted_children iter_rows);

my $file_b = new_node(name => 'b.txt', path => 'b.txt', is_dir => 0);
my $file_a = new_node(name => 'A.txt', path => 'A.txt', is_dir => 0);
my $dir_z  = new_node(name => 'zdir', path => 'zdir', is_dir => 1);
my $dir_a  = new_node(name => 'adir', path => 'adir', is_dir => 1);

my $root = new_node(
    name => '.', path => '', is_dir => 1,
    children => [ $file_b, $file_a, $dir_z, $dir_a ],
);

my @sorted = sorted_children($root);
is_deeply(
    [ map { $_->{name} } @sorted ],
    ['adir', 'zdir', 'A.txt', 'b.txt'],
    'directories sort before files; each group is case-insensitive alphabetical'
);

push @{ $dir_a->{children} }, new_node(name => 'inner.txt', path => 'adir/inner.txt', is_dir => 0);

my $rows = iter_rows($root);
is(scalar(@$rows), 5, 'iter_rows flattens the whole tree, excluding the root itself');

my ($adir_row) = grep { $_->{node}{name} eq 'adir' } @$rows;
is($adir_row->{depth}, 0, 'top-level entries are at depth 0');
ok(!$adir_row->{is_last}, 'adir is not last among its siblings (zdir, A.txt, b.txt follow)');

my ($inner_row) = grep { $_->{node}{name} eq 'inner.txt' } @$rows;
is($inner_row->{depth}, 1, 'nested entry is one level deeper');
ok($inner_row->{is_last}, 'inner.txt is the only (and thus last) child of adir');
is_deeply($inner_row->{ancestors_last}, [0], 'ancestors_last records that adir was not last');

my ($b_row) = grep { $_->{node}{name} eq 'b.txt' } @$rows;
ok($b_row->{is_last}, 'b.txt is the last top-level entry');

done_testing();
