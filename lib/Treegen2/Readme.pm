package Treegen2::Readme;
use strict;
use warnings;

# Find tree markers/placeholders in a Markdown (or HTML) file and splice in
# the rendered tree.
#
# Two authoring styles are supported:
#
#   * Placeholder (easy insert): a one-off token, [[files]] by default,
#     optionally carrying attributes: [[files dir="src" style="svg"]]. On
#     the first run it is expanded into a managed marker block.
#   * Marker block (idempotent): a <!-- filetree:start ... --> /
#     <!-- filetree:end --> pair. Everything between the markers is
#     regenerated on every run; the start line's attributes are preserved.
#
# Processing is fence-aware: marker blocks and [[...]] placeholders inside
# fenced code blocks or inline code spans are left untouched, so the syntax
# can be safely documented in the very same file it operates on.

use Cwd qw(abs_path);

use Treegen2::Config qw(apply_attrs);
use Treegen2::Renderer;
use Treegen2::Scanner qw(build_tree);

use Exporter 'import';
our @EXPORT_OK = qw(parse_attributes process_text process_file has_markers);

my $INLINE_CODE_RE = qr/`[^`]*`/;

# Match "key" or key="value" / key='value' / key=bareword tokens. No named
# captures (kept Perl-5.8-safe): group 1 = key, 2 = dq value, 3 = sq value,
# 4 = bare value.
my $ATTR_RE = qr/
    ([\w-]+)
    (?:\s*=\s*
        (?: "([^"]*)"
          | '([^']*)'
          | ([^\s"'\]]+)
        )
    )?
/x;

# Parse an attribute string like: dir="src" style=svg collapse
sub parse_attributes {
    my ($text) = @_;
    my %attrs;
    while ($text =~ /$ATTR_RE/g) {
        my ($key, $dq, $sq, $bare) = ($1, $2, $3, $4);
        my $value;
        if    (defined $dq)   { $value = $dq; }
        elsif (defined $sq)   { $value = $sq; }
        elsif (defined $bare) { $value = $bare; }
        else                  { $value = 'true'; }
        $attrs{$key} = $value;
    }
    return \%attrs;
}

sub _placeholder_re {
    my ($name) = @_;
    my $escaped = quotemeta($name);
    return qr/\[\[\s*$escaped([^\]]*)\]\]/i;
}

my $START_RE = qr/<!--\s*filetree:start(.*?)-->/i;
my $END_RE   = qr/<!--\s*filetree:end\s*-->/i;

sub _render_block {
    my ($attrs_text, $base_options, $ctx, $assets) = @_;
    my $attrs = parse_attributes($attrs_text);
    my $options = apply_attrs($base_options, $attrs);
    my $root = build_tree($ctx->{base}, $options);
    my $result = Treegen2::Renderer::render($root, $options, $ctx);
    for my $path (keys %{ $result->{assets} }) {
        $assets->{$path} = $result->{assets}{$path};
    }
    return $result->{markdown};
}

sub _start_marker {
    my ($attrs_text) = @_;
    my $stripped = defined $attrs_text ? $attrs_text : '';
    $stripped =~ s/^\s+|\s+$//g;
    return length($stripped)
        ? "<!-- filetree:start $stripped -->"
        : '<!-- filetree:start -->';
}

# If the (already left-stripped) line opens a code fence, return an arrayref
# [char, length]; otherwise undef. Follows CommonMark closely enough for
# nesting: a backtick fence's info string may not itself contain a backtick.
sub _fence_open {
    my ($stripped_line) = @_;
    return undef unless $stripped_line =~ /^(`{3,}|~{3,})(.*)$/;
    my ($seq, $info) = ($1, $2);
    my $char = substr($seq, 0, 1);
    return undef if $char eq '`' && index($info, '`') >= 0;
    return [ $char, length($seq) ];
}

# Whether $stripped_line closes a fence opened with $length repeats of $char.
sub _fence_closes {
    my ($stripped_line, $char, $length) = @_;
    my $pattern = quotemeta($char) . '{' . $length . ',}';
    return $stripped_line =~ /^$pattern\s*$/ ? 1 : 0;
}

# Blank out inline code spans (keeping length) so markers inside `code` are
# not mistaken for real ones.
sub _mask_inline_code {
    my ($line) = @_;
    $line =~ s/$INLINE_CODE_RE/' ' x length($&)/ge;
    return $line;
}

sub process_text {
    my ($text, $base_options, $ctx, $placeholder, $enable_placeholder) = @_;
    $placeholder = 'files' unless defined $placeholder;
    $enable_placeholder = 1 unless defined $enable_placeholder;

    my %assets;
    my $count = 0;
    my $ph_re = _placeholder_re($placeholder);

    my $render_marker = sub {
        my ($attrs_text) = @_;
        $count++;
        my $content = _render_block($attrs_text, $base_options, $ctx, \%assets);
        return _start_marker($attrs_text) . "\n" . $content . "\n<!-- filetree:end -->";
    };

    my $expand_placeholders = sub {
        my ($line) = @_;
        # Split keeps captured inline-code spans in the result at odd
        # indices (0=gap,1=code,2=gap,...); only substitute in the gaps.
        my @segments = split /($INLINE_CODE_RE)/, $line;
        my $rebuilt = '';
        for my $i (0 .. $#segments) {
            my $segment = $segments[$i];
            if ($i % 2 == 1) {
                $rebuilt .= $segment;
            }
            else {
                $segment =~ s/$ph_re/$render_marker->($1)/ge;
                $rebuilt .= $segment;
            }
        }
        return $rebuilt;
    };

    my @lines = split /\n/, $text;
    my @out;
    my $index = 0;
    my $fence; # undef, or [char, length]

    while ($index < @lines) {
        my $line = $lines[$index];
        (my $stripped = $line) =~ s/^\s+//;

        if (defined $fence) {
            push @out, $line;
            $fence = undef if _fence_closes($stripped, $fence->[0], $fence->[1]);
            $index++;
            next;
        }

        my $masked = _mask_inline_code($line);
        if ($masked =~ /$START_RE/) {
            my $attrs_text = $1;
            my $end_of_start = $+[0];

            if (substr($masked, $end_of_start) =~ /$END_RE/) {
                push @out, $render_marker->($attrs_text);
                $index++;
                next;
            }

            my $end = $index + 1;
            while ($end < @lines && _mask_inline_code($lines[$end]) !~ /$END_RE/) {
                $end++;
            }
            push @out, $render_marker->($attrs_text);
            $index = ($end < @lines) ? $end + 1 : $index + 1;
            next;
        }

        my $opened = _fence_open($stripped);
        if (defined $opened) {
            $fence = $opened;
            push @out, $line;
            $index++;
            next;
        }

        push @out, $enable_placeholder ? $expand_placeholders->($line) : $line;
        $index++;
    }

    my $new_text = join("\n", @out);
    if ($text =~ /\n$/ && $new_text !~ /\n$/) {
        $new_text .= "\n";
    }

    return {
        text    => $new_text,
        assets  => \%assets,
        changed => ($new_text ne $text) ? 1 : 0,
        blocks  => $count,
    };
}

# Whether $text contains any marker block or placeholder token.
sub has_markers {
    my ($text, $placeholder) = @_;
    $placeholder = 'files' unless defined $placeholder;
    my $ph_re = _placeholder_re($placeholder);
    return ($text =~ /$START_RE/ || $text =~ /$ph_re/) ? 1 : 0;
}

# Process a single file on disk (does not write it back).
sub process_file {
    my ($path, $base_options, $base, $placeholder, $enable_placeholder) = @_;

    open my $fh, '<:encoding(UTF-8)', $path
        or die "treegen2: cannot read $path: $!\n";
    local $/;
    my $text = <$fh>;
    close $fh;

    my $abs_path = abs_path($path);
    $abs_path = $path unless defined $abs_path;
    my $ctx = { base => $base, readme_path => $abs_path };

    return process_text($text, $base_options, $ctx, $placeholder, $enable_placeholder);
}

1;
