package Treegen2::Renderer::Ascii;
use strict;
use warnings;

# Classic `tree`-style ASCII renderer with optional aligned descriptions.

use Treegen2::Model qw(iter_rows);
use Treegen2::Escape qw(escape_html);

use Exporter 'import';
our @EXPORT_OK = qw(render_ascii render_ascii_html);

# One flattened row: { branch, name, is_dir, description, width }.
sub _row_width {
    my ($row) = @_;
    return length($row->{branch}) + length($row->{name}) + ($row->{is_dir} ? 1 : 0);
}

sub _ascii_rows {
    my ($root, $options) = @_;
    my @rows;
    if ($options->{show_root}) {
        push @rows, { branch => '', name => $root->{name}, is_dir => $root->{is_dir},
                      description => $root->{description} };
    }
    for my $row (@{ iter_rows($root) }) {
        my $prefix = join '', map { $_ ? '    ' : "\x{2502}   " } @{ $row->{ancestors_last} };
        my $connector = $row->{is_last} ? "\x{2514}\x{2500}\x{2500} " : "\x{251c}\x{2500}\x{2500} ";
        push @rows, {
            branch      => $prefix . $connector,
            name        => $row->{node}{name},
            is_dir      => $row->{node}{is_dir},
            description => $row->{node}{description},
        };
    }
    for my $r (@rows) { $r->{width} = _row_width($r); }
    return \@rows;
}

# Render root's tree using tree-style connectors. Returns raw text (no code
# fence); the caller wraps it.
sub render_ascii {
    my ($root, $options) = @_;
    my $rows = _ascii_rows($root, $options);

    my $width = 0;
    for my $r (@$rows) {
        $width = $r->{width} if $r->{description} && $r->{width} > $width;
    }

    my @lines;
    for my $r (@$rows) {
        my $text = $r->{branch} . $r->{name} . ($r->{is_dir} ? '/' : '');
        if ($r->{description}) {
            my $pad = $width - length($text);
            $pad = 0 if $pad < 0;
            push @lines, $text . (' ' x $pad) . '  # ' . $r->{description};
        }
        else {
            push @lines, $text;
        }
    }
    return @lines ? join("\n", @lines) : '(empty)';
}

# Render the ASCII tree as a coloured <pre> for embedding in HTML. Same
# layout as render_ascii, but each part is wrapped in a span so a host page
# can colour connectors, names, slashes and comments independently
# (classes ft-branch, ft-dir / ft-file, ft-slash, ft-comment).
sub render_ascii_html {
    my ($root, $options) = @_;
    my $rows = _ascii_rows($root, $options);

    my $width = 0;
    for my $r (@$rows) {
        $width = $r->{width} if $r->{description} && $r->{width} > $width;
    }

    my @lines;
    for my $r (@$rows) {
        my $name_class = $r->{is_dir} ? 'ft-dir' : 'ft-file';
        my @parts;
        push @parts, '<span class="ft-branch">' . escape_html($r->{branch}) . '</span>';
        push @parts, qq{<span class="$name_class">} . escape_html($r->{name}) . '</span>';
        push @parts, '<span class="ft-slash">/</span>' if $r->{is_dir};
        if ($r->{description}) {
            my $pad = $width - $r->{width} + 2;
            $pad = 0 if $pad < 0;
            push @parts, (' ' x $pad) . '<span class="ft-comment"># '
                . escape_html($r->{description}) . '</span>';
        }
        push @lines, join('', @parts);
    }
    my $inner = @lines ? join("\n", @lines) : '(empty)';
    return qq{<pre class="filetree-ascii">$inner</pre>};
}

1;
