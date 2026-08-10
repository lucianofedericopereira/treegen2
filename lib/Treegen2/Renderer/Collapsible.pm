package Treegen2::Renderer::Collapsible;
use strict;
use warnings;

# GitHub-native collapsible tree using nested <details> elements.
#
# Each directory becomes a <details> you can expand/collapse directly on
# GitHub; files are grouped into <ul> lists. Everything is plain HTML so it
# renders identically whether or not the surrounding Markdown parser is
# lenient.

use Treegen2::Model qw(sorted_children);
use Treegen2::Escape qw(escape_html);

use Exporter 'import';
our @EXPORT_OK = qw(render_collapsible);

use constant FOLDER_ICON => "\x{1F4C1}"; # folder
use constant FILE_ICON   => "\x{1F4C4}"; # page
use constant INDENT      => '  ';

# Build <span class="ft-name">icon name</span> <em class="ft-note">...</em>.
# No dash separator; the ft-name / ft-note split lets a host page align the
# notes into a column. On GitHub, which strips CSS, it simply renders inline.
sub _row {
    my ($icon, $name_html, $node) = @_;
    my $name = qq{<span class="ft-name">$icon $name_html</span>};
    return $name unless $node->{description};
    return $name . ' <em class="ft-note">' . escape_html($node->{description}) . '</em>';
}

sub _render_children; # forward decl: _render_dir and _render_children are mutually recursive

sub _render_dir {
    my ($node, $options, $indent) = @_;
    my @lines;
    my $open_attr = $options->{open} ? ' open' : '';
    my $summary = _row(FOLDER_ICON, '<strong>' . escape_html($node->{name}) . '</strong>', $node);
    push @lines, "$indent<details$open_attr>";
    push @lines, "$indent<summary>$summary</summary>";
    push @lines, @{ _render_children($node, $options, $indent . INDENT) };
    push @lines, "$indent</details>";
    return \@lines;
}

sub _render_children {
    my ($node, $options, $indent) = @_;
    my @children = sorted_children($node);
    my @lines;
    my @pending_files;

    my $flush_files = sub {
        return unless @pending_files;
        push @lines, "$indent<ul>";
        for my $file_node (@pending_files) {
            my $item = _row(FILE_ICON, escape_html($file_node->{name}), $file_node);
            push @lines, $indent . INDENT . "<li>$item</li>";
        }
        push @lines, "$indent</ul>";
        @pending_files = ();
    };

    for my $child (@children) {
        if ($child->{is_dir}) {
            $flush_files->();
            push @lines, @{ _render_dir($child, $options, $indent) };
        }
        else {
            push @pending_files, $child;
        }
    }
    $flush_files->();
    return \@lines;
}

# Render root as nested collapsible <details> blocks.
sub render_collapsible {
    my ($root, $options) = @_;
    if ($options->{show_root}) {
        return join("\n", @{ _render_dir($root, $options, '') });
    }
    my $lines = _render_children($root, $options, '');
    return @$lines ? join("\n", @$lines) : '<em>(empty)</em>';
}

1;
