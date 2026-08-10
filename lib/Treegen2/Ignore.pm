package Treegen2::Ignore;
use strict;
use warnings;

# A best-effort .gitignore-style path matcher (core Perl only).
#
# This is intentionally a pragmatic subset of full gitignore semantics. It
# supports the cases people actually put in these markers:
#
#   * bare names match at any depth (node_modules, *.log)
#   * a trailing "/" restricts a rule to directories (build/)
#   * a rule containing "/" is anchored to the scan root (src/generated)
#   * "*" matches within a path segment, "**" matches across segments
#   * a leading "!" negates an earlier match
#
# Only the root-level .gitignore is read; nested ignore files are not merged.

use Exporter 'import';
our @EXPORT_OK = qw(default_excludes build_matcher is_excluded glob_to_regex);

# Always excluded, regardless of user configuration.
my @DEFAULT_EXCLUDES = (
    '.git/', '.hg/', '.svn/', '.DS_Store',
    'node_modules/', '__pycache__/', '.mypy_cache/',
    '.pytest_cache/', '.ruff_cache/', '.venv/', 'venv/',
);

sub default_excludes { return @DEFAULT_EXCLUDES }

# Translate a glob (already stripped of anchors/flags) into a regex body.
# Public alias, also used by Treegen2::CLI to resolve "**" README patterns.
sub glob_to_regex { return _glob_to_regex(@_); }

sub _glob_to_regex {
    my ($pattern) = @_;
    my @out;
    my @chars = split //, $pattern;
    my $i = 0;
    my $len = scalar @chars;
    while ($i < $len) {
        my $char = $chars[$i];
        if ($char eq '*') {
            if ($i + 1 < $len && $chars[$i + 1] eq '*') {
                if ($i + 2 < $len && $chars[$i + 2] eq '/') {
                    push @out, '(?:.*/)?';
                    $i += 3;
                    next;
                }
                push @out, '.*';
                $i += 2;
                next;
            }
            push @out, '[^/]*';
        }
        elsif ($char eq '?') {
            push @out, '[^/]';
        }
        else {
            push @out, quotemeta($char);
        }
        $i++;
    }
    return join '', @out;
}

# Compile one pattern line into a rule hashref, or undef if it's blank.
sub _compile_rule {
    my ($pattern) = @_;
    my $negate = ($pattern =~ s/^!//) ? 1 : 0;
    my $dir_only = ($pattern =~ m{/$}) ? 1 : 0;
    $pattern =~ s{/+$}{};
    return undef unless length $pattern;
    my $anchored = ($pattern =~ m{^/}) || ($pattern =~ m{/});
    $pattern =~ s{^/+}{};
    my $regex_body = _glob_to_regex($pattern);
    my $regex = qr/^$regex_body$/;
    return {
        regex    => $regex,
        negate   => $negate,
        dir_only => $dir_only,
        anchored => $anchored,
    };
}

# Build a matcher (arrayref of rules) from a list of raw pattern lines.
sub build_matcher {
    my (@patterns) = @_;
    my @rules;
    for my $pattern (@patterns) {
        my $stripped = $pattern;
        $stripped =~ s/^\s+|\s+$//g;
        next unless length $stripped;
        next if $stripped =~ /^#/;
        my $rule = _compile_rule($stripped);
        push @rules, $rule if defined $rule;
    }
    return \@rules;
}

# Combine default excludes, user excludes, and the root .gitignore (if
# use_gitignore is true and the file exists) into one matcher.
sub build {
    my (%args) = @_;
    my $root          = $args{root};
    my $extra          = $args{extra} || [];
    my $use_gitignore  = $args{use_gitignore};

    my @patterns = (@DEFAULT_EXCLUDES, @$extra);
    if ($use_gitignore) {
        my $gitignore = "$root/.gitignore";
        if (-f $gitignore) {
            open my $fh, '<:encoding(UTF-8)', $gitignore
                or die "treegen2: cannot read $gitignore: $!";
            local $/;
            my $content = <$fh>;
            close $fh;
            push @patterns, split /\r?\n/, $content;
        }
    }
    return build_matcher(@patterns);
}

# Return true if $rel_path (POSIX, root-relative) should be excluded.
sub is_excluded {
    my ($rules, $rel_path, $is_dir) = @_;
    my $basename = $rel_path;
    $basename =~ s{^.*/}{};
    my $excluded = 0;
    for my $rule (@$rules) {
        next if $rule->{dir_only} && !$is_dir;
        my $target = $rule->{anchored} ? $rel_path : $basename;
        if ($target =~ $rule->{regex}) {
            $excluded = $rule->{negate} ? 0 : 1;
        }
    }
    return $excluded;
}

1;
