#!/usr/bin/perl -w

use strict;

use File::Which;
use HTML::Template;
use CGI qw(header param);
use CGI::Carp qw(fatalsToBrowser);

use CVS::Metrics;

my $extract = param("extract");
my $repository = param("repository");
my $module = param("module");
my $viewcvs = param("viewcvs");
my $cvs_root = $extract . "/" . $repository . "/" . $module;
chdir $cvs_root
		or die "can't change dir $cvs_root ($!).\n";

my $cfg = ".cvs_metrics";
our ($title, $regex_tag, @dirs, $start_date, $regex_ignore_tag);
if ( -r $cfg) {
	warn "reading $cfg\n";
	require $cfg;
}

unless (defined $regex_tag) {
	$regex_tag = '\d+';
}

unless (defined $start_date) {
	$start_date = "2004/01/01";
}

my $cvs = FindCvs();
my $cvs_logfile = $cvs . " log |";

=head1 NAME

cgi_cvs_evolq - Extract from cvs log

=head1 SYNOPSIS

cgi_cvs_evolq

=head1 OPTIONS

CGI parameters

=over 8

=item cvsroot

Directory.

=back

=head1 DESCRIPTION

B<cgi_cvs_evolq> parses B<cvs log> and produces an HTML form.

This form allows to call B<cgi_cvs_evolr>.

=head2 Configuration file (.cvs_metrics)

If present, B<cgi_cvs_evolq> reads the configuration file F<.cvs_metrics>
in the current directory. The file could contains the following variables :

 $title = "main";

 $regex_tag = '^V\d+';

 @dirs = ( "abc", "def" , "def/hij" );

 $start_date = "2003/01/01";

=head1 SEE ALSO

cvs_activity, cvs_energy, cvs_tklog, cvs_wxlog, cvs_current

=head1 COPYRIGHT

(c) 2004 Francois PERRAD, France. All rights reserved.

This library is distributed under the terms of the Artistic Licence.

=head1 AUTHOR

Francois PERRAD, francois.perrad@gadz.org

=cut

our $cvs_log = CVS::Metrics::CvsLog(
		stream		=> $cvs_logfile,
		use_cache	=> 1,
);
if ($cvs_log) {
	our @tags;
	my $timed = $cvs_log->getTimedTag($regex_ignore_tag);
	my %matched;
	while (my ($tag, $date) = each %{$timed}) {
		if ($tag =~ /$regex_tag/) {
			$matched{$date.$tag} = $tag;
		}
	}
	foreach (sort keys %matched) {
		push @tags, $matched{$_};
	}

	my $tag_from = $tags[-1];
	push @tags, "HEAD";
	$cvs_log->insertHead();

	GenerateHTML($title, \@tags, \@dirs);
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
	my ($title, $r_tags, $r_dirs) = @_;

my $html = q{
<?xml version='1.0' encoding='ISO-8859-1'?>
<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Transitional//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd'>
<html xmlns='http://www.w3.org/1999/xhtml'>
  <head>
    <meta http-equiv='Content-Type' content='text/html; charset=ISO-8859-1' />
    <meta name='generator' content='<TMPL_VAR NAME=generator>' />
    <meta name='date' content='<TMPL_VAR NAME=date>' />
    <meta name='robots' content='nofollow' />
    <title>cvs_evol <!-- TMPL_VAR NAME=title --></title>
    <style type='text/css'>
      <!-- TMPL_VAR NAME=style -->
    </style>
  </head>
  <body>
  <h1><!-- TMPL_VAR NAME=title --></h1>
  <hr />
  <h2>Evolution Report Query</h2>
  <blockquote>
    <!-- TMPL_IF NAME=valid -->
    <form action='cgi_cvs_evolr.pl' method='get'>
      <input type='hidden' name='extract' value='<TMPL_VAR NAME=extract>'/>
      <input type='hidden' name='repository' value='<TMPL_VAR NAME=repository>'/>
      <input type='hidden' name='module' value='<TMPL_VAR NAME=module>'/>
      <input type='hidden' name='viewcvs' value='<TMPL_VAR NAME=viewcvs>'/>
      <table>
        <tr>
          <td>path :</td>
          <td>
            <select name='path'><!-- TMPL_LOOP NAME=dirs -->
              <option <!-- TMPL_IF NAME=__FIRST__ -->selected='selected'<!-- /TMPL_IF -->>
                <!-- TMPL_VAR NAME=value --></option><!-- /TMPL_LOOP -->
            </select>
          </td>
        </tr>
        <tr>
          <td>from tag :</td>
          <td>
            <select name='from_tag'><!-- TMPL_LOOP NAME=from_tags -->
              <option <!-- TMPL_IF NAME=__LAST__ -->selected='selected'<!-- /TMPL_IF -->>
                <!-- TMPL_VAR NAME=value --></option><!-- /TMPL_LOOP -->
            </select>
          </td>
        </tr>
        <tr>
          <td>to tag :</td>
          <td>
            <select name='to_tag'><!-- TMPL_LOOP NAME=to_tags -->
              <option <!-- TMPL_IF NAME=__LAST__ -->selected='selected'<!-- /TMPL_IF -->>
                <!-- TMPL_VAR NAME=value --></option><!-- /TMPL_LOOP -->
            </select>
          </td>
        </tr>
        <tr>
          <td><input type='submit'/></td>
        </tr>
        <tr>
          <td align='right'>
            <input type='checkbox' name='force' value='1'/>
          </td>
          <td>Force generation (don't use nightly extract)</td>
        </tr>
      </table>
    </form>
    <!-- TMPL_ELSE -->
    <em>Sorry, no tag available.</em>
    <!-- /TMPL_IF -->
  </blockquote>
  <hr />
  <cite>Generated by cgi_cvs_evolq (<!-- TMPL_VAR NAME=date -->)</cite>
  </body>
</html>
};

my $style = q{
      body  { background-color: #CCFFFF }
      h1    { text-align: center }
      h2    { color: red }
};

	$html =~ s/^\s+//gm;
	my $template = new HTML::Template(
			loop_context_vars	=> 1,
			scalarref			=> \$html,
	);
	die "can't create template ($!).\n"
			unless (defined $template);

	my $now = localtime();
	my $generator = "cgi_cvs_evolq " . $CVS::Metrics::VERSION . " (Perl " . $] . ")";

	my $valid = scalar(@{$r_tags}) >= 2;

	my @dirs = ();
	push @dirs, {
		value		=> ".",
	};
	foreach (@{$r_dirs}) {
		push @dirs, {
			value		=> $_,
		}
	}
	my @from_tags = ();
	foreach (@{$r_tags}) {
		push @from_tags, {
			value		=> $_,
		}
	}
	pop @from_tags;
	my @to_tags = ();
	foreach (@{$r_tags}) {
		push @to_tags, {
			value		=> $_,
		}
	}
	shift @to_tags;

	$template->param(
			style		=> $style,
			generator	=> $generator,
			date		=> $now,
			title		=> $title,
			valid		=> $valid,
			extract		=> $extract,
			repository	=> $repository,
			module		=> $module,
			viewcvs		=> $viewcvs,
			dirs		=> \@dirs,
			from_tags	=> \@from_tags,
			to_tags		=> \@to_tags,
	);

	print header(
			-type  =>  'text/html',
	);
	print $template->output();
}

