#!/usr/bin/perl -w

use strict;

use File::Basename;
use File::Which;
use Getopt::Std;
use HTML::Template;
use Pod::Usage;

use CVS::Metrics;

my %opts;
getopts('d:f:hst:vS:', \%opts);

if ($opts{h}) {
	pod2usage(-verbose => 1);
}

if ($opts{v}) {
	print "$0\n";
	print "CVS::Metrics Version $CVS::Metrics::VERSION\n";
	exit(0);
}

my $cfg = ".cvs_metrics";
our ($title, $regex_tag, @dirs, $flg_css, $start_date);
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

if ($opts{s}) {
	$flg_css = 1;
}

unless (defined $regex_tag) {
	$regex_tag = '\d+';
}

if ($opts{S}) {
	$start_date = $opts{S};
} else {
	$start_date = "2003/01/01" unless (defined $start_date);
}

=head1 NAME

cvs_current - Extract from cvs log

=head1 SYNOPSIS

cvs_current [B<-f> I<file.log>] [B<-t> I<title>] [B<-s>] [B<-d> "I<dirs> ..."] [B<-S> I<yyyy/mm/dd>]

=head1 OPTIONS

=over 8

=item -d

List of directories.

=item -f

Mode off-line.

=item -h

Display Usage.

=item -s

use an extern style sheet (cvs_current.css).

=item -t

Specify the main title.

=item -v

Display Version.

=item -D

suppress 'dead' files in tree.

=item -S

Specify the start date (yyyy/mm/dd).

=back

=head1 DESCRIPTION

B<cvs_current> parses B<cvs log> and produces HTML reports.

These reports are between the last tag and HEAD.

Each report is composed of three parts :

- activity and energy plots

- an evolution summary : numbers of added/modified/deleted files for each directory

- an detailed report : all informations about CVS commit, sorted first by directory,
after grouped by message and sorted by date.

This tool needs File::Which, GD, Chart::Plot::Canvas, HTML::Template
and Parse::RecDescent modules.

=head2 Configuration file (.cvs_metrics)

If present, B<cvs_current> reads the configuration file F<.cvs_metrics>
in the current directory. The file could contains the following variables :

 $title = "main";

 $regex_tag = '^V\d+';

 @dirs = ( "abc", "def" , "def/hij" );

 $start_date = "2003/01/01";

=head1 SEE ALSO

cvs_activity, cvs_energy, cvs_tklog, cvs_wxlog

=head1 COPYRIGHT

(c) 2004 Francois PERRAD, France. All rights reserved.

This library is distributed under the terms of the Artistic Licence.

=head1 AUTHOR

Francois PERRAD, francois.perrad@gadz.org

=cut

my $parser = new CVS::Metrics::Parser();
if ($parser) {
	our $cvs_log = $parser->parse($cvs_logfile);

	our @tags;
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

	my $tag_from = $tags[-1];
	push @tags, "HEAD";
	$cvs_log->insertHead();

	my @html = ();
	push @html, GenerateHTML($cvs_log, \@tags, $title, ".", $tag_from, "HEAD", $flg_css, $start_date);
	for my $path (@dirs) {
		push @html, GenerateHTML($cvs_log, \@tags, $title, $path, $tag_from, "HEAD", $flg_css, $start_date);
	}
	GenerateSummary($title, $flg_css, \@html);
}

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

sub GenerateHTML {
	my ($cvs_log, $tags, $title, $path, $tag_from, $tag_to, $flg_css, $start_date) = @_;

my $html = q{
<?xml version='1.0' encoding='ISO-8859-1'?>
<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Transitional//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd'>
<html xmlns='http://www.w3.org/1999/xhtml'>
  <head>
    <meta http-equiv='Content-Type' content='text/html; charset=ISO-8859-1' />
    <meta name='generator' content='<TMPL_VAR NAME=generator>' />
    <meta name='date' content='<TMPL_VAR NAME=date>' />
    <title>cvs_current <!-- TMPL_VAR NAME=title --></title>
    <!-- TMPL_IF NAME=css -->
    <link href='cvs_current.css' rel='stylesheet' type='text/css'/>
    <!-- TMPL_ELSE -->
    <style type='text/css'>
      <!-- TMPL_VAR NAME=style -->
    </style>
    <!-- /TMPL_IF -->
  </head>
  <body>
  <h1>Evolution Report</h1>
  <h1><!-- TMPL_VAR NAME=title --></h1>
  <hr />
  <h2>Activity</h2>
  <img src='<TMPL_VAR NAME=a_img>' />
  <h2>Context</h2>
  <table class='layout'>
    <tr>
      <td valign='top'><img src='<TMPL_VAR NAME=e_img>' /></td>
      <td valign='top'>
        <table border='1' cellpadding='5'>
          <tr>
            <th>Tag</th>
            <th>Date</th>
          </tr>
        <!-- TMPL_LOOP NAME=timed_tag -->
          <tr>
            <td><!-- TMPL_VAR NAME=tag --></td>
            <td><!-- TMPL_VAR NAME=timed --></td>
          </tr>
        <!-- /TMPL_LOOP -->
        </table>
      </td>
    </tr>
  </table>
  <hr />
  <h2>Evolution Report Summary</h2>
  <table border='1' cellpadding='5'>
    <tr>
      <th width='40%'>Directories</th>
      <th width='20%'>Added files</th>
      <th width='20%'>Modified files</th>
      <th width='20%'>Deleted files</th>
    </tr>
  <!-- TMPL_LOOP NAME=summary -->
    <tr>
      <td><a href='#<TMPL_VAR NAME=dir>'><!-- TMPL_VAR NAME=dir --></a></td>
      <td><!-- TMPL_VAR NAME=added --></td>
      <td><!-- TMPL_VAR NAME=modified --></td>
      <td><!-- TMPL_VAR NAME=deleted --></td>
    </tr>
  <!-- /TMPL_LOOP -->
  </table>
  <hr />
  <h2>Detailed Evolution Report</h2>
  <table border='1' cellpadding='5'>
    <tr>
      <th width='20%'>Directories</th>
      <th width='40%'>Messages</th>
      <th width='30%'>File Descriptions</th>
      <th width='10%'>Actions</th>
    </tr>
  <!-- TMPL_LOOP NAME=dirs --><tr>
      <td valign='top' rowspan='<TMPL_VAR NAME=rowspan>'><a id='<TMPL_VAR NAME=dir>'
                 name='<TMPL_VAR NAME=dir>' /><!-- TMPL_VAR NAME=dir --></td>
    <!-- TMPL_LOOP NAME=comments -->
      <!-- TMPL_UNLESS NAME=__FIRST__ --><tr><!-- /TMPL_UNLESS -->
      <td valign='top' rowspan='<TMPL_VAR NAME=rowspan>'><!-- TMPL_VAR NAME=comment --></td>
      <!-- TMPL_LOOP NAME=files -->
        <!-- TMPL_UNLESS NAME=__FIRST__ --><tr><!-- /TMPL_UNLESS -->
        <td><span class='filename'><!-- TMPL_VAR NAME=filename --></span>
            <span class='revision'><!-- TMPL_VAR NAME=revision --></span><br />
          <!-- TMPL_LOOP NAME=tags -->
            <span class='tag'><!-- TMPL_VAR NAME=tag --></span><br />
          <!-- /TMPL_LOOP -->
            <span class='author'><!-- TMPL_VAR NAME=author --></span>
            <span class='date'><!-- TMPL_VAR NAME=date --></span></td>
        <td><!-- TMPL_VAR NAME=action --></td>
      </tr><!-- /TMPL_LOOP -->
    <!-- /TMPL_LOOP -->
  <!-- /TMPL_LOOP -->
  </table>
  <hr />
  <cite>Generated by cvs_current (<!-- TMPL_VAR NAME=date -->)</cite>
  </body>
</html>
};

my $style = q{
      body  { background-color: #FFFFCC }
      table { background-color: #FFFFFF }
      th    { background-color: #DCDCDC }
      h1    { text-align: center }
      h2    { color: red }
      td a  { font-weight: bold }
      table.layout  { background-color: #FFFFCC }
      span.author   { font-weight: bold }
      span.filename { color: blue }
      span.revision { font-weight: bold; color: blue }
      span.tag      { font-weight: bold }
      span.date     { }
      span.deleted  { font-weight: bold; color: red }
      span.added    { font-weight: bold; color: blue }
      span.modified { font-weight: bold }
};

	my $template = new HTML::Template(
			loop_context_vars	=> 1,
			scalarref			=> \$html,
	);
	die "can't create template ($!).\n"
			unless (defined $template);

	my $now = localtime();
	my $generator = "cvs_current " . $CVS::Metrics::VERSION . " (Perl " . $] . ")";
	my $dir = $path eq "." ? "all" : $path;
	my $title_full = "${title}_${dir}_${tag_from}_to_${tag_to}";
	$title_full =~ s/\//_/g;

	my $image = $cvs_log->EnergyGD($tags, $path, $dir, 600, 400, $tag_from, $tag_to);

	my $e_img = "e_${title_full}.png";
	$e_img =~ s/\//_/g;
	if (defined $image) {
		open OUT, "> $e_img"
				or die "can't open $e_img ($!).\n";
		binmode OUT, ":raw";
		print OUT $image->png();
		close OUT;
	}

	my $timed_tag = $cvs_log->getTimedTag();
	my @timed_tag = ();
	foreach my $tag (@{$tags}) {
		if ($tag eq "HEAD") {
			push @timed_tag, {
					tag		=> $tag,
					timed	=> "now",
			};
		} else {
			push @timed_tag, {
					tag		=> $tag,
					timed	=> substr($timed_tag->{$tag}, 0, 10),
			};
		}
	}

	my $date_from = substr($timed_tag->{$tag_from}, 0, 10);
	my $date_to = substr($timed_tag->{$tag_to}, 0, 10);
	$image = $cvs_log->ActivityGD($path, $dir, $start_date, 800, 225, $date_from, $date_to);

	my $a_img = "a_${title_full}.png";
	$a_img =~ s/\//_/g;
	if (defined $image) {
		open OUT, "> $a_img"
				or die "can't open $a_img ($!).\n";
		binmode OUT, ":raw";
		print OUT $image->png();
		close OUT;
	}

	my $dir_evol = $cvs_log->getDirEvolution($path, $tag_from, $tag_to);
	my @summary = ();
	foreach my $dirname (sort keys %{$dir_evol}) {
		my @val = @{$dir_evol->{$dirname}};
		next unless ($val[0] or $val[1] or $val[2]);
		push @summary, {
			dir			=> $dirname,
			added		=> $val[0],
			modified	=> $val[1],
			deleted		=> $val[2],
		};
	}

	my $evol = $cvs_log->getEvolution($path, $tag_from, $tag_to);
	my @dirs = ();
	foreach my $dirname (sort keys %{$evol}) {
		my $dir = $evol->{$dirname};
		my %date_sorted;
		next unless (scalar keys %{$dir});
		foreach my $message (keys %{$dir}) {
			my $files = $dir->{$message};
			my $file0 = $files->[0];
			$date_sorted{$file0->{date}} = $message;
		}
		my $rowspan1 = 0;
		my @comments = ();
		foreach (sort keys %date_sorted) {
			my $message = $date_sorted{$_};
			my $files = $dir->{$message};
			my $rowspan2 = 0;
			my @files = ();
			foreach my $file (@{$files}) {
				my @tags = ();
				foreach my $tag (sort @{$file->{tags}}) {
					push @tags, {
						tag			=> $tag,
					};
				}
				my $action;
				if ($file->{state} eq 'dead') {
					$action = "<span class='deleted'>DELETED</span>";
				} else {
					if ($file->{revision} =~ /^1(\.1)+$/) {
						$action = "<span class='added'>ADDED</span>";
					} else {
						$action = "<span class='modified'>MODIFIED</span>";
					}
				}
				push @files, {
					filename	=> basename($file->{filename}),
					revision	=> $file->{revision},
					date		=> $file->{date},
					author		=> $file->{author},
					action		=> $action,
					tags		=> \@tags,
				};
				$rowspan1 ++;
				$rowspan2 ++;
			}
			$message =~ s/&/&amp;/g;
			$message =~ s/</&lt;/g;
			$message =~ s/>/&gt;/g;
			$message =~ s/\n/<br \/>/g;
			push @comments, {
				rowspan		=> $rowspan2,
				comment		=> $message,
				files		=> \@files,
			};
		}
		push @dirs, {
			rowspan		=> $rowspan1,
			dir			=> $dirname,
			comments	=> \@comments,
		}
	}

	$template->param(
			css			=> $flg_css,
			style		=> $style,
			generator	=> $generator,
			date		=> $now,
			title		=> $title_full,
			e_img		=> $e_img,
			a_img		=> $a_img,
			timed_tag	=> \@timed_tag,
			summary		=> \@summary,
			dirs		=> \@dirs,
	);

	my $filename = "${title_full}.html";
	$filename =~ s/\//_/g;
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $template->output();
	close OUT;

	if ($flg_css) {
		my $stylesheet = "cvs_current.css";
		unless (-e $stylesheet) {
			open OUT, "> $stylesheet"
					or die "can't open $stylesheet ($!)\n";
			print OUT $style;
			close OUT;
		}
	}

	return $filename;
}

sub GenerateSummary {
	my ($title, $flg_css, $r_html) = @_;

my $html = q{
<?xml version='1.0' encoding='ISO-8859-1'?>
<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Transitional//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd'>
<html xmlns='http://www.w3.org/1999/xhtml'>
  <head>
    <meta http-equiv='Content-Type' content='text/html; charset=ISO-8859-1' />
    <meta name='generator' content='<TMPL_VAR NAME=generator>' />
    <meta name='date' content='<TMPL_VAR NAME=date>' />
    <title>cvs_current <!-- TMPL_VAR NAME=title --></title>
    <!-- TMPL_IF NAME=css -->
    <link href='cvs_current.css' rel='stylesheet' type='text/css'/>
    <!-- TMPL_ELSE -->
    <style type='text/css'>
      <!-- TMPL_VAR NAME=style -->
    </style>
    <!-- /TMPL_IF -->
  </head>
  <body>
  <h1><!-- TMPL_VAR NAME=title --></h1>
  <hr />
  <h2>Reports Index</h2>
  <ul>
  <!-- TMPL_LOOP NAME=rpts -->
    <li><a href='<TMPL_VAR NAME=href>'><!-- TMPL_VAR NAME=href --></a></li>
  <!-- /TMPL_LOOP -->
  </ul>
  <hr />
  <cite>Generated by cvs_current (<!-- TMPL_VAR NAME=date -->)</cite>
  </body>
</html>
};

my $style = q{
      body  { background-color: #FFFFCC }
      h1    { text-align: center }
      h2    { color: red }
};

	my $template = new HTML::Template(
			loop_context_vars	=> 1,
			scalarref			=> \$html,
	);
	die "can't create template ($!).\n"
			unless (defined $template);

	my $now = localtime();
	my $generator = "cvs_current " . $CVS::Metrics::VERSION . " (Perl " . $] . ")";

	my @rpts = ();
	foreach (@{$r_html}) {
		push @rpts, {
			href		=> $_,
		}
	}

	$template->param(
			css			=> $flg_css,
			style		=> $style,
			generator	=> $generator,
			date		=> $now,
			title		=> $title,
			rpts		=> \@rpts,
	);

	my $filename = "current.html";
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $template->output();
	close OUT;
}

