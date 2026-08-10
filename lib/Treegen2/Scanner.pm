package Treegen2::Scanner;
use strict;
use warnings;

# Walk a directory into a Treegen2::Model Node tree.

use Cwd qw(abs_path);
use File::Spec;
use File::Basename qw(basename);

use Treegen2::Ignore;
use Treegen2::Model qw(new_node);
use Treegen2::Descriptions qw(load_descriptions get_description);

use Exporter 'import';
our @EXPORT_OK = qw(build_tree);

# Scan options->{directory} (resolved against $base) into a tree. Returns
# the root Node; its path is "" and its name is the resolved directory's
# display name.
sub build_tree {
    my ($base, $options) = @_;

    my $directory = defined $options->{directory} ? $options->{directory} : '.';
    my $joined = File::Spec->file_name_is_absolute($directory)
        ? $directory
        : File::Spec->catdir($base, $directory);
    my $root_dir = File::Spec->canonpath($joined);
    my $resolved = abs_path($root_dir);
    $root_dir = $resolved if defined $resolved;

    die "treegen2: not a directory: $root_dir\n" unless -d $root_dir;

    my $rules = Treegen2::Ignore::build(
        root          => $root_dir,
        extra         => $options->{exclude} || [],
        use_gitignore => $options->{use_gitignore},
    );
    my $descriptions = load_descriptions($options->{descriptions_file}, $base);

    my $root_name = ($directory eq '' || $directory eq '.') ? '.' : basename($root_dir);
    my $root = new_node(
        name        => $root_name,
        path        => '',
        is_dir      => 1,
        description => get_description($descriptions, ''),
    );
    _scan_into($root, $root_dir, '', 1, $options, $rules, $descriptions);
    return $root;
}

sub _scan_into {
    my ($parent, $directory, $rel_prefix, $depth, $options, $rules, $descriptions) = @_;

    return if $options->{max_depth} && $depth > $options->{max_depth};

    opendir(my $dh, $directory) or return; # permission/gone-away: skip quietly
    my @entries = grep { $_ ne '.' && $_ ne '..' } readdir($dh);
    closedir $dh;

    my %is_dir_cache = map { $_ => ( -d "$directory/$_" ? 1 : 0 ) } @entries;
    my @sorted = sort {
        $is_dir_cache{$b} <=> $is_dir_cache{$a}
            || lc($a) cmp lc($b)
    } @entries;

    for my $name (@sorted) {
        my $is_dir = $is_dir_cache{$name};
        next if $options->{dirs_only} && !$is_dir;

        my $rel_path = length($rel_prefix) ? "$rel_prefix/$name" : $name;
        next if Treegen2::Ignore::is_excluded($rules, $rel_path, $is_dir);

        my $node = new_node(
            name        => $name,
            path        => $rel_path,
            is_dir      => $is_dir,
            description => get_description($descriptions, $rel_path),
        );
        push @{ $parent->{children} }, $node;

        if ($is_dir) {
            _scan_into($node, "$directory/$name", $rel_path, $depth + 1,
                       $options, $rules, $descriptions);
        }
    }
}

1;
