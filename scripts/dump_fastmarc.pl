#!/usr/bin/perl -w

use strict;
use blib;

use MARC::Fast;

use Data::Dumper;

my $file = shift @ARGV || die "usage: $0 file.marc\n";
my $debug = shift @ARGV;

my $marc = new MARC::Fast(
	marcdb => $file,
	debug => $debug,
);

print STDERR "$file has ",$marc->count," records...\n\n";

for my $mfn (1 .. $marc->count) {
	my $rec = $marc->fetch($mfn) || next;
	print "REC $mfn\n";
	foreach my $f (sort keys %{$rec}) {
		print "$f\t",$rec->{$f},"\n";
	}
	print "\n";
}
