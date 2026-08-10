use strict;
use warnings;
use Test::More;
use FindBin ();
use lib "$FindBin::RealBin/../lib";

my @modules = qw(
    Treegen2
    Treegen2::Config
    Treegen2::Ignore
    Treegen2::Model
    Treegen2::JSONLite
    Treegen2::Descriptions
    Treegen2::Scanner
    Treegen2::Escape
    Treegen2::Renderer::Ascii
    Treegen2::Renderer::Collapsible
    Treegen2::Renderer::Svg
    Treegen2::Renderer
    Treegen2::Readme
    Treegen2::CLI
);

plan tests => scalar(@modules);

for my $module (@modules) {
    require_ok($module);
}
