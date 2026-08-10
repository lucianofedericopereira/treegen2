package Treegen2::Config;
use strict;
use warnings;

# Options for a single tree block, plus helpers for merging marker
# attributes on top of action/CLI defaults. Values come from three layers
# (lowest priority first): built-in defaults below, action/CLI inputs, and
# per-marker attributes. Later layers win.

use Exporter 'import';
our @EXPORT_OK = qw(
    STYLE_ASCII STYLE_SVG STYLE_COLLAPSIBLE @STYLES
    @COLORS $DEFAULT_COLOR @COLOR_CHOICES
    new_options apply_attrs parse_bool split_list
);

use constant STYLE_ASCII       => 'ascii';
use constant STYLE_SVG         => 'svg';
use constant STYLE_COLLAPSIBLE => 'collapsible';

our @STYLES = (STYLE_ASCII, STYLE_SVG, STYLE_COLLAPSIBLE);

# Named folder colours for the SVG style (macOS-label-ish). The hex values
# (light + dark) live in Treegen2::Renderer::Svg.
our @COLORS = qw(blue green red orange yellow purple pink gray);

# "github" is a smart default that matches GitHub's own folder colour
# (Primer blue, theme-aware). It resolves to the "blue" palette entry.
our $DEFAULT_COLOR = 'github';
our @COLOR_CHOICES = ($DEFAULT_COLOR, @COLORS);

# Marker attribute name -> canonical option field name.
my %ALIASES = (
    'dir'              => 'directory',
    'directory'        => 'directory',
    'path'             => 'directory',
    'style'            => 'style',
    'depth'            => 'max_depth',
    'max-depth'        => 'max_depth',
    'max_depth'        => 'max_depth',
    'dirs-only'        => 'dirs_only',
    'dirs_only'        => 'dirs_only',
    'dirsonly'         => 'dirs_only',
    'exclude'          => 'exclude',
    'ignore'           => 'exclude',
    'gitignore'        => 'use_gitignore',
    'use-gitignore'    => 'use_gitignore',
    'use_gitignore'    => 'use_gitignore',
    'root'             => 'show_root',
    'show-root'        => 'show_root',
    'show_root'        => 'show_root',
    'desc'             => 'descriptions_file',
    'descriptions'     => 'descriptions_file',
    'descriptions-file'=> 'descriptions_file',
    'descriptions_file'=> 'descriptions_file',
    'svg'              => 'svg_output',
    'svg-output'       => 'svg_output',
    'svg_output'       => 'svg_output',
    'output'           => 'svg_output',
    'format'           => 'output_format',
    'output-format'    => 'output_format',
    'output_format'    => 'output_format',
    'color'            => 'color',
    'colour'           => 'color',
    'svg-color'        => 'color',
    'background'       => 'background',
    'bg'               => 'background',
    'svg-bg'           => 'background',
    'collapse'         => 'collapse',
    'open'             => 'open',
    'title'            => 'title',
);

my %BOOL_FIELDS  = map { $_ => 1 } qw(dirs_only use_gitignore show_root collapse open);
my %INT_FIELDS   = map { $_ => 1 } qw(max_depth);
my %TUPLE_FIELDS = map { $_ => 1 } qw(exclude);

# Return a fresh TreeOptions hashref with built-in defaults, overridden by
# any %overrides passed in (used to apply action/CLI-level inputs).
sub new_options {
    my (%overrides) = @_;
    my %options = (
        directory         => '.',
        style              => STYLE_ASCII,
        max_depth          => 0,       # 0 means "no limit".
        dirs_only          => 0,
        exclude            => [],
        use_gitignore      => 1,
        show_root          => 0,
        descriptions_file  => undef,
        # Output flavour: "markdown" or "html" for embedding in an HTML page.
        output_format      => 'markdown',
        svg_output         => 'assets/filetree.svg',
        color              => $DEFAULT_COLOR,
        background         => 'auto',
        collapse           => 0,
        open               => 1,
        title              => 'Project structure',
        %overrides,
    );
    return \%options;
}

# Parse a human-friendly truthy/falsey string.
sub parse_bool {
    my ($value) = @_;
    $value = '' unless defined $value;
    $value = lc(_trim($value));
    return $value =~ /^(1|true|yes|on|y|)$/ ? 1 : 0;
}

sub _trim {
    my ($s) = @_;
    $s =~ s/^\s+|\s+$//g;
    return $s;
}

# Split a comma/newline separated list, dropping blanks.
sub split_list {
    my ($value) = @_;
    my @out;
    for my $chunk (split /\n/, $value) {
        for my $piece (split /,/, $chunk) {
            my $trimmed = _trim($piece);
            push @out, $trimmed if length $trimmed;
        }
    }
    return @out;
}

# Return a *new* options hashref: a shallow copy of $base with marker
# %$attrs applied on top.
sub apply_attrs {
    my ($base, $attrs) = @_;
    my %options = %$base;
    $options{exclude} = [ @{ $base->{exclude} || [] } ];

    for my $raw_key (keys %$attrs) {
        my $raw_value = $attrs->{$raw_key};
        my $lc_key = lc(_trim($raw_key));
        (my $dashed = $lc_key) =~ s/_/-/g;
        my $field = $ALIASES{$dashed};
        $field = $ALIASES{$lc_key} unless defined $field;
        next unless defined $field;

        if ($BOOL_FIELDS{$field}) {
            $options{$field} = parse_bool($raw_value);
        }
        elsif ($INT_FIELDS{$field}) {
            next unless $raw_value =~ /^-?\d+$/;
            $options{$field} = int($raw_value);
        }
        elsif ($TUPLE_FIELDS{$field}) {
            $options{$field} = [ @{ $options{$field} || [] }, split_list($raw_value) ];
        }
        else {
            $options{$field} = $raw_value;
        }
    }
    return \%options;
}

1;
