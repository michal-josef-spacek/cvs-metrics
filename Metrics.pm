use strict;

package CVS::Metrics;

use vars qw($VERSION);
$VERSION = '0.02';

use File::Basename;
use POSIX qw(mktime);

sub insertHead {
	my $cvs_log = shift;

	foreach my $file (values %{$cvs_log}) {
		my $head = $file->{head};
		my $state = $file->{description}->{$head}->{state};
		if ($state eq 'Exp') {
			$file->{'symbolic names'}->{HEAD} = $head;
		}
	}
}

sub getTagname {
	my $cvs_log = shift;

	my %tagname;
	foreach my $file (values %{$cvs_log}) {
		foreach (keys %{$file->{'symbolic names'}}) {
			unless (exists $tagname{$_}) {
				$tagname{$_} = 1;
			}
		}
	}
	return keys %tagname;
}

sub getTimedTag {
	my $cvs_log = shift;

	my %timed;
#	open LOG, "> timed.log";
	while (my ($filename, $file) = each %{$cvs_log}) {
		next if (dirname($filename) eq '.');
		while (my ($tag, $rev_name) = each %{$file->{'symbolic names'}}) {
			my $rev = $file->{description}->{$rev_name};
			next unless (exists $rev->{date});
			my $date = $rev->{date};
			if (exists $timed{$tag}) {
				if ($date gt $timed{$tag}) {
					$timed{$tag} = $date;
#					print LOG "$tag $filename $date\n";
				}
			} else {
				$timed{$tag} = $date;
			}
		}
	}
#	close LOG;
	return \%timed;
}

sub _Energy {
	my $cvs_log = shift;
	my ($tags, $path) = @_;

	my @diffs;
	my @tags0 = @{$tags};
	my @tags1 = @{$tags};
	shift @tags1;
	foreach (@tags1) {
		my $diff = shift(@tags0) . "-" . $_;
		push @diffs, $diff;
	}

	my %size;
	foreach my $tag (@{$tags}) {
		$size{$tag} = 0;
	}

	my %delta;
	foreach my $diff (@diffs) {
		$delta{$diff} = 0;
	}

	while (my ($filename, $file) = each %{$cvs_log}) {
		next unless ($filename =~ /^$path/);
		my @rev0;
		foreach my $tag (@{$tags}) {
			if (exists $file->{'symbolic names'}->{$tag}) {
				$size{$tag} ++;
				push @rev0, $file->{'symbolic names'}->{$tag};
			} else {
				push @rev0, '';
			}
		}
		my @rev1 = @rev0;
		shift @rev1;
		foreach my $diff (@diffs) {
			my $rev0 = shift @rev0;
			my $rev1 = shift @rev1;
			if ($rev1 and $rev0 ne $rev1) {
				$delta{$diff} ++;
			}
		}
	}

	my %cumul;
	$cumul{$tags->[0]} = 0;
	@tags0 = @{$tags};
	@tags1 = @{$tags};
	shift @tags1;
	foreach my $tag1 (@tags1) {
		my $tag0 = shift @tags0;
		my $diff = $tag0 . "-" . $tag1;
		$cumul{$tag1} = $cumul{$tag0} + $delta{$diff};
	}

	my @data = ();
	foreach my $tag (@{$tags}) {
		push @data, $cumul{$tag};	# x
		push @data, $size{$tag};	# y
	}

	return \@data;
}

sub EnergyGD {
	my $cvs_log = shift;
	my ($tags, $path, $title, $width, $height, $tag_from, $tag_to) = @_;

	my $data = $cvs_log->_Energy($tags, $path);
	my $img = new CVS::Metrics::TaggedChart($width, $height);
	if (defined $tag_from and defined $tag_to) {
		my @tags2 = @{$tags};
		my @data_pre;
		my @tags_pre;
		while ($tags2[0] lt $tag_from) {
			push @tags_pre, shift @tags2;
			push @data_pre, shift @{$data};
			push @data_pre, shift @{$data};
		}
		if (scalar @tags_pre) {
			push @tags_pre, $tags2[0];
			push @data_pre, ${$data}[0], ${$data}[1];
			$img->setData(\@data_pre, "blue");
			$img->setTag(\@tags_pre);
		}
		unless ($tag_to eq "HEAD") {
			my @data_post;
			my @tags_post;
			if ($tags2[-1] eq "HEAD") {
				unshift @tags_post, pop @tags2;
				unshift @data_post, pop @{$data};
				unshift @data_post, pop @{$data};
			}
			while ($tags2[-1] gt $tag_to) {
				unshift @tags_post, pop @tags2;
				unshift @data_post, pop @{$data};
				unshift @data_post, pop @{$data};
			}
			if (scalar @tags_post) {
				unshift @tags_post, $tags2[-1];
				unshift @data_post, ${$data}[-2], ${$data}[-1];
				$img->setData(\@data_post, "blue");
				$img->setTag(\@tags_post);
			}
		}
		$img->setData($data, "red");
		$img->setTag(\@tags2);
	} else {
		$img->setData($data, "blue");
		$img->setTag($tags);
	}
	$img->setGraphOptions(
			title			=> $title,
			horAxisLabel	=> "delta (added or modified files)",
			vertAxisLabel	=> "size (nb files)",
	);
	$img->draw();
	my $gd = $img->getGDobject();
	$gd->transparent(-1);
	return $gd;
}

sub EnergyCv {
	my $cvs_log = shift;
	my ($tags, $path, $title, $width, $height, $toplevel) = @_;

	my $data = $cvs_log->_Energy($tags, $path);
	my $img = new CVS::Metrics::TaggedChart($width, $height);
	$img->setData($data, "blue");
	$img->setTag($tags);
	$img->setGraphOptions(
			title			=> $title,
			horAxisLabel	=> "delta (added or modified files)",
			vertAxisLabel	=> "size (nb files)",
	);
	return $img->canvas($toplevel);
}

sub getTimedEvolution {
	my $cvs_log = shift;
	my ($path) = @_;
	my %evol;

	while (my ($filename, $file) = each %{$cvs_log}) {
		next if ($path ne "." and $filename !~ /^$path/);
		while (my ($rev_name, $rev) = each %{$file->{description}}) {
			my $date = substr $rev->{date}, 0, 10;		# aaaa/mm/jj
			$evol{$date} = [ 0, 0, 0 ] unless (exists $evol{$date});
			if ($rev->{state} eq "dead") {
				$evol{$date}->[2] ++;		# deleted
			} else {
				if ($rev_name =~ /^1(\.1)+$/) {
					$evol{$date}->[0] ++;	# added
				} else {
					$evol{$date}->[1] ++;	# modified
				}
			}
		}
	}
	return \%evol;
}

sub getDirEvolution {
	my $cvs_log = shift;
	my ($path, $tag_from, $tag_to) = @_;
	my %evol;

	while (my ($filename, $file) = each %{$cvs_log}) {
		next if ($path ne "." and $filename !~ /^$path/);
		my $rev_from = $file->{'symbolic names'}->{$tag_from} || '';
		my $rev_to = $file->{'symbolic names'}->{$tag_to} || '';
		if ($rev_from or $rev_to) {
			next if (cmp_rev($rev_from, $rev_to) == 0);
		} else {
			my $in = 0;
			foreach my $tag (sort keys %{$file->{'symbolic names'}}) {
				$in = 1 if ($tag gt $tag_from and $tag lt $tag_to);
			}
			next unless ($in);
		}
		my $dir = dirname($filename);
		$evol{$dir} = [ 0, 0, 0 ] unless (exists $evol{$dir});
		$evol{$dir}->[0] ++		# added
				unless ($rev_from);
		$evol{$dir}->[2] ++		# deleted
				unless ($rev_to);
		if ($rev_from and $rev_to) {
			next if (cmp_rev($rev_from, $rev_to) == 0);
			my $in = 0;
			while (my ($rev_name, $rev) = each %{$file->{description}}) {
				next if ($rev_from and cmp_rev($rev_name, $rev_from) <= 0);
				next if ($rev_to and cmp_rev($rev_name, $rev_to) > 0);
				$in = 1;
				last;
			}
			$evol{$dir}->[1] ++		# modified
					if ($in);
		}
	}
	return \%evol;
}

sub getEvolution {
	my $cvs_log = shift;
	my ($path, $tag_from, $tag_to) = @_;
	my %evol;

	while (my ($filename, $file) = each %{$cvs_log}) {
		next if ($path ne "." and $filename !~ /^$path/);
		my $rev_from = $file->{'symbolic names'}->{$tag_from} || '';
		my $rev_to = $file->{'symbolic names'}->{$tag_to} || '';
		if ($rev_from or $rev_to) {
			next if (cmp_rev($rev_from, $rev_to) == 0);
		} else {
			my $in = 0;
			foreach my $tag (sort keys %{$file->{'symbolic names'}}) {
				$in = 1 if ($tag gt $tag_from and $tag lt $tag_to);
			}
			next unless ($in);
		}
		my $dir = dirname($filename);
		$evol{$dir} = {} unless (exists $evol{$dir});

		print "$filename:";
		foreach (keys %{$file->{description}}) {
			print " ",$_;
		}
		print "\n";
		while (my ($rev_name, $rev) = each %{$file->{description}}) {
#			print "$filename $rev_name\n";
			next if ($rev_from and cmp_rev($rev_name, $rev_from) <= 0);
			next if ($rev_to and cmp_rev($rev_name, $rev_to) > 0);
			my $message = $rev->{message};
#			print "$rev_name $message\n";
			$message .= " " . $rev->{date} if ($message eq "no message");
			my @tags;
			if ($tag_to eq "HEAD") {
				foreach my $tag (keys %{$file->{'symbolic names'}}) {
					if (cmp_rev($file->{'symbolic names'}->{$tag}, $rev_name) == 0) {
						push @tags, $tag;
					}
				}
			}
			$evol{$dir}->{$message} = [] unless (exists $evol{$dir}->{$message});
			push @{$evol{$dir}->{$message}}, {
					filename	=> $filename,
					date		=> $rev->{date},
					author		=> $rev->{author},
					state		=> $rev->{state},
					revision	=> $rev_name,
					tags		=> \@tags,
			};
		}
	}
	return \%evol;
}

sub cmp_rev {
	my ($rev1, $rev2) = @_;

	return 0 unless ($rev1 or $rev2);
	return -1 unless ($rev1);
	return 1 unless ($rev2);
	return 0 if ($rev1 eq $rev2);
	my @l1 = split /\./, $rev1;
	my @l2 = split /\./, $rev2;
	foreach my $v1 (@l1) {
		my $v2 = shift @l2;
		return 1 unless (defined $v2);
		return 1 if ($v1 > $v2);
		return -1 if ($v1 < $v2);
	}
	return -1;
}

sub _Activity {
	my $cvs_log = shift;
	my ($path, $start_date) = @_;

	use POSIX qw(mktime);

	my $evol = $cvs_log->getTimedEvolution($path);

	my $start = _get_day($start_date) || 0;

	my %evol2;
	while (my ($date, $value) = each %{$evol}) {
		my $d = _get_day($date);
		if (defined $d and $d > $start) {
			$evol2{sprintf("%08d", $d)} = $value;
		}
	}

	my @days;
	my @data;
	my @key_evol2 = sort keys %evol2;
	my $last_day = $start ? $start : $key_evol2[0];
	foreach my $date (@key_evol2) {
		foreach ($last_day+1 .. $date-1) {
			push @days, $_;
			push @data, undef;
		}
		my $val = $evol2{$date};
		push @days, $date;
		push @data, (${$val}[0] + ${$val}[1]);		# added + modified
		$last_day = $date;
	}
	my $now = int(time() / 86400);
	foreach ($last_day+1 .. $now) {
		push @days, $_;
		push @data, undef;
	}

	return (\@days, \@data);
}

sub _get_day {
	my ($date) = @_;

	if ($date =~ /^(\d+)[\-\/](\d+)[\-\/](\d+)$/) {
		my $t = POSIX::mktime(0, 0, 0, $3, $2 - 1, $1 - 1900);
		return int($t / 86400);
	} else {
		warn "_get_day: $date\n";
		return undef;
	}
}

sub ActivityGD {
	my $cvs_log = shift;
	my ($path, $title, $start_date, $width, $height, $date_from, $date_to) = @_;

	use GD::Graph::bars;
	use GD::Graph::mixed;

	my ($days, $data) = $cvs_log->_Activity($path, $start_date);

	my $sum = 0;
	my $nb = 0;
	foreach (@{$data}) {
		next unless ($_);
		$sum += $_;
		$nb ++;
	}
	my $average = $sum / $nb;

	my $range_day = 30;
	while ((scalar(@{$days}) % $range_day) != 1) {
		unshift @{$days}, ${$days}[0] - 1;
		unshift @{$data}, 0;
	}

	my @days2;
	foreach (@{$days}) {
		push @days2, $_ - ${$days}[-1];
	}

	$width = 200 - ${$days}[0] if ($width < 200 - ${$days}[0]);

	if (defined $date_from and defined $date_to) {
		my $now = int(time() / 86400);
		my $day_from = _get_day($date_from) || 0;
		my $day_to = _get_day($date_to) || 0;
		my @data1;
		my @data2;
		my $i = 0;
		foreach (reverse @{$data}) {
			if (        $i <= ($now - $day_from)
					and $i >= ($now - $day_to) ) {
				unshift @data1, $_;
				unshift @data2, undef;
			} else {
				unshift @data1, undef;
				unshift @data2, $_;
			}
			$i ++;
		}
		my $graph = new GD::Graph::mixed($width, $height);
		$graph->set(
				'3d'			=> 0,
				x_label			=> 'days',
				y_label			=> 'nb commits',
				x_label_skip	=> $range_day,
				title			=> $title,
				y_max_value		=> 5 ** int(1 + 1.2 * log($average) / log(5)),
				dclrs			=> [qw(lred lblue)],
				types			=> [ "bars", "bars" ],
		);
		return $graph->plot( [\@days2, \@data1, \@data2] );
	} else {
		my $graph = new GD::Graph::bars($width, $height);
		$graph->set(
				'3d'			=> 0,
				x_label			=> 'days',
				y_label			=> 'nb commits',
				x_label_skip	=> $range_day,
				title			=> $title,
				y_max_value		=> 5 ** int(1 + 1.2 * log($average) / log(5)),
		);
		return $graph->plot( [\@days2, $data] );
	}
}

#######################################################################

package CVS::Metrics::TaggedChart;

use GD;
#use base qw(Chart::Plot);
use base qw(Chart::Plot::Canvas);

sub setTag {
	my $self = shift;
	my ($arrayref) = @_;

	# record the dataset
	my $label = $self->{_numDataSets};
	$self->{_tag}->{$label} = $arrayref;
	return $label;
}

sub _drawData {
	my $self = shift;
	$self->SUPER::_drawData();
	$self->_drawTag();
}

sub _drawTag {
	my $self = shift;

	foreach my $dataSetLabel (keys %{$self->{_data}}) {
		next unless (exists $self->{_tag}->{$dataSetLabel});

		# get color
		my $color = '_black';
		if ( $self->{'_dataStyle'}->{$dataSetLabel} =~ /((red)|(blue)|(green))/i ) {
			$color = "_$1";
			$color =~ tr/A-Z/a-z/;
		}

		my $num = @{ $self->{'_data'}->{$dataSetLabel} };
		my $prevpx = 0;
		for (my $i = 0; $i < $num/2; $i ++) {

			# get next point
			my ($px, $py) = $self->_data2pxl (
					$self->{_data}->{$dataSetLabel}[2*$i],
					$self->{_data}->{$dataSetLabel}[2*$i+1]
			);

			if ($px != $prevpx) {
				$self->{'_im'}->stringUp(gdTinyFont, $px-8, $py-5,
				       $self->{_tag}->{$dataSetLabel}[$i], $self->{$color})
			}
			$prevpx = $px;
		}
	}
}

sub _createData {
	my $self = shift;
	$self->SUPER::_createData();
	$self->_createTag();
}

sub _createTag {
	my $self = shift;

	foreach my $dataSetLabel (keys %{$self->{_data}}) {
		next unless (exists $self->{_tag}->{$dataSetLabel});

		# get color
		my $color = 'black';
		if ( $self->{'_dataStyle'}->{$dataSetLabel} =~ /((red)|(blue)|(green))/i ) {
			$color = $1;
			$color =~ tr/A-Z/a-z/;
		}

		my $num = @{ $self->{'_data'}->{$dataSetLabel} };
		my $prevpx = 0;
		for (my $i = 0; $i < $num/2; $i ++) {

			# get next point
			my ($px, $py) = $self->_data2pxl (
					$self->{_data}->{$dataSetLabel}[2*$i],
					$self->{_data}->{$dataSetLabel}[2*$i+1]
			);

			if ($px != $prevpx) {
				foreach (reverse split//, $self->{_tag}->{$dataSetLabel}[$i]) {
					$self->{'_cv'}->createText($px-5, $py,
							-anchor => 's',
							-font => $self->{_TinyFont},
							-text => $_,
							-fill => $color
					);
					$py -= 9;
				}
			}
			$prevpx = $px;
		}
	}
}

#######################################################################

package CVS::Metrics::Parser;

use Parse::RecDescent;

our %cvs_log;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);

	my $grammar = q{
		File: EOL rcs working head branch lock access symbolic keyword total selected Description
				{
					$CVS::Metrics::Parser::cvs_log{$item[3]} = {
#							'rcs file'				=> $item[2],
#							'working file'			=> $item[3],
							'head'					=> $item[4],
#							'branch'				=> $item[5],
#							'locks'					=> $item[6],
#							'access list'			=> $item[7],
							'symbolic names'		=> $item[8],
#							'keyword subtitution'	=> $item[9],
							'total revisions'		=> $item[10],
#							'selected revisions'	=> $item[11],
							'description'			=> $item[12]
					};
				}

		rcs: 'RCS file:' /[^,]+/ ',v' EOL
				{ $item[2]; }

		working: 'Working file:' /(.*)/ EOL
				{ $item[2]; }

		head: 'head:' /(.*)/ EOL
				{ $item[2]; }

		branch: 'branch:' /(.*)/ EOL
				{ $item[2]; }

		lock: 'locks:' /(.*)/ EOL
				{ $item[2]; }

		access: 'access list:' /(.*)/ EOL
				{ $item[2]; }

		symbolic: 'symbolic names:' EOL Tag(s?)
				{
					my @list;
					foreach (@{$item[3]}) {
						push @list, @{$_};
					}
					my %hash = @list;
					\%hash;
				}

		Tag: /[0-9A-Za-z_\-\.]+/ ':' /[0-9\.]+/ EOL
				{
					[ $item[1], $item[3] ];
				}

		keyword: 'keyword substitution:' /(.*)/ EOL
				{ $item[2]; }

		total: 'total revisions:' /[0-9]+/ SEMICOL
				{ $item[2]; }

		selected: 'selected revisions:'  /[0-9]+/ EOL
				{ $item[2]; }

		Description: 'description:' EOL Revision(s)
				{
					my @list;
					foreach (@{$item[3]}) {
						push @list, @{$_};
					}
					my %hash = @list;
					\%hash;
				}

		Revision: /[-]+\n/ id date author state line(?) EOL message(s)
				{
					[
						$item[2],
						{
								'date'		=> $item[3],
								'author'	=> $item[4],
								'state'		=> $item[5],
#								'line_add'	=> ${$item[6]}[0],
#								'line_del'	=> ${$item[6]}[1],
								'message'	=> join "\n", @{$item[8]},
						}
					];
				}

		id: 'revision' /[0-9\.]+/ EOL
				{ $item[2]; }

		date: 'date:' /[^;]+/ SEMICOL
				{ $item[2]; }

		author: 'author:' /[^;]+/ SEMICOL
				{ $item[2]; }

		state: 'state:' /[^;]+/ SEMICOL
				{ $item[2]; }

		line: 'lines:' /[-+]?[0-9]+/ /[-+]?[0-9]+/
				{ [ $item[2] , $item[3] ]; }

		message: /([^\-].*)|([-]+[^\-\n].*)/ EOL
				{ $item[1] || $item[2]; }

		SEMICOL: ';'

		EOL: /\n/
	};
	$Parse::RecDescent::skip = '[ \t]*';
	$self->{parser} = new Parse::RecDescent($grammar);
	return undef unless (defined $self->{parser});
	return $self;
}

sub parse {
	my $self = shift;
	my ($cvs_logfile) = @_;

	%cvs_log = ();
	$Parse::RecDescent::skip = '[ \t]*';
	my $text;
	open IN, $cvs_logfile
			or die "can't open CVS output ($!).\n";
	while (<IN>) {
		$text = $_;
		last unless (/^\?/);
	}
	while (<IN>) {
		if (/^[=]+$/) {
			unless (defined $self->{parser}->File($text)) {
				print "Not matched\n$text\n";
			}
			$text = '';
		} else {
			$text .= $_;
		}
	}
	close IN;
	my $metric = \%cvs_log;
	return bless($metric, "CVS::Metrics");
}

1;

__END__


=head1 NAME

CVS::Metrics - Utilities for process B<cvs log>

=head1 SEE ALSO

L<cvs_activity.pl>, L<cvs_energy.pl>, L<cvs_tklog.pl>

=head1 COPYRIGHT

(c) 2003 Francois PERRAD, France. All rights reserved.

This library is distributed under the terms of the Artistic Licence.

=head1 AUTHOR

Francois PERRAD, francois.perrad@gadz.org

=cut
