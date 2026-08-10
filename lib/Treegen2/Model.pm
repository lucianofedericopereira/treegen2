package Treegen2::Model;
use strict;
use warnings;

# Core data model shared across the scanner and renderers.
#
# A Node is a plain hashref:
#   name        => bare file or directory name (no path separators)
#   path        => POSIX-style path relative to the scan root ('' for the root)
#   is_dir      => true/false
#   children    => arrayref of child Nodes
#   description => optional human-written note shown next to the entry

use Exporter 'import';
our @EXPORT_OK = qw(new_node sorted_children iter_rows);

sub new_node {
    my (%args) = @_;
    return {
        name        => $args{name},
        path        => $args{path},
        is_dir      => $args{is_dir} ? 1 : 0,
        children    => $args{children} || [],
        description => $args{description},
    };
}

# Return children with directories first, then alphabetical by name
# (case-insensitive) — mirrors the Python sort key (not is_dir, name.lower()).
sub sorted_children {
    my ($node) = @_;
    return sort {
        $b->{is_dir} <=> $a->{is_dir}
            || lc($a->{name}) cmp lc($b->{name})
    } @{ $node->{children} };
}

# Flatten root's descendants (not the root itself) into display rows.
# Returns an arrayref of {node, depth, is_last, ancestors_last => [...]}.
sub iter_rows {
    my ($root) = @_;
    my @rows;

    my $walk;
    $walk = sub {
        my ($node, $ancestors) = @_;
        my @children = sorted_children($node);
        my $count = scalar @children;
        for my $index (0 .. $count - 1) {
            my $child = $children[$index];
            my $is_last = ($index == $count - 1) ? 1 : 0;
            push @rows, {
                node           => $child,
                depth          => scalar @$ancestors,
                is_last        => $is_last,
                ancestors_last => [ @$ancestors ],
            };
            $walk->($child, [ @$ancestors, $is_last ]);
        }
    };
    $walk->($root, []);
    return \@rows;
}

1;
