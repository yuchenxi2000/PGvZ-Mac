#!/usr/bin/perl
use strict;
use warnings;

my ($iconset_dir, $output_file) = @ARGV;
die "Usage: $0 <iconset-directory> <output.icns>\n"
  unless defined $iconset_dir && defined $output_file;

my @entries = (
  [ 'icp4', 'icon_16x16.png' ],
  [ 'icp5', 'icon_32x32.png' ],
  [ 'icp6', 'icon_64x64.png' ],
  [ 'ic07', 'icon_128x128.png' ],
  [ 'ic08', 'icon_256x256.png' ],
  [ 'ic09', 'icon_512x512.png' ],
  [ 'ic10', 'icon_1024x1024.png' ],
);

my @chunks;
my $total_size = 8;

for my $entry (@entries) {
  my ($type, $filename) = @$entry;
  my $path = "$iconset_dir/$filename";
  open my $input, '<:raw', $path or die "Cannot read $path: $!\n";
  local $/;
  my $png = <$input>;
  close $input;

  die "$path is not a PNG file\n"
    unless defined $png && substr($png, 0, 8) eq "\x89PNG\r\n\x1a\n";

  my $chunk = $type . pack('N', length($png) + 8) . $png;
  push @chunks, $chunk;
  $total_size += length($chunk);
}

open my $output, '>:raw', $output_file
  or die "Cannot write $output_file: $!\n";
print {$output} 'icns', pack('N', $total_size), @chunks;
close $output or die "Cannot finish $output_file: $!\n";
