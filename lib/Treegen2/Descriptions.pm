package Treegen2::Descriptions;
use strict;
use warnings;

# Optional per-path descriptions loaded from a JSON file.
#
# The file maps a POSIX path (relative to the scan root) to a short note:
#
#   {
#     "brand-identity": "Core visual brand elements",
#     "brand-identity/logos": "Official logos and icons (SVG, PNG)"
#   }
#
# Trailing slashes on keys are ignored, so "logos/" and "logos" both match.

use Treegen2::JSONLite qw(decode_json_lite);

use Exporter 'import';
our @EXPORT_OK = qw(load_descriptions get_description);

sub _strip_slashes {
    my ($s) = @_;
    $s =~ s{^/+|/+$}{}g;
    return $s;
}

# Load descriptions from $path (relative to $base). Returns a hashref
# (possibly empty) of normalized-path -> text.
sub load_descriptions {
    my ($path, $base) = @_;
    return {} unless defined $path && length $path;

    my $file_path = "$base/$path";
    return {} unless -f $file_path;

    open my $fh, '<:encoding(UTF-8)', $file_path
        or die "treegen2: cannot read $file_path: $!\n";
    local $/;
    my $raw_text = <$fh>;
    close $fh;

    my $raw = decode_json_lite($raw_text);
    die "treegen2: $file_path: expected a JSON object of path -> text\n"
        unless ref $raw eq 'HASH';

    my %mapping;
    for my $key (keys %$raw) {
        my $value = $raw->{$key};
        $value = '' unless defined $value;
        $mapping{ _strip_slashes($key) } = "$value";
    }
    return \%mapping;
}

# Return the description for $path (POSIX, root-relative), if any.
sub get_description {
    my ($mapping, $path) = @_;
    return undef unless $mapping;
    my $value = $mapping->{ _strip_slashes($path) };
    return (defined $value && length $value) ? $value : undef;
}

1;
