use strict;
use warnings;
use Test::More tests => 15;
use File::Temp qw(tempdir);
use File::Path qw(mkpath);
use FindBin ();
use lib "$FindBin::RealBin/../lib";

use Treegen2::Config qw(new_options apply_attrs);
use Treegen2::Scanner qw(build_tree);
use Treegen2::Model qw(sorted_children);

my $dir = tempdir(CLEANUP => 1);
mkpath("$dir/src/pkg");
mkpath("$dir/node_modules/dep");
open my $fh, '>', "$dir/src/pkg/main.py" or die $!; close $fh;
open $fh, '>', "$dir/src/README.md" or die $!; close $fh;
open $fh, '>', "$dir/node_modules/dep/index.js" or die $!; close $fh;
open $fh, '>', "$dir/.gitignore" or die $!;
print $fh "*.log\nbuild/\n";
close $fh;
open $fh, '>', "$dir/debug.log" or die $!; close $fh;
mkpath("$dir/build");
open $fh, '>', "$dir/build/output.bin" or die $!; close $fh;

# --- default scan: node_modules excluded by built-in default, .gitignore honored
my $root = build_tree($dir, new_options());
my @top = sorted_children($root);
my @top_names = map { $_->{name} } @top;
ok(!(grep { $_ eq 'node_modules' } @top_names), 'node_modules excluded by default excludes');
ok(!(grep { $_ eq 'build' } @top_names), 'build/ excluded via .gitignore');
ok(!(grep { $_ eq 'debug.log' } @top_names), '*.log excluded via .gitignore');
ok((grep { $_ eq 'src' } @top_names), 'src is present');

# --- use_gitignore => 0 restores build/ and debug.log, but not the hardcoded default excludes
my $no_gitignore = build_tree($dir, new_options(use_gitignore => 0));
my @names2 = map { $_->{name} } sorted_children($no_gitignore);
ok((grep { $_ eq 'build' } @names2), 'build/ reappears when use_gitignore is off');
ok((grep { $_ eq 'debug.log' } @names2), 'debug.log reappears when use_gitignore is off');
ok(!(grep { $_ eq 'node_modules' } @names2), 'node_modules is still excluded (hardcoded default)');

# --- dirs_only ---------------------------------------------------------------
my $src_root = build_tree($dir, apply_attrs(new_options(), { dir => 'src', 'dirs-only' => 'true' }));
my @src_names = map { $_->{name} } sorted_children($src_root);
is_deeply(\@src_names, ['pkg'], 'dirs-only hides README.md, keeps the pkg directory');

# --- max_depth -----------------------------------------------------------------
my $shallow = build_tree($dir, apply_attrs(new_options(), { dir => 'src', 'max-depth' => '1' }));
my ($pkg) = grep { $_->{name} eq 'pkg' } sorted_children($shallow);
ok(defined $pkg, 'pkg dir itself is still listed at max-depth=1');
is(scalar(@{ $pkg->{children} }), 0, 'max-depth=1 does not descend into pkg');

# --- extra excludes --------------------------------------------------------------
my $excluded = build_tree($dir, apply_attrs(new_options(), { dir => 'src', exclude => 'README.md' }));
my @src_names2 = map { $_->{name} } sorted_children($excluded);
is_deeply(\@src_names2, ['pkg'], 'per-marker exclude= removes README.md');

# --- root node naming ---------------------------------------------------------
is($root->{path}, '', 'root node path is empty string');
is($root->{name}, '.', 'root node name is "." when directory is "." (matches original tool)');

require File::Basename;
my $named_root = build_tree($dir, apply_attrs(new_options(), { dir => 'src' }));
is($named_root->{name}, 'src', 'root node name is the directory basename when scanning a subdir');

# --- error on a directory that does not exist -------------------------------
eval { build_tree($dir, apply_attrs(new_options(), { dir => 'does-not-exist' })) };
like($@, qr/not a directory/, 'scanning a missing directory dies with a clear message');
