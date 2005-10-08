
package MARC::Fast;
use strict;
use Carp;
use Data::Dumper;

BEGIN {
	use Exporter ();
	use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	$VERSION     = 0.02;
	@ISA         = qw (Exporter);
	#Give a hoot don't pollute, do not export more than needed by default
	@EXPORT      = qw ();
	@EXPORT_OK   = qw ();
	%EXPORT_TAGS = ();
}

=head1 NAME

MARC::Fast - Very fast implementation of MARC database reader

=head1 SYNOPSIS

  use MARC::Fast;


=head1 DESCRIPTION

This is very fast alternative to C<MARC> and C<MARC::Record> modules.

It's is also very sutable for random access to MARC records (as opposed to
sequential one).

=head1 METHODS

=head2 new

Read MARC database

  my $marc = new MARC::Fast(
  	marcdb => 'unimarc.iso',
	quiet => 0,
	debug => 0,
	assert => 0,
  );

=cut

################################################## subroutine header end ##


sub new {
	my $class = shift;
	my $self = {@_};
	bless ($self, $class);

	croak "need marcdb parametar" unless ($self->{marcdb});

	print STDERR "# opening ",$self->{marcdb},"\n" if ($self->{debug});

	open($self->{fh}, $self->{marcdb}) || croak "can't open ",$self->{marcdb},": $!";

	$self->{count} = 0;

	while (! eof($self->{fh})) {
		$self->{count}++;

		# save record position
		push @{$self->{fh_offset}}, tell($self->{fh});

		my $leader;
		read($self->{fh}, $leader, 24);

		# Byte        Name
		# ----        ----
		# 0-4         Record Length
		# 5           Status (n=new, c=corrected and d=deleted)
		# 6           Type of Record (a=printed material)
		# 7           Bibliographic Level (m=monograph)
		# 8-9         Blanks
		# 10          Indictator count (2 for monographs)
		# 11          Subfield code count (2 - 0x1F+subfield code itself)
		# 12-16       Base address of data
		# 17          Encoding level (blank=full level, 1=sublevel 1, 2=sublevel 2,
		# 		3=sublevel 3)
		# 18          Descriptive Cataloguing Form (blank=record is full ISBD,
		#		n=record is in non-ISBD format, i=record is in
		#		an incomplete ISBD format)
		# 19          Blank
		# 20          Length of length field in directory (always 4 in UNIMARC)
		# 21          Length of Starting Character Position in directory (always
		# 		5 in UNIMARC)
		# 22          Length of implementation defined portion in directory (always
		# 		0 in UNIMARC)
		# 23          Blank
		#
		#           |0   45  89  |12 16|1n 450 |
		#           |xxxxxnam  22(.....)   45 <---

		print STDERR "REC ",$self->{count},": $leader\n" if ($self->{debug});

		# store leader for later
		push @{$self->{leaders}}, $leader;

		# skip to next record
		seek($self->{fh},substr($leader,0,5)-24,1);

	}

	return $self;
}

=head2 count

Return number of records in database

  print $marc->count;

=cut

sub count {
	my $self = shift;
	return $self->{count};
}

=head2 fetch

Fetch record from database

  my $hash = $marc->fetch(42);

=cut

sub fetch {
	my $self = shift;

	my $rec_nr = shift || return;

	my $leader = $self->{leaders}->[$rec_nr - 1];
	unless ($leader) {
		carp "can't find record $rec_nr";
		return;
	};
	my $offset = $self->{fh_offset}->[$rec_nr - 1];
	unless (defined($offset)) {
		carp "can't find offset for record $rec_nr";
		return;
	};

	my $reclen = substr($leader,0,5);
	my $base_addr = substr($leader,12,5);

	print STDERR "# $rec_nr leader: '$leader' reclen: $reclen base addr: $base_addr [dir: ",$base_addr - 24,"]\n" if ($self->{debug});

	my $skip = 0;

	print STDERR "# seeking to $offset + 24\n" if ($self->{debug});

	if ( ! seek($self->{fh}, $offset+24, 0) ) {
		carp "can't seek to $offset: $!";
		return;
	}

	print STDERR "# reading ",$base_addr-24," bytes of dictionary\n" if ($self->{debug});

	my $directory;
	if( ! read($self->{fh},$directory,$base_addr-24) ) {
		carp "can't read directory: $!";
		$skip = 1;
	} else {
		print STDERR "# $rec_nr directory: [",length($directory),"] '$directory'\n" if ($self->{debug});
	}

	print STDERR "# reading ",$reclen-$base_addr," bytes of fields\n" if ($self->{debug});

	my $fields;
	if( ! read($self->{fh},$fields,$reclen-$base_addr) ) {
		carp "can't read fields: $!";
		$skip = 1;
	} else {
		print STDERR "# $rec_nr fields: '$fields'\n" if ($self->{debug});
	}

	my $row;

	while (!$skip && $directory =~ s/(\d{3})(\d{4})(\d{5})//) {
		my ($tag,$len,$addr) = ($1,$2,$3);

		if (($addr+$len) > length($fields)) {
			print STDERR "WARNING: error in dictionary on record $rec_nr skipping...\n" if (! $self->{quiet});
			$skip = 1;
			next;
		}

		# take field
		my $f = substr($fields,$addr,$len);
		print STDERR "tag/len/addr $tag [$len] $addr: '$f'\n" if ($self->{debug});

		if ($row->{$tag}) {
			$row->{$tag} .= $f;
		} else {
			$row->{$tag} = $f;
		}

		my $del = substr($fields,$addr+$len-1,1);

		# check field delimiters...
		if ($self->{assert} && $del ne chr(30)) {
			print STDERR "WARNING: skipping record $rec_nr, can't find delimiter 30 got: '$del'\n" if (! $self->{quiet});
			$skip = 1;
			next;
		}

		if ($self->{assert} && length($f) < 2) {
			print STDERR "WARNING: skipping field $tag from record $rec_nr because it's too short!\n" if (! $self->{quiet});
			next;
		}

	}

	return $row;
}

1;
__END__

=head1 BUGS



=head1 SUPPORT



=head1 AUTHOR

	Dobrica Pavlinusic
	CPAN ID: DPAVLIN
	dpavlin@rot13.org
	http://www.rot13.org/~dpavlin/

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).

=cut
