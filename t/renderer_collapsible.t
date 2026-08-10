use strict;
use warnings;
use Test::More tests => 10;
use FindBin ();
use lib "$FindBin::RealBin/../lib";

use Treegen2::Config qw(new_options);
use Treegen2::Model qw(new_node);
use Treegen2::Renderer::Collapsible qw(render_collapsible);

my $main_py = new_node(name => 'main.py', path => 'src/main.py', is_dir => 0);
my $src     = new_node(name => 'src', path => 'src', is_dir => 1, children => [$main_py],
                        description => 'Source code');
my $readme  = new_node(name => 'README.md', path => 'README.md', is_dir => 0);
my $root    = new_node(name => '.', path => '', is_dir => 1, children => [$src, $readme]);

my $options = new_options();
my $html = render_collapsible($root, $options);

like($html, qr/<details open>/, 'directories are open <details> by default');
like($html, qr/<summary>.*src.*<\/summary>/s, 'directory summary contains its name');
like($html, qr/<em class="ft-note">Source code<\/em>/, 'directory description renders as a note');
like($html, qr/<li>.*main\.py.*<\/li>/s, 'nested file is listed inside a <ul><li>');
like($html, qr/README\.md/, 'top-level file is listed');

my $closed_options = new_options();
$closed_options->{open} = 0;
my $closed = render_collapsible($root, $closed_options);
unlike($closed, qr/<details open>/, 'open=false renders <details> without the open attribute');
like($closed, qr/<details>/, 'still emits a <details> element');

my $show_root_options = new_options();
$show_root_options->{show_root} = 1;
my $with_root = render_collapsible($root, $show_root_options);
like($with_root, qr/<strong>\.<\/strong>/, 'show_root wraps everything in a details for the root itself');

my $empty_root = new_node(name => '.', path => '', is_dir => 1, children => []);
is(render_collapsible($empty_root, $options), '<em>(empty)</em>', 'empty tree renders as (empty)');

# files and dirs interleave correctly: files between two dirs must still be
# grouped into one contiguous <ul>, not split by the dirs around them.
my $f1 = new_node(name => 'a.txt', path => 'a.txt', is_dir => 0);
my $f2 = new_node(name => 'b.txt', path => 'b.txt', is_dir => 0);
my $d1 = new_node(name => 'zdir', path => 'zdir', is_dir => 1, children => []);
my $mixed_root = new_node(name => '.', path => '', is_dir => 1, children => [$d1, $f1, $f2]);
my $mixed = render_collapsible($mixed_root, $options);
my @ul_count = ($mixed =~ /<ul>/g);
is(scalar(@ul_count), 1, 'files sorted after the one directory share a single <ul>');
