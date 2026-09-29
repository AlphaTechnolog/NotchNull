# Loads NowPlayingBridge.dylib into /usr/bin/perl and calls one of its entry points.
# Usage: /usr/bin/perl now-playing.pl <path/to/NowPlayingBridge.dylib> <notchnull_stream|notchnull_command>
use strict;
use warnings;
use DynaLoader;

my ($library, $entry) = @ARGV;
die "usage: now-playing.pl <dylib> <entry>\n" unless $library && $entry;
my $handle = DynaLoader::dl_load_file($library, 0) or die DynaLoader::dl_error();
my $symbol = DynaLoader::dl_find_symbol($handle, $entry) or die DynaLoader::dl_error();
my $call = DynaLoader::dl_install_xsub("main::bridge_entry", $symbol);
&$call();
