#!/usr/bin/perl -w

use strict;
use blib;

use MARC::Fast;
use Getopt::Std;
use Data::Dumper;

my %opt;
getopts('dn:', \%opt);

my $file = shift @ARGV || die "usage: $0 [-n number] [-d] file.marc\n";

my $marc = new MARC::Fast(
	marcdb => $file,
	debug => $opt{'d'},
);

print STDERR "$file has ",$marc->count," records...\n";

my $min = 1;
my $max = $marc->count;

if (my $mfn = $opt{'n'}) {
	$min = $max = $mfn;
}

print STDERR "Dumping $min - $max\n" if ($opt{'d'});

for my $mfn ($min .. $max) {
	my $rec = $marc->fetch($mfn) || next;
	print "REC $mfn\n";
	foreach my $f (sort keys %{$rec}) {
		print "$f\t",$rec->{$f},"\n";
	}
	print "\n";
}
