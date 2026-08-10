package Treegen2::Renderer::Svg;
use strict;
use warnings;

# Render a directory tree to a themeable, responsive SVG image.
#
# The generated SVG:
#   * carries a viewBox plus intrinsic width/height so GitHub scales it down
#     to the container width without distortion (responsive);
#   * ships light and dark palettes lifted from GitHub's Primer design
#     tokens, switched with @media (prefers-color-scheme: dark) so it
#     matches whichever theme the reader is using;
#   * draws real folder/file glyphs and tree-style connector lines.
#
# Because GitHub strips inline <svg> from Markdown, the image is written to
# a file and embedded with a normal Markdown image reference (which GitHub
# renders and, thanks to its stylesheet, makes responsive for free).

use File::Spec;
use File::Basename qw(dirname);

use Treegen2::Model qw(iter_rows);
use Treegen2::Escape qw(escape_xml);

use Exporter 'import';
our @EXPORT_OK = qw(build_svg render_svg);

# --- Layout constants (all in SVG user units == px at 100% scale). --------
use constant FONT_SIZE   => 13;
use constant LINE_HEIGHT => 22;
use constant CHAR_WIDTH  => 7.8;  # Monospace advance width at FONT_SIZE.
use constant PAD_X       => 16;
use constant PAD_Y       => 14;
use constant INDENT      => 22;
use constant ICON_W      => 16;
use constant ICON_GAP    => 8;
use constant COMMENT_GAP => 22;   # Space between the longest name and the comment column.

sub _cx     { my ($depth) = @_; return PAD_X + $depth * INDENT + INDENT * 0.5; }
sub _icon_x { my ($depth) = @_; return PAD_X + ($depth + 1) * INDENT; }

sub _f1 { return sprintf('%.1f', $_[0]); }

sub _place_rows {
    my ($root, $options) = @_;
    my @rows;
    if ($options->{show_root}) {
        push @rows, { node => $root, depth => -1, is_last => 1, ancestors_last => [] };
    }
    for my $row (@{ iter_rows($root) }) {
        push @rows, {
            node => $row->{node}, depth => $row->{depth},
            is_last => $row->{is_last}, ancestors_last => $row->{ancestors_last},
        };
    }
    return \@rows;
}

# A folder silhouette with a tab on the upper-left. All commands are
# relative so the glyph can be dropped at any (x, y) offset.
sub _folder_glyph {
    my ($x, $y) = @_;
    my $d = sprintf('M%s %sh4.5l1.4 1.6h8.1v7.8h-14z', $x + 1, $y + 4);
    return qq{<path class="folder" d="$d"/>};
}

sub _file_glyph {
    my ($x, $y) = @_;
    my $body = sprintf('M%s %sh5l3 3v9h-8z', $x + 3.5, $y + 2);
    my $fold = sprintf('M%s %sv3h3', $x + 8.5, $y + 2);
    return qq{<path class="file" d="$body"/><path class="file-fold" d="$fold"/>};
}

# Build the SVG document as a string.
sub build_svg {
    my ($root, $options) = @_;
    my $rows = _place_rows($root, $options);

    # Geometry pre-pass. Names carry no trailing slash in the SVG; instead
    # the comments are aligned into a single column (like the ASCII
    # renderer), which is why they need no leading "#".
    my $text_x_of = sub { my ($depth) = @_; return _icon_x($depth) + ICON_W + ICON_GAP; };

    my @name_end = map { $text_x_of->($_->{depth}) + length($_->{node}{name}) * CHAR_WIDTH } @$rows;
    my @desc_indexes = grep { $rows->[$_]{node}{description} } 0 .. $#$rows;

    my $comment_col = 0.0;
    if (@desc_indexes) {
        my $max_name_end = $name_end[$desc_indexes[0]];
        for my $i (@desc_indexes) {
            $max_name_end = $name_end[$i] if $name_end[$i] > $max_name_end;
        }
        $comment_col = $max_name_end + COMMENT_GAP;
    }

    my @right_edges;
    for my $i (0 .. $#$rows) {
        my $desc = $rows->[$i]{node}{description};
        push @right_edges, $desc
            ? $comment_col + length($desc) * CHAR_WIDTH
            : $name_end[$i];
    }
    my $max_right = 0.0;
    for my $e (@right_edges) { $max_right = $e if $e > $max_right; }
    my $width  = int($max_right + PAD_X);
    my $row_count = @$rows ? scalar(@$rows) : 1;
    my $height = int(PAD_Y * 2 + $row_count * LINE_HEIGHT);

    my @parts;
    push @parts,
        qq{<svg xmlns="http://www.w3.org/2000/svg" }
      . qq{width="$width" height="$height" }
      . qq{viewBox="0 0 $width $height" }
      . qq{font-family="ui-monospace,SFMono-Regular,Menlo,Consolas,monospace" }
      . qq{role="img" aria-label="} . escape_xml($options->{title}) . qq{">};
    push @parts, _style($options->{color});

    my $background = lc(_trim($options->{background}));
    if ($background eq 'transparent' || $background eq 'none') {
        # No backdrop — the tree blends into whatever contains it.
    }
    elsif ($background eq '' || $background eq 'auto' || $background eq 'github') {
        # Theme-aware framed panel (GitHub-matched light/dark).
        push @parts, sprintf(
            '<rect x="0.5" y="0.5" width="%s" height="%s" rx="6" class="bg"/>',
            $width - 1, $height - 1);
    }
    else {
        push @parts, sprintf(
            '<rect x="0.5" y="0.5" width="%s" height="%s" rx="6" fill="%s"/>',
            $width - 1, $height - 1, escape_xml($options->{background}));
    }

    my (@connectors, @icons, @labels);

    for my $index (0 .. $#$rows) {
        my $row = $rows->[$index];
        my $row_top = PAD_Y + $index * LINE_HEIGHT;
        my $row_mid = $row_top + LINE_HEIGHT / 2;
        my $depth = $row->{depth};

        if ($depth >= 0) {
            my @ancestors = @{ $row->{ancestors_last} };
            for my $level (0 .. $#ancestors) {
                next if $ancestors[$level];
                my $x = _cx($level);
                push @connectors, sprintf(
                    '<line class="guide" x1="%s" y1="%s" x2="%s" y2="%s"/>',
                    _f1($x), $row_top, _f1($x), $row_top + LINE_HEIGHT);
            }
            my $cx = _cx($depth);
            my $icon_x = _icon_x($depth);
            if ($row->{is_last}) {
                my $r = 6.0;
                push @connectors, sprintf(
                    '<path class="guide" fill="none" d="M%s %s V%s Q%s %s %s %s H%s"/>',
                    _f1($cx), $row_top, _f1($row_mid - $r), _f1($cx), _f1($row_mid),
                    _f1($cx + $r), _f1($row_mid), _f1($icon_x));
            }
            else {
                push @connectors, sprintf(
                    '<line class="guide" x1="%s" y1="%s" x2="%s" y2="%s"/>',
                    _f1($cx), _f1($row_top), _f1($cx), _f1($row_top + LINE_HEIGHT));
                push @connectors, sprintf(
                    '<line class="guide" x1="%s" y1="%s" x2="%s" y2="%s"/>',
                    _f1($cx), _f1($row_mid), _f1($icon_x), _f1($row_mid));
            }
        }

        my $icon_x = _icon_x($depth);
        my $icon_y = $row_mid - ICON_W / 2;
        push @icons, ($row->{node}{is_dir}
            ? _folder_glyph($icon_x, $icon_y)
            : _file_glyph($icon_x, $icon_y));

        my $text_x = $icon_x + ICON_W + ICON_GAP;
        my $name_class = $row->{node}{is_dir} ? 'name-dir' : 'name-file';
        my $label = qq{<text y="} . _f1($row_mid) . qq{" dominant-baseline="central" font-size="}
            . FONT_SIZE . qq{"><tspan class="$name_class" x="} . _f1($text_x) . qq{">}
            . escape_xml($row->{node}{name}) . qq{</tspan>};
        if ($row->{node}{description}) {
            $label .= qq{<tspan class="comment" x="} . _f1($comment_col) . qq{">}
                . escape_xml($row->{node}{description}) . qq{</tspan>};
        }
        $label .= '</text>';
        push @labels, $label;
    }

    # A single node dot at the very top of the root spine.
    my $root_index;
    for my $i (0 .. $#$rows) {
        if ($rows->[$i]{depth} == 0) { $root_index = $i; last; }
    }
    if (defined $root_index) {
        my $cy = PAD_Y + $root_index * LINE_HEIGHT;
        push @connectors, sprintf('<circle class="dot" cx="%s" cy="%s" r="2"/>', _f1(_cx(0)), $cy);
    }

    push @parts, @connectors, @icons, @labels;
    push @parts, '</svg>';
    return join("\n", @parts);
}

# Build the SVG, schedule it for writing, and return the embed markup.
# Returns { markdown => ..., assets => { $abs_path => $svg_content } }.
sub render_svg {
    my ($root, $options, $base, $readme_path) = @_;

    my $svg = build_svg($root, $options);

    my $joined = File::Spec->file_name_is_absolute($options->{svg_output})
        ? $options->{svg_output}
        : File::Spec->catfile($base, $options->{svg_output});
    my $svg_abs = File::Spec->canonpath($joined);

    my $readme_dir = dirname($readme_path);
    my $rel = File::Spec->abs2rel($svg_abs, $readme_dir);
    my $rel_posix = $rel;
    $rel_posix =~ s{\\}{/}g if File::Spec->can('canonpath') && $^O eq 'MSWin32';

    my $alt = escape_xml($options->{title});
    my $embed;
    if (lc($options->{output_format}) eq 'html' || lc($options->{output_format}) eq 'htm') {
        $embed = qq{<img class="filetree-svg" src="$rel_posix" alt="$alt" />};
    }
    else {
        $embed = "![$alt]($rel_posix)";
    }
    return { markdown => $embed, assets => { $svg_abs => $svg } };
}

sub _trim {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/^\s+|\s+$//g;
    return $s;
}

# Light + dark colours for each named scheme:
# [folder_l, name_l, comment_l, line_l, folder_d, name_d, comment_d, line_d]
my %PALETTE = (
    github => ['#54aeff','#0969da','#59636e','#8c959f','#388bfd','#2f81f7','#8b949e','#6e7681'],
    blue   => ['#54aeff','#0969da','#5b6b7d','#94b8e0','#388bfd','#2f81f7','#8b98a8','#4d6480'],
    green  => ['#4ac26b','#1a7f37','#5c6f5c','#93c4a0','#3fb950','#57d472','#8fa891','#4f6b57'],
    red    => ['#ff8182','#cf222e','#86635f','#e0a3a3','#f85149','#ff7b72','#b39894','#7d5453'],
    orange => ['#fd9843','#bc4c00','#806a52','#e6b98c','#ec8e2c','#e0975a','#b39d84','#7d6144'],
    yellow => ['#eac54f','#9a6700','#756a4c','#d8c88a','#d4a72c','#e3b341','#ab9f80','#6e6440'],
    purple => ['#c297ff','#8250df','#6d6280','#c3aee0','#a371f7','#b083f0','#9c93ad','#63577a'],
    pink   => ['#ff9bce','#bf3989','#856072','#e8b3cf','#f778ba','#ff9bce','#b394a6','#7d5468'],
    gray   => ['#afb8c1','#59636e','#59636e','#afb8c1','#6e7681','#8b949e','#8b949e','#6e7681'],
);
my %COLOR_ALIASES = (auto => 'github');
my $FALLBACK_COLOR = 'github';

# GitHub-Primer-based <style> block with a chosen scheme colour.
sub _style {
    my ($color) = @_;
    $color = '' unless defined $color;
    my $lc_color = lc $color;
    my $key = exists $COLOR_ALIASES{$lc_color} ? $COLOR_ALIASES{$lc_color} : $lc_color;
    my $p = exists $PALETTE{$key} ? $PALETTE{$key} : $PALETTE{$FALLBACK_COLOR};
    my ($folder_l, $name_l, $comment_l, $line_l, $folder_d, $name_d, $comment_d, $line_d) = @$p;

    my $css = <<"CSS";
<style>
  .bg { fill: #ffffff; stroke: #d1d9e0; }
  .name-dir { fill: $name_l; font-weight: 600; }
  .name-file { fill: #1f2328; }
  .comment { fill: $comment_l; }
  .folder { fill: $folder_l; }
  .file { fill: #eaeef2; stroke: #afb8c1; stroke-width: 1; }
  .file-fold { fill: none; stroke: #afb8c1; stroke-width: 1; }
  .guide { stroke: $line_l; stroke-width: 1; }
  .dot { fill: $line_l; }
  \@media (prefers-color-scheme: dark) {
    .bg { fill: #0d1117; stroke: #30363d; }
    .name-dir { fill: $name_d; }
    .name-file { fill: #e6edf3; }
    .comment { fill: $comment_d; }
    .folder { fill: $folder_d; }
    .file { fill: #21262d; stroke: #484f58; }
    .file-fold { stroke: #484f58; }
    .guide { stroke: $line_d; }
    .dot { fill: $line_d; }
  }
</style>
CSS
    chomp $css;
    return $css;
}

1;
