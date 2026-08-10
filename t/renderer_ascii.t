use strict;
use warnings;
use Test::More;
use FindBin ();
use lib "$FindBin::RealBin/../lib";

use Treegen2::Config qw(new_options);
use Treegen2::Model qw(new_node);
use Treegen2::Renderer::Ascii qw(render_ascii render_ascii_html);

# root
#  - README.md            # Overview
#  - src/
#      - main.py

my $main_py = new_node(name => 'main.py', path => 'src/main.py', is_dir => 0);
my $src     = new_node(name => 'src', path => 'src', is_dir => 1, children => [$main_py]);
my $readme  = new_node(name => 'README.md', path => 'README.md', is_dir => 0, description => 'Overview');
my $root    = new_node(name => '.', path => '', is_dir => 1, children => [$src, $readme]);

my $options = new_options();
my $text = render_ascii($root, $options);

like($text, qr/\Qsrc\/\E/, 'directory names get a trailing slash');
like($text, qr/main\.py/, 'nested file is listed');
like($text, qr/README\.md\s+# Overview/, 'description is aligned as a trailing "# comment"');
like($text, qr/\x{251c}\x{2500}\x{2500} /, 'uses the tree-style connector for non-last entries');
like($text, qr/\x{2514}\x{2500}\x{2500} /, 'uses the corner connector for the last entry');

my $empty_root = new_node(name => '.', path => '', is_dir => 1, children => []);
is(render_ascii($empty_root, $options), '(empty)', 'an empty directory renders as "(empty)"');

my $shown_root = new_options();
$shown_root->{show_root} = 1;
my $with_root = render_ascii($root, $shown_root);
like($with_root, qr/^\.\//m, 'show_root prepends the root itself with no branch prefix');

# HTML variant
my $html = render_ascii_html($root, $options);
like($html, qr/<pre class="filetree-ascii">/, 'wraps output in a filetree-ascii <pre>');
like($html, qr/class="ft-dir"/, 'directory names get the ft-dir class');
like($html, qr/class="ft-file"/, 'file names get the ft-file class');
like($html, qr/class="ft-comment"/, 'descriptions get the ft-comment class');

my $unsafe = new_node(name => '<script>.txt', path => '<script>.txt', is_dir => 0);
my $unsafe_root = new_node(name => '.', path => '', is_dir => 1, children => [$unsafe]);
my $escaped = render_ascii_html($unsafe_root, $options);
unlike($escaped, qr/<script>\.txt/, 'file names are HTML-escaped in the HTML renderer');
like($escaped, qr/&lt;script&gt;\.txt/, 'escaped form is present');

done_testing();
