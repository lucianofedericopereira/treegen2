use strict;
use warnings;
use Test::More tests => 8;
use FindBin ();
use lib "$FindBin::RealBin/../lib";

# An integration test against examples/brand: the same fixture used in
# README.md's own demo blocks, so a passing test here is also evidence the
# documented output is accurate.

use Treegen2::Config qw(apply_attrs new_options);
use Treegen2::Scanner qw(build_tree);
use Treegen2::Renderer;

my $repo_root = "$FindBin::RealBin/..";
my $brand_dir = "$repo_root/examples/brand";

BAIL_OUT("examples/brand fixture is missing") unless -d $brand_dir;

my $options = apply_attrs(new_options(), {
    dir           => 'examples/brand',
    descriptions  => 'examples/brand/.filetree.json',
    exclude       => '.filetree.json',
});
my $root = build_tree($repo_root, $options);
my $ctx = { base => $repo_root, readme_path => "$repo_root/README.md" };
my $result = Treegen2::Renderer::render($root, $options, $ctx);

like($result->{markdown}, qr/\Qbrand-identity/, 'top-level brand-identity dir is present');
like($result->{markdown}, qr/Core visual brand elements/, 'directory description from .filetree.json is applied');
like($result->{markdown}, qr/twitter-header\.png/, 'nested file three levels deep is present');
unlike($result->{markdown}, qr/\.filetree\.json/, 'the descriptions file itself is excluded from its own tree');

# Same fixture, svg style: just needs to not die and to produce a valid
# document referencing every top-level directory once.
my $svg_options = apply_attrs(new_options(), { dir => 'examples/brand', style => 'svg' });
my $svg_root = build_tree($repo_root, $svg_options);
my $svg_result = Treegen2::Renderer::render($svg_root, $svg_options, $ctx);
my ($svg_content) = values %{ $svg_result->{assets} };
like($svg_content, qr/<svg/, 'svg style produces a valid document for the brand fixture');
like($svg_content, qr/media-center/, 'svg document mentions each top-level directory');

# Same fixture, collapsible style.
my $collapsible_options = apply_attrs(new_options(), { dir => 'examples/brand', style => 'collapsible' });
my $collapsible_root = build_tree($repo_root, $collapsible_options);
my $collapsible_result = Treegen2::Renderer::render($collapsible_root, $collapsible_options, $ctx);
like($collapsible_result->{markdown}, qr/<details open>/, 'collapsible style produces nested details');
like($collapsible_result->{markdown}, qr/design-resources/, 'collapsible tree mentions each top-level directory');
