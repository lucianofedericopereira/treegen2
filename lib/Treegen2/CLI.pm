package Treegen2::CLI;
use strict;
use warnings;

# Command-line interface: bin/treegen2.
#
# Scans directories and updates one or more Markdown/HTML files in place.
# Designed to be driven either by a human locally or by the bundled
# GitHub Action.

use Getopt::Long qw(GetOptions);
use Cwd qw(abs_path);
use File::Spec;
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use File::Glob qw(bsd_glob);
use File::Find ();

use Treegen2;
use Treegen2::Config;
use Treegen2::Ignore qw(glob_to_regex);
use Treegen2::Readme;

use Exporter 'import';
our @EXPORT_OK = qw(run);

sub _format_for {
    my ($path, $chosen) = @_;
    return $chosen unless $chosen eq 'auto';
    return ($path =~ /\.html?$/i) ? 'html' : 'markdown';
}

# Expand one README pattern (literal path, single-level glob, or a "**"
# recursive glob) into the paths that currently exist on disk.
sub _glob_paths {
    my ($piece) = @_;
    return () unless length $piece;

    if ($piece !~ /[*?\[]/) {
        return (-e $piece) ? ($piece) : ();
    }
    if (index($piece, '**') >= 0) {
        return _glob_recursive($piece);
    }
    return bsd_glob($piece);
}

sub _glob_recursive {
    my ($piece) = @_;
    my @segments = split m{/}, $piece;
    my @prefix;
    while (@segments && $segments[0] !~ /[*?\[]/) {
        push @prefix, shift @segments;
    }
    my $root = @prefix ? join('/', @prefix) : '.';
    return () unless -d $root;

    my $regex_body = glob_to_regex($piece);
    my $regex = qr/^$regex_body$/;

    my @matches;
    File::Find::find({
        wanted => sub {
            my $rel = $File::Find::name;
            $rel =~ s{^\./}{};
            push @matches, $rel if $rel =~ $regex;
        },
        # Skip dotfiles/dotdirs (matches recursive-glob's usual "no hidden
        # entries unless asked for" convention, and keeps this out of .git).
        preprocess => sub { return grep { !/^\./ } @_ },
        no_chdir => 1,
    }, $root);
    return sort @matches;
}

sub _resolve_readmes {
    my (@patterns) = @_;
    my @paths;
    my %seen;

    for my $pattern (@patterns) {
        for my $line (split /\n/, $pattern) {
            for my $chunk (split /,/, $line) {
                (my $piece = $chunk) =~ s/^\s+|\s+$//g;
                next unless length $piece;

                my @matches = _glob_paths($piece);
                @matches = ($piece) unless @matches;

                for my $match (@matches) {
                    my $resolved = abs_path($match);
                    $resolved = File::Spec->rel2abs($match) unless defined $resolved;
                    next if $seen{$resolved};
                    $seen{$resolved} = 1;
                    push @paths, $match;
                }
            }
        }
    }
    return @paths;
}

# Write asset files (currently just SVGs). Returns true if any changed.
sub _write_assets {
    my ($assets, $check) = @_;
    my $changed = 0;

    for my $path (keys %$assets) {
        my $content = $assets->{$path};
        my $existing;
        if (-f $path) {
            open my $fh, '<:encoding(UTF-8)', $path
                or die "treegen2: cannot read $path: $!\n";
            local $/;
            $existing = <$fh>;
            close $fh;
        }
        next if defined $existing && $existing eq $content;
        $changed = 1;
        unless ($check) {
            my $dir = dirname($path);
            mkpath($dir) unless -d $dir;
            open my $fh, '>:encoding(UTF-8)', $path
                or die "treegen2: cannot write $path: $!\n";
            print $fh $content;
            close $fh;
        }
    }
    return $changed;
}

sub _set_github_output {
    my ($name, $value) = @_;
    my $output = $ENV{GITHUB_OUTPUT};
    return unless defined $output && length $output;
    open my $fh, '>>:encoding(UTF-8)', $output
        or die "treegen2: cannot write $output: $!\n";
    print $fh "$name=$value\n";
    close $fh;
}

# Run the CLI with @argv (typically @ARGV). Returns a process exit code.
sub run {
    my (@argv) = @_;
    local @ARGV = @argv;

    my $opt_version        = 0;
    my @opt_readme;
    my $opt_base           = '.';
    my $opt_directory      = '.';
    my $opt_style          = Treegen2::Config::STYLE_ASCII;
    my $opt_max_depth      = 0;
    my $opt_dirs_only      = 0;
    my @opt_exclude;
    my $opt_no_gitignore   = 0;
    my $opt_show_root      = 0;
    my $opt_descriptions;
    my $opt_svg_output     = 'assets/filetree.svg';
    my $opt_color          = $Treegen2::Config::DEFAULT_COLOR;
    my $opt_background     = 'auto';
    my $opt_title          = 'Project structure';
    my $opt_collapse       = 0;
    my $opt_closed         = 0;
    my $opt_placeholder    = 'files';
    my $opt_format         = 'auto';
    my $opt_no_placeholder = 0;
    my $opt_check          = 0;

    my $ok = GetOptions(
        'version'          => \$opt_version,
        'readme=s'         => \@opt_readme,
        'base=s'           => \$opt_base,
        'directory|dir=s'  => \$opt_directory,
        'style=s'          => \$opt_style,
        'max-depth=i'      => \$opt_max_depth,
        'dirs-only'        => \$opt_dirs_only,
        'exclude=s'        => \@opt_exclude,
        'no-gitignore'     => \$opt_no_gitignore,
        'show-root'        => \$opt_show_root,
        'descriptions=s'   => \$opt_descriptions,
        'svg-output=s'     => \$opt_svg_output,
        'color=s'          => \$opt_color,
        'background=s'     => \$opt_background,
        'title=s'          => \$opt_title,
        'collapse'         => \$opt_collapse,
        'closed'           => \$opt_closed,
        'placeholder=s'    => \$opt_placeholder,
        'format=s'         => \$opt_format,
        'no-placeholder'   => \$opt_no_placeholder,
        'check'            => \$opt_check,
    );

    unless ($ok) {
        print STDERR "treegen2: invalid arguments\n";
        return 1;
    }

    if ($opt_version) {
        print "treegen2 $Treegen2::VERSION\n";
        return 0;
    }

    unless (grep { $_ eq $opt_style } @Treegen2::Config::STYLES) {
        print STDERR "treegen2: invalid --style '$opt_style' (choose from: "
            . join(', ', @Treegen2::Config::STYLES) . ")\n";
        return 1;
    }
    unless (grep { $_ eq $opt_color } @Treegen2::Config::COLOR_CHOICES) {
        print STDERR "treegen2: invalid --color '$opt_color' (choose from: "
            . join(', ', @Treegen2::Config::COLOR_CHOICES) . ")\n";
        return 1;
    }
    unless (grep { $_ eq $opt_format } qw(auto markdown html)) {
        print STDERR "treegen2: invalid --format '$opt_format' (choose from: auto, markdown, html)\n";
        return 1;
    }

    my $base = abs_path($opt_base);
    $base = File::Spec->rel2abs($opt_base) unless defined $base;

    my @exclude;
    for my $value (@opt_exclude) {
        push @exclude, Treegen2::Config::split_list($value);
    }

    my $options = Treegen2::Config::new_options(
        directory         => $opt_directory,
        style             => $opt_style,
        max_depth         => $opt_max_depth,
        dirs_only         => $opt_dirs_only ? 1 : 0,
        exclude           => \@exclude,
        use_gitignore     => $opt_no_gitignore ? 0 : 1,
        show_root         => $opt_show_root ? 1 : 0,
        descriptions_file => $opt_descriptions,
        svg_output        => $opt_svg_output,
        color             => $opt_color,
        background        => $opt_background,
        collapse          => $opt_collapse ? 1 : 0,
        open              => $opt_closed ? 0 : 1,
        title             => $opt_title,
    );

    my $placeholder        = $opt_placeholder;
    my $chosen_format       = $opt_format;
    my $enable_placeholder = $opt_no_placeholder ? 0 : 1;
    my $check              = $opt_check ? 1 : 0;

    my @patterns = @opt_readme ? @opt_readme : ('README.md');
    my @readmes = _resolve_readmes(@patterns);

    unless (@readmes) {
        print STDERR "treegen2: no README files matched\n";
        return 1;
    }

    my $any_changed  = 0;
    my $total_blocks = 0;
    my $processed    = 0;

    for my $readme (@readmes) {
        unless (-f $readme) {
            print STDERR "treegen2: skipping missing file $readme\n";
            next;
        }
        $processed++;

        my %file_options = %$options;
        $file_options{output_format} = _format_for($readme, $chosen_format);

        my $result = Treegen2::Readme::process_file(
            $readme, \%file_options, $base, $placeholder, $enable_placeholder);

        $total_blocks += $result->{blocks};
        my $assets_changed = _write_assets($result->{assets}, $check);
        my $file_changed = $result->{changed};

        if ($result->{changed} && !$check) {
            open my $fh, '>:encoding(UTF-8)', $readme
                or die "treegen2: cannot write $readme: $!\n";
            print $fh $result->{text};
            close $fh;
        }

        my $status = ($file_changed || $assets_changed) ? 'changed' : 'unchanged';
        print "treegen2: $readme \x{2014} $result->{blocks} block(s), $status\n";
        $any_changed = 1 if $file_changed || $assets_changed;
    }

    if ($processed == 0) {
        print STDERR "treegen2: no existing README files to process\n";
        return 1;
    }

    _set_github_output('changed', $any_changed ? 'true' : 'false');
    _set_github_output('blocks', "$total_blocks");

    if ($check && $any_changed) {
        print STDERR "treegen2: files are out of date (run without --check to update)\n";
        return 1;
    }
    return 0;
}

1;
