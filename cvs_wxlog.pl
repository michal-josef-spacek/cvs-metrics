#!/usr/bin/perl -w

use strict;

use Getopt::Std;
use File::Which;
use Wx;

use CVS::Metrics;

my %opts;
getopts('f:hst:DHS:', \%opts);

if ($opts{h}) {
	print "Usage: $0 [-h] [-f file.log] [-s] [-t title] [-D] [-H] [-S \"yyyy/mm/dd\"]\n";
	print "\t-h : help\n";
	print "\t-f file.log : off-line mode\n";
	print "\t-s : use an extern style sheet\n";
	print "\t-t title\n";
	print "\t-D : suppress 'dead' files in tree\n";
	print "\t-H : append HEAD as a tag\n";
	print "\t-S start_date : yyyy/mm/dd \n";
	exit(0);
}

my $cfg = ".cvs_metrics";
our ($title, $regex_tag, $flg_head, $flg_dead, $flg_css, $start_date);
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

if ($opts{t}) {
	$title = $opts{t};
} else {
	$title = "total" unless (defined $title);
}

if ($opts{H}) {
	$flg_head = 1;
}

if ($opts{D}) {
	$flg_dead = 1;
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

cvs_tklog - Extract from cvs log

=head1 SYNOPSYS

cvs_tklog [B<-h>] [B<-f> I<file.log>] [B<-t> I<title>] [B<-s>] [B<-D>] [B<-H>] [B<-S> I<yyyy/mm/dd>]

=head1 OPTIONS

=over 8

=item -h

Display Usage.

=item -f

Mode off-line.

=item -s

use an extern style sheet (cvs_tklog.css).

=item -t

Specify the main title.

=item -D

suppress 'dead' files in tree.

=item -H

append HEAD as a tag.

=item -S

Specify the start date (yyyy/mm/dd).

=back

=head1 DESCRIPTION

B<cvs_wxlog> parses B<cvs log> and produces selected HTML reports.

The wxWindows GUI allows to select a directory and a couple of from/to tags.

Each report is composed of three parts :

- activity and energy plots

- an evolution summary : numbers of added/modified/deleted files for each directory

- an detailed report : all informations about CVS commit, sorted first by directory,
after grouped by message and sorted by date.

This tool needs Wx, Wx::ActiveX, File::Which, GD, Chart::Plot::Canvas,
HTML::Template and Parse::RecDescent modules.

=head2 Configuration file (.cvs_metrics)

If present, B<cvs_wxlog> reads the configuration file F<.cvs_metrics>
in the current directory. The file could contains the following variables :

 $title = "main";

 $regex_tag = '^V\d+';

 $flg_head = 1;		# or 0

 $flg_dead = 1;		# or 0

 $start_date = "2002/01/01";

=head1 SEE ALSO

cvs_activity, cvs_energy, cvs_tklog

=head1 AUTHOR

Francois PERRAD, francois.perrad@gadz.org

=cut

my $parser = new CVS::Metrics::Parser();
if ($parser) {
	our $cvs_log = $parser->parse($cvs_logfile);

	our @tags;
	my @tagname = $cvs_log->getTagname();
	foreach my $tag (sort @tagname) {
		print "Tag: ", $tag;
		if ($tag =~ /$regex_tag/) {
			push @tags, $tag;
			print " ... matched";
		}
		print "\n";
	}

	if ($flg_head) {
		push @tags, "HEAD";
		$cvs_log->insertHead();
	}

	my $app = new MyApp();
	$app->MainLoop();
}

sub FindCvs {
	my $cvs = which('cvs');

	if ( !defined $cvs and $^O eq 'MSWin32' ) {
		use Win32::TieRegistry(Delimiter => "/");

		my $cvs_setting = $Registry->{"HKEY_CURRENT_USER/Software/WinCvs/wincvs/CVS settings"};
		$cvs = $cvs_setting->{'/P_WhichCvs'};
		if (defined $cvs) {
			$cvs =~ s/[\000\001]//g;
			$cvs =~ s/wincvs\.exe\@$/cvs.exe/;
		}
	}

	die "$cvs not found !\n" unless (defined $cvs);

	warn "Using CVS : $cvs\n";
	return '"' . $cvs . '"';
}

#######################################################################

package MyIEFrame;

use strict;
use base qw(Wx::Frame);

use Wx::ActiveX::IE;
use Wx qw(:sizer);
use Wx qw(wxDefaultPosition wxDefaultSize);

sub new {
	my $class = shift;
	my ($title, $url) = @_;

	my $self = $class->SUPER::new(undef, -1, $title,
			wxDefaultPosition, wxDefaultSize);
	$self->SetIcon(Wx::GetWxPerlIcon());

	my $IE = Wx::ActiveX::IE->new( $self , -1 , wxDefaultPosition , wxDefaultSize );
	$IE->LoadUrl($url);

	my $top_s = new Wx::BoxSizer(wxVERTICAL);
	$top_s->Add($IE, 1, wxGROW|wxALL, 0);

	$self->SetSizer($top_s);
	$self->SetAutoLayout(1);

	return $self;
}

#######################################################################

package MyFrame;

use strict;
use base qw(Wx::Frame);

use File::Basename;

use Wx::Event qw(EVT_MENU EVT_BUTTON EVT_COMBOBOX EVT_TREE_SEL_CHANGED);
use Wx qw(:window :sizer :treectrl :bitmap :button :combobox :statictext :icon :color);
use Wx qw(wxDefaultPosition wxDefaultSize wxOK);

use constant ID_QUIT	=> 10000;

sub new {
	my $class = shift;
	my $model = shift;
	my $self = $class->SUPER::new(@_);
	$self->{model} = $model;

	$self->CreateStatusBar(1);
	$self->SetBackgroundColour(wxLIGHT_GREY);
	$self->SetIcon(Wx::GetWxPerlIcon());

	$self->CreateMyMenuBar();
	$self->CreateMyTreeCtrl();

	my $rightsizer = new Wx::BoxSizer(wxVERTICAL);
	my $bottomsizer = new Wx::BoxSizer(wxHORIZONTAL);
	my $topsizer = new Wx::BoxSizer(wxHORIZONTAL);

	if (scalar(@{$model->{tags}}) >= 2) {
		my $b_audit = new Wx::Button($self, -1, "Audit :");

		my @tags_from = @{$model->{tags}};
		pop @tags_from;
		my @tags_to = @{$model->{tags}};
		shift @tags_to;

		my $cb_from = new Wx::ComboBox($self, -1, $model->{tag_from},
				wxDefaultPosition, wxDefaultSize,
				\@tags_from, wxCB_READONLY);

		my $cb_to = new Wx::ComboBox($self, -1, $model->{tag_to},
				wxDefaultPosition, wxDefaultSize,
				\@tags_to, wxCB_READONLY);

		my $l_from = new Wx::StaticText($self, -1, "from",
				wxDefaultPosition, wxDefaultSize, wxST_NO_AUTORESIZE );
		my $l_to = new Wx::StaticText($self, -1, "to",
				wxDefaultPosition, wxDefaultSize, wxST_NO_AUTORESIZE );

		EVT_BUTTON($self, $b_audit, \&OnAudit);
		EVT_COMBOBOX($self, $cb_from, \&OnComboFrom);
		EVT_COMBOBOX($self, $cb_to, \&OnComboTo);

		$bottomsizer->Add($b_audit, 0, wxALL, 2);
		$bottomsizer->Add($l_from, 0, wxALL, 2);
		$bottomsizer->Add($cb_from, 0, wxALL, 2);
		$bottomsizer->Add($l_to, 0, wxALL, 2);
		$bottomsizer->Add($cb_to, 0, wxALL, 2);
	}

	$self->{bmp} = new Wx::StaticBitmap($self, -1, new Wx::Bitmap(600, 400, -1));

	$rightsizer->Add($self->{bmp}, 0, wxALL|wxALIGN_CENTER, 1);
	$rightsizer->Add($bottomsizer, 0, wxALL|wxALIGN_CENTER, 8);

	$topsizer->Add($self->{tree}, 1, wxEXPAND);
	$topsizer->Add($rightsizer, 0, wxALL);

	EVT_MENU($self, ID_QUIT, sub { $self->Close(); });
	EVT_TREE_SEL_CHANGED($self, $self->{tree}, \&OnSelChange);

	$self->SetSizer($topsizer);
	$self->SetAutoLayout(1);
	$topsizer->Fit($self);
	$topsizer->SetSizeHints($self);

	return $self;
}

sub CreateMyMenuBar {
	my $self = shift;

	my $bar = new Wx::MenuBar();

	my $file = new Wx::Menu();
	$file->Append(ID_QUIT, "E&xit");

	$bar->Append($file, "&File");

	$self->SetMenuBar($bar);
}

sub CreateMyImageList {
	my $self = shift;

	my $imagelist = new Wx::ImageList(16, 16, 3);

	my $xpm_open_folder = [
		# columns rows colors chars-per-pixel
		"32 32 7 1",
		"+ c Black",
		"@ c #808000",
		"O c #C0C0C0",
		"o c #FFFF00",
		"  c None",
		"X c #FFFFFF",
		". c #808080",
		# pixels
		"                                ",
		"                                ",
		"       .........                ",
		"      .XXXXXXXXX.               ",
		"     .XoOoOoOoOoO.              ",
		"    .XoOoOoOoOoOoO.             ",
		"   .XoOoOoOoOoOoOoO...........  ",
		"   .XOoOoOoOoOoOoOoXXXXXXXXXXX+ ",
		"   .XoOoOoOoOoOoOoOoOoOoOoOoOo@+",
		"   .XOoOoOoOoOoOoOoOoOoOoOoOoO@+",
		"   .XoOoOoOoOoOoOoOoOoOoOoOoOo@+",
		" ..OOOOOOOOOOOOOOOOOOOOOOOOOoO@+",
		".XXXXXXXXXXXXXXXXXXXXXXXXXX+.o@+",
		".oOoOoOoOoOoOoOoOoOoOoOoOoO.+O@+",
		".OoOoOoOoOoOoOoOoOoOoOoOoOo.+o@+",
		".oOoOoOoOoOoOoOoOoOoOoOoOoOo+.@+",
		".OoOoOoOoOoOoOoOoOoOoOoOoOoO+.@+",
		" .OoOoOoOoOoOoOoOoOoOoOoOoOo.+@+",
		" .oOoOoOoOoOoOoOoOoOoOoOoOoO.+@+",
		" .OoOoOoOoOoOoOoOoOoOoOoOoOoO+@+",
		" .oOoOoOoOoOoOoOoOoOoOoOoOoOo+@+",
		"  .oOoOoOoOoOoOoOoOoOoOoOoOoO.++",
		"  .OoOoOoOoOoOoOoOoOoOoOoOoOo.++",
		"  .oOoOoOoOoOoOoOoOoOoOoOoOoOO++",
		"  .OoOoOoOoOoOoOoOoOoOoOoOoOoO++",
		"   .OoOoOoOoOoOoOoOoOoOoOoOoOo@+",
		"   .oOoOoOoOoOoOoOoOoOoOoOoOoO@+",
		"   .@@@@@@@@@@@@@@@@@@@@@@@@@@@+",
		"    +++++++++++++++++++++++++++ ",
		"                                ",
		"                                ",
		"                                "
	];

	my $xpm_closed_folder = [
		# columns rows colors chars-per-pixel
		"32 32 7 1",
		"+ c Black",
		"@ c #808000",
		"O c #C0C0C0",
		"o c #FFFF00",
		"  c None",
		"X c #FFFFFF",
		". c #808080",
		# pixels
		"                                ",
		"                                ",
		"                                ",
		"     .........                  ",
		"    .XXXXXXXXX.                 ",
		"   .XoOoOoOoOoO.                ",
		"  .XoOoOoOoOoOoO.               ",
		" .OOOOOOOOOOOOOOO............   ",
		" .XXXXXXXXXXXXXXXXXXXXXXXXXXX+  ",
		" .XoOoOoOoOoOoOoOoOoOoOoOoOoO@+ ",
		" .XOoOoOoOoOoOoOoOoOoOoOoOoOo@+ ",
		" .XoOoOoOoOoOoOoOoOoOoOoOoOoO@+ ",
		" .XOoOoOoOoOoOoOoOoOoOoOoOoOo@+ ",
		" .XoOoOoOoOoOoOoOoOoOoOoOoOoO@+ ",
		" .XOoOoOoOoOoOoOoOoOoOoOoOoOo@+ ",
		" .XoOoOoOoOoOoOoOoOoOoOoOoOoO@+ ",
		" .XOoOoOoOoOoOoOoOoOoOoOoOoOo@+ ",
		" .XoOoOoOoOoOoOoOoOoOoOoOoOoO@+ ",
		" .XOoOoOoOoOoOoOoOoOoOoOoOoOo@+ ",
		" .XoOoOoOoOoOoOoOoOoOoOoOoOoO@+ ",
		" .XOoOoOoOoOoOoOoOoOoOoOoOoOo@+ ",
		" .XoOoOoOoOoOoOoOoOoOoOoOoOoO@+ ",
		" .XOoOoOoOoOoOoOoOoOoOoOoOoOo@+ ",
		" .XoOoOoOoOoOoOoOoOoOoOoOoOoO@+ ",
		" .XOoOoOoOoOoOoOoOoOoOoOoOoOo@+ ",
		" .XoOoOoOoOoOoOoOoOoOoOoOoOoO@+ ",
		" ............................@+ ",
		"  ++++++++++++++++++++++++++++  ",
		"                                ",
		"                                ",
		"                                ",
		"                                "
	];

	my $xpm_docl = [
		# columns rows colors chars-per-pixel
		"32 32 5 1",
		"o c Black",
		"O c #C0C0C0",
		"  c None",
		"X c #FFFFFF",
		". c #808080",
		# pixels
		"   ....................         ",
		"   .XXXXXXXXXXXXXXXXXX.o        ",
		"   .XXXXXXXXXXXXXXXXXX..o       ",
		"   .XXXXXXXXXXXXXXXXXX.O.o      ",
		"   .XXXXXXXXXXXXXXXXXX.XO.o     ",
		"   .XXXXXXXXXXXXXXXXXX.XXO.o    ",
		"   .XXXXXXXXXXXXXXXXXX.oooooo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .XXXXXXXXXXXXXXXXXXXXXXXOo   ",
		"   .OOOOOOOOOOOOOOOOOOOOOOOOo   ",
		"   oooooooooooooooooooooooooo   "
	];

	my $binpath = $0;
	$binpath =~ s/[^\\\/]+$//;
	my $open_folder = new Wx::Image(Wx::Bitmap->newFromXPM($xpm_open_folder));
	$open_folder = new Wx::Bitmap($open_folder->Rescale(16,16));
	$imagelist->Add($open_folder);
	my $closed_folder = new Wx::Image(Wx::Bitmap->newFromXPM($xpm_closed_folder));
	$closed_folder = new Wx::Bitmap($closed_folder->Rescale(16,16));
	$imagelist->Add($closed_folder);
	my $doc = new Wx::Image(Wx::Bitmap->newFromXPM($xpm_docl));
	$doc = new Wx::Bitmap($doc->Rescale(16,16));
	$imagelist->Add($doc);
	return $imagelist;
}

sub CreateMyTreeCtrl {
	my $self = shift;
	my $model = $self->{model};

	$self->{tree} = new Wx::TreeCtrl($self, -1, wxDefaultPosition, [150, 400],
			wxTR_HAS_BUTTONS|wxSUNKEN_BORDER);

	$self->{imagelist} = $self->CreateMyImageList();
	$self->{tree}->SetImageList($self->{imagelist});

	my %dir = (
		'.'		=> 1
	);
	while (my ($filename, $file) = each %{$model->{cvs_log}}) {
		if ($model->{flg_dead}) {
			my $head = $file->{head};
			my $state = $file->{description}->{$head}->{state};
			next if ($state eq "dead");
		}
		my $path = dirname($filename);
		$dir{$path} = 1;
		while (($path = dirname($path)) ne '.') {
			$dir{$path} = 1;
		}
	}

	# populate TreeCtrl
	$dir{'.'} = $self->{tree}->AddRoot($model->{title}, -1, -1, new Wx::TreeItemData('.'));

	foreach my $path (sort keys %dir) {
		unless ($path eq '.') {
			my $parent = $dir{dirname($path)};
			$dir{$path} = $self->{tree}->AppendItem($parent, basename($path), -1, -1, new Wx::TreeItemData($path));
		}
	}

	while (my ($path, $item) = each %dir) {
		if ($self->{tree}->GetChildrenCount($item) > 0) {
			$self->{tree}->SetItemImage($item, 1, wxTreeItemIcon_Normal);	# Closed Folder
			$self->{tree}->SetItemImage($item, 1, wxTreeItemIcon_Selected);	# Closed Folder
			$self->{tree}->SetItemImage($item, 0, wxTreeItemIcon_Expanded);	# Open Folder
			if (dirname($path) eq '.') {
				$self->{tree}->Expand($item);
			}
		} else {
			$self->{tree}->SetItemImage($item, 2, wxTreeItemIcon_Normal);	# Doc
			$self->{tree}->SetItemImage($item, 2, wxTreeItemIcon_Selected);	# Doc
		}
	}
}

sub OnSelChange {
	my ($self, $event) = @_;
	my $model = $self->{model};

	my $item = $event->GetItem();
	$model->{path} = $self->{tree}->GetPlData($item);
	$self->SetStatusText($model->{path}, 0);

	my $gd = $model->GenerateBMP();

	use File::Temp qw(tmpnam);
	my $file = tmpnam();
	open OUT, "> $file"
			or die "can't open $file ($!).";
	binmode OUT, ":raw";
	print OUT $gd->png();
	close OUT;
	my $img = new Wx::Image($file, wxBITMAP_TYPE_PNG);
	unlink $file;
	$self->{bmp}->SetBitmap(new Wx::Bitmap($img));
}

sub OnComboFrom {
	my ($self, $event) = @_;

	$self->{model}->{tag_from} = $event->GetString();
}

sub OnComboTo {
	my ($self, $event) = @_;

	$self->{model}->{tag_to} = $event->GetString();
}

sub OnAudit {
	my ($self, $event) = @_;
	my $model = $self->{model};

	if (        $model->{tag_to} ne 'HEAD'
			and $model->{tag_from} ge $model->{tag_to} ) {
		my $msg = new Wx::MessageDialog($self, "$model->{tag_from} >= $model->{tag_to}",
				"CVS log", wxICON_ERROR|wxOK, wxDefaultPosition);
		$msg->ShowModal();
		return;
	}

	my $html = $model->GenerateHTML();
	if (Wx::wxMSW()) {
		use Cwd;
		my $title = $html;
		$title =~ s/\.\w+$//;
		my $url = "file://" . cwd() . "/" . $html;
		my $ie = new MyIEFrame($title, $url);
		$ie->Show(1);
	}
}

#######################################################################

package MyModel;

use strict;
use HTML::Template;
use File::Basename;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {
			cvs_log		=> $main::cvs_log,
			tags		=> \@main::tags,
			title		=> $main::title,
			flg_dead	=> $main::flg_dead,
			flg_css		=> $main::flg_css,
			start_date	=> $main::start_date,
	};
	bless($self, $class);
	$self->{path} = '.';
	if (scalar(@{$self->{tags}}) >= 2) {
		$self->{tag_from} = ${$self->{tags}}[-2];
		$self->{tag_to} = ${$self->{tags}}[-1];
	}
	return $self;
}

sub GenerateBMP {
	my $self = shift;

	my $title = ($self->{path} eq '.') ? $self->{title} : $self->{path};
	my $gd = $self->{cvs_log}->EnergyGD($self->{tags}, $self->{path}, $title, 600, 400);
	return $gd;
}

sub GenerateHTML {
	my $self = shift;

my $html = q{
<?xml version='1.0' encoding='ISO-8859-1'?>
<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Transitional//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd'>
<html xmlns='http://www.w3.org/1999/xhtml'>
  <head>
    <meta http-equiv='Content-Type' content='text/html; charset=ISO-8859-1' />
    <meta name='generator' content='<TMPL_VAR NAME=generator>' />
    <meta name='date' content='<TMPL_VAR NAME=date>' />
    <title>cvs_tklog <!-- TMPL_VAR NAME=title --></title>
    <!-- TMPL_IF NAME=css -->
    <link href='cvs_tklog.css' rel='stylesheet' type='text/css'/>
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
  <cite>Generated by cvs_tklog (<!-- TMPL_VAR NAME=date -->)</cite>
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
	my $generator = "cvs_tklog " . $CVS::Metrics::VERSION . " (Perl " . $] . ")";
	my $dir = $self->{path} eq "." ? "all" : $self->{path};
	my $title_full = "$self->{title}_${dir}_$self->{tag_from}_to_$self->{tag_to}";
	$title_full =~ s/\//_/g;

	my $image = $self->{cvs_log}->EnergyGD($self->{tags}, $self->{path}, $dir, 600, 400, $self->{tag_from}, $self->{tag_to});

	my $e_img = "e_${title_full}.png";
	$e_img =~ s/\//_/g;
	open OUT, "> $e_img"
			or die "can't open $e_img ($!).\n";
	binmode OUT, ":raw";
	print OUT $image->png();
	close OUT;

	my $timed_tag = $self->{cvs_log}->getTimedTag();
	my @timed_tag = ();
	foreach my $tag (@{$self->{tags}}) {
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

	my $date_from = substr($timed_tag->{$self->{tag_from}}, 0, 10);
	my $date_to = substr($timed_tag->{$self->{tag_to}}, 0, 10);
	$image = $self->{cvs_log}->ActivityGD($self->{path}, $dir, $self->{start_date}, 800, 225, $date_from, $date_to);

	my $a_img = "a_${title_full}.png";
	$a_img =~ s/\//_/g;
	open OUT, "> $a_img"
			or die "can't open $a_img ($!).\n";
	binmode OUT, ":raw";
	print OUT $image->png();
	close OUT;

	my $dir_evol = $self->{cvs_log}->getDirEvolution($self->{path}, $self->{tag_from}, $self->{tag_to});
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

	my $evol = $self->{cvs_log}->getEvolution($self->{path}, $self->{tag_from}, $self->{tag_to});
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
		my $stylesheet = "cvs_tklog.css";
		unless (-e $stylesheet) {
			open OUT, "> $stylesheet"
					or die "can't open $stylesheet ($!)\n";
			print OUT $style;
			close OUT;
		}
	}
	return $filename;
}

#######################################################################

package MyApp;

use strict;
use base qw(Wx::App);

# this is called automatically on object creation
sub OnInit {
	my $self = shift;

	Wx::InitAllImageHandlers();

	my $model = new MyModel();

	# create a new frame
	my $frame = new MyFrame($model, undef, -1, "CVS log - $main::title");
	# set as top frame
	$self->SetTopWindow($frame);

	# show it
	$frame->Show(1);
	$frame->{tree}->SelectItem($frame->{tree}->GetRootItem());

	return 1;
}





