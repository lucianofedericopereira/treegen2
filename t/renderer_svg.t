use strict;
use warnings;
use Test::More;
use FindBin ();
use lib "$FindBin::RealBin/../lib";

use Treegen2::Config qw(new_options);
use Treegen2::Model qw(new_node);
use Treegen2::Renderer::Svg qw(build_svg render_svg);

my $main_py = new_node(name => 'main.py', path => 'src/main.py', is_dir => 0,
                        description => 'Entry point');
my $src     = new_node(name => 'src', path => 'src', is_dir => 1, children => [$main_py]);
my $root    = new_node(name => '.', path => '', is_dir => 1, children => [$src]);

my $options = new_options();
my $svg = build_svg($root, $options);

like($svg, qr/^<svg xmlns="http:\/\/www\.w3\.org\/2000\/svg"/, 'starts with an <svg> root element');
like($svg, qr/<\/svg>$/, 'ends with the closing tag');
like($svg, qr/viewBox="0 0 \d+ \d+"/, 'has a numeric viewBox');
like($svg, qr/prefers-color-scheme: dark/, 'ships a dark-mode media query');
like($svg, qr/Entry point/, 'description text is embedded');
like($svg, qr/class="folder"/, 'draws a folder glyph for the directory');
like($svg, qr/class="file"/, 'draws a file glyph for the file');

# Colour palette selection
my $green_opts = new_options();
$green_opts->{color} = 'green';
my $green_svg = build_svg($root, $green_opts);
like($green_svg, qr/#1a7f37/, 'green palette hex value is used when color=green');

my $unknown_opts = new_options();
$unknown_opts->{color} = 'not-a-real-color';
my $fallback_svg = build_svg($root, $unknown_opts);
like($fallback_svg, qr/#0969da/, 'unknown color name falls back to the github palette');

# Background handling
my $transparent_opts = new_options();
$transparent_opts->{background} = 'transparent';
my $transparent_svg = build_svg($root, $transparent_opts);
unlike($transparent_svg, qr/class="bg"/, 'transparent background omits the backdrop rect');

my $custom_bg_opts = new_options();
$custom_bg_opts->{background} = '#ff00ff';
my $custom_bg_svg = build_svg($root, $custom_bg_opts);
like($custom_bg_svg, qr/fill="#ff00ff"/, 'a custom CSS colour is used as a solid fill');

# XML-escaping of user-controlled text (title, names)
my $unsafe_opts = new_options();
$unsafe_opts->{title} = 'A & B <tag>';
my $unsafe_svg = build_svg($root, $unsafe_opts);
like($unsafe_svg, qr/aria-label="A &amp; B &lt;tag&gt;"/, 'title is XML-escaped in aria-label');

# render_svg: asset path + embed markup
my $result = render_svg($root, $options, '/repo', '/repo/README.md');
is($result->{markdown}, '![Project structure](assets/filetree.svg)',
    'markdown embed is a relative image reference from the readme dir');
ok(exists $result->{assets}{'/repo/assets/filetree.svg'}, 'asset is keyed by its absolute path');
like($result->{assets}{'/repo/assets/filetree.svg'}, qr/<svg/, 'asset content is the SVG document');

my $html_options = new_options();
$html_options->{output_format} = 'html';
my $html_result = render_svg($root, $html_options, '/repo', '/repo/docs/index.html');
like($html_result->{markdown}, qr/^<img class="filetree-svg"/, 'html format embeds an <img> tag');
like($html_result->{markdown}, qr/src="\.\.\/assets\/filetree\.svg"/,
    'relative path climbs out of the docs/ subdirectory correctly');

done_testing();
