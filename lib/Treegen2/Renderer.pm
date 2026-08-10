package Treegen2::Renderer;
use strict;
use warnings;

# Renderers turn a Treegen2::Model Node tree into Markdown (or HTML). Each
# one returns a result hashref: { markdown => ..., assets => { path => content } }
# — only the SVG renderer populates assets.

use Treegen2::Config qw(STYLE_ASCII STYLE_SVG STYLE_COLLAPSIBLE);
use Treegen2::Renderer::Ascii qw(render_ascii render_ascii_html);
use Treegen2::Renderer::Collapsible qw(render_collapsible);
use Treegen2::Renderer::Svg qw(render_svg);

use Exporter 'import';
our @EXPORT_OK = qw(is_html_format render);

# Whether output should be HTML (styled) rather than Markdown.
sub is_html_format {
    my ($options) = @_;
    my $fmt = defined $options->{output_format} ? lc($options->{output_format}) : '';
    return ($fmt eq 'html' || $fmt eq 'htm') ? 1 : 0;
}

sub _wrap_details {
    my ($inner, $title, $is_open) = @_;
    my $open_attr = $is_open ? ' open' : '';
    return "<details$open_attr>\n<summary>$title</summary>\n\n$inner\n\n</details>";
}

# Render root according to options->{style} and the output format. $ctx is
# { base => ..., readme_path => ... }.
sub render {
    my ($root, $options, $ctx) = @_;
    my $style = $options->{style};
    my $result;

    if ($style eq STYLE_ASCII) {
        if (is_html_format($options)) {
            $result = { markdown => render_ascii_html($root, $options), assets => {} };
        }
        else {
            $result = { markdown => "```\n" . render_ascii($root, $options) . "\n```", assets => {} };
        }
    }
    elsif ($style eq STYLE_COLLAPSIBLE) {
        $result = { markdown => render_collapsible($root, $options), assets => {} };
    }
    elsif ($style eq STYLE_SVG) {
        $result = render_svg($root, $options, $ctx->{base}, $ctx->{readme_path});
        $result->{assets} ||= {};
    }
    else {
        die "treegen2: unknown style: '$style'\n";
    }

    if ($options->{collapse}) {
        $result->{markdown} = _wrap_details($result->{markdown}, $options->{title}, $options->{open});
    }
    return $result;
}

1;
