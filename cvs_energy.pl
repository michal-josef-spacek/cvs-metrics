#!/usr/bin/perl -w

use strict;

use Getopt::Std;
use File::Which;
use File::Path;
use HTML::Template;
use Pod::Usage;

use CVS::Metrics;

my %opts;
getopts('bd:f:ho:t:vH', \%opts);

if ($opts{h}) {
	pod2usage(-verbose => 1);
}

if ($opts{v}) {
	print "$0\n";
	print "CVS::Metrics Version $CVS::Metrics::VERSION\n";
	exit(0);
}

my $cfg = ".cvs_metrics";
our ($title, @dirs, $regex_tag, $flg_head);
if ( -r $cfg) {
	print "reading $cfg\n";
	require $cfg;
}

my $cvs_logfile;
if ($opts{f}) {
	$cvs_logfile = $opts{f};
} else {
	my $cvs = FindCvs();
	$cvs_logfile = $cvs . " log |";
}

if ($opts{d}) {
	my $dirs = $opts{d};
	@dirs = split / /, $dirs;
}

if ($opts{t}) {
	$title = $opts{t};
} else {
	$title = "total" unless (defined $title);
}

if ($opts{H}) {
	$flg_head = 1;
}

unless (defined $regex_tag) {
	$regex_tag = '\d+';
}

my $output = $opts{o};
if ($output and ! -d $output) {
	mkpath $output
			or die "can't create $output ($!).";
}

=head1 NAME

cvs_energy - Extract metrics from cvs log

=head1 SYNOPSIS

cvs_energy [B<-f> I<file.log>] [B<-o> I<dir>] [B<-t> I<title>] [B<-H>] [B<-d> "I<dirs> ..."]

=head1 OPTIONS

=over 8

=item -b

At the end, start a Browser.

=item -d

List of directories.

=item -f

Mode off-line.

=item -h

Display Usage.

=item -o

Output directory.

=item -t

Specify the main title.

=item -v

Display Version.

=item -H

append HEAD as a tag.

=back

=head1 DESCRIPTION

B<cvs_activity> parses B<cvs log> and produces an HTML report.

This report is composed of a list of plot charts, each chart represents the
energy in a directory between each tags.

This tool needs File::Which, GD, Chart::Plot::Canvas, HTML::Template and Parse::RecDescent modules.

=head2 Configuration file (.cvs_metrics)

If present, B<cvs_energy> reads the configuration file F<.cvs_metrics>
in the current directory. The file could contains the following variables :

 $title = "main";

 $regex_tag = '^V\d+';

 @dirs = ( "abc", "def" , "def/hij" );

 $flg_head = 1;		# or 0

=head1 SEE ALSO

cvs_activity, cvs_tklog, cvs_wxlog, cvs_current

=head1 COPYRIGHT

(c) 2003-2004 Francois PERRAD, France. All rights reserved.

This library is distributed under the terms of the Artistic Licence.

=head1 AUTHOR

Francois PERRAD, francois.perrad@gadz.org

=cut

my $cvs_log = CVS::Metrics::CvsLog(
		stream		=> $cvs_logfile,
		use_cache	=> 1,
);
if ($cvs_log) {
	my @tags;
	my $timed = $cvs_log->getTimedTag();
	my %matched;
	while (my ($tag, $date) = each %{$timed}) {
		print "Tag: ", $tag;
		if ($tag =~ /$regex_tag/) {
			$matched{$date} = $tag;
			print " ... matched";
		}
		print "\n";
	}
	foreach (sort keys %matched) {
		push @tags, $matched{$_};
	}

	if ($flg_head) {
		push @tags, "HEAD";
		$cvs_log->insertHead();
	}

	GeneratePNG($cvs_log, $output, \@tags, $title, @dirs);
	GenerateHTML($output, $title, @dirs);
	if ($opts{b}) {
		print "Starting browser...";
		exec "e_${title}.html";
	}
}

#######################################################################

sub FindCvs {
	my $cvs = which('cvs');

	if ( !defined $cvs and $^O eq 'MSWin32' ) {
		my $cvs_setting;
		eval 'use Win32::TieRegistry(Delimiter => "/")';
		eval '$cvs_setting = $Registry->{"HKEY_CURRENT_USER/Software/WinCvs/wincvs/CVS settings"}';
		$cvs = $cvs_setting->{'/P_WhichCvs'};
		if (defined $cvs) {
			$cvs =~ s/[\000\001]//g;
			$cvs =~ s/wincvs\.exe\@$//;
			if ( -e "${cvs}CVSNT\\\\cvs.exe") {
				$cvs .= "CVSNT\\\\cvs.exe";
			} else {
				$cvs .= "cvs.exe";
			}
		}
	}

	die "$cvs not found !\n" unless (defined $cvs);

	warn "Using CVS : $cvs\n";
	return '"' . $cvs . '"';
}

#######################################################################

sub GeneratePNG {
	my ($cvs_log, $output, $tags, $title, @dirs) = @_;

	my $img = $cvs_log->EnergyGD($tags, ".", $title, 600, 400);

	if (defined $img) {
		my $e_img = "e_${title}.png";
		$e_img =~ s/\//_/g;
		my $filename = (defined $output) ? $output . "/" . $e_img : $e_img;
		open OUT, "> $filename"
				or die "can't open $filename ($!).\n";
		binmode OUT, ":raw";
		print OUT $img->png();
		close OUT;
	}

	for my $dir (@dirs) {
		$img = $cvs_log->EnergyGD($tags, $dir, $dir, 600, 400);

		if (defined $img) {
			my $e_img = "e_${title}_${dir}.png";
			$e_img =~ s/\//_/g;
			my $filename = (defined $output) ? $output . "/" . $e_img : $e_img;
			open OUT, "> $filename"
					or die "can't open $filename ($!).\n";
			binmode OUT, ":raw";
			print OUT $img->png();
			close OUT;
		}
	}
}

#######################################################################

sub GenerateHTML {
	my ($output, $title, @dirs) = @_;

my $html = q{
<?xml version='1.0' encoding='ISO-8859-1'?>
<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Strict//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd'>
<html xmlns='http://www.w3.org/1999/xhtml'>
  <head>
    <meta http-equiv='Content-Type' content='text/html; charset=ISO-8859-1' />
    <meta name='generator' content='<TMPL_VAR NAME=generator>' />
    <meta name='date' content='<TMPL_VAR NAME=date>' />
    <title>cvs_energy <!-- TMPL_VAR NAME=title --></title>
    <style type='text/css'>
      h1 {text-align: center}
    </style>
  </head>
  <body>
  <h1><!-- TMPL_VAR NAME=title --></h1>
  <hr />
  <!-- TMPL_LOOP NAME=loop -->
    <h2><!-- TMPL_VAR NAME=header --></h2>
    <img src='<TMPL_VAR NAME=img>' />
    <hr />
  <!-- /TMPL_LOOP -->
  <cite>Generated by cvs_energy (<!-- TMPL_VAR NAME=date -->)</cite>
  </body>
</html>
};

	my $template = new HTML::Template(
			scalarref	=> \$html
	);
	die "can't create template ($!).\n"
			unless (defined $template);

	my $now = localtime();
	my $generator = "cvs_energy " . $CVS::Metrics::VERSION . " (Perl " . $] . ")";
	my $path = "e_${title}.png";
	$path =~ s/\//_/g;
	my @loop = ( {
			header		=> $title,
			img			=> $path
	} );
	for my $dir (@dirs) {
		$path = "e_${title}_${dir}.png";
		$path =~ s/\//_/g;
		push @loop, {
				header		=> $dir,
				img			=> $path
		};
	}
	$template->param(
			generator	=> $generator,
			date		=> $now,
			title		=> $title,
			loop		=> \@loop,
	);

	my $basename = "e_${title}.html";
	my $filename = (defined $output) ? $output . "/" . $basename : $basename;
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $template->output();
	close OUT;
}

