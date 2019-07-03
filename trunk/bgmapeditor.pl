#!/usr/bin/perl -w
# Copyright (c) 2006-2012, Nicolas Mazziotta
# $Id: $
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;		

my ($name,$execpath,$suffix,$main);

#######################################################
#		 Imports
#######################################################

use File::Basename;

BEGIN {
  # find where the program has been installed
  my $filename = $0;
  eval {$filename = readlink $0 if -l $0};
  ($name,$execpath,$suffix) = fileparse($filename,qw/pl/);
	$execpath =~ s/\\/\//g if $^O =~ /^MSWin/;
}
# custom
use lib "$execpath/lib";
use lib "$execpath";

# cpan
use Fcntl ':flock';
use File::Path;
use File::Spec;

use Archive::Zip;
use POSIX;
use GD;
use Encode;

use Tk;
use Tk::PNG;
use Tk::ItemStyle;
use Tk::Balloon;
use Tk::Button;
use Tk::Dialog;
use Tk::Adjuster;
use Tk::TextUndo;
use Tk::NoteBook;
use Tk::Bitmap;

use MIME::Base64;
use Switch;
$Tk::encodeFallback=1;


# Imports (importés au niveau de l'app. pour PARL)
use TilePack;
use TileRegistry;
use ConfigReader;
use ImageData;
use Tk::Map;
use Tk::Mapeditor;
use Tk::Tabber;
use Tk::TileChoser;
use Tk::TileChoser::AvButton;
use Tk::TileChoser::PackEntry;

#######################################################
#		 globals
#######################################################

my $path = "$execpath";
my $imgpath = "$path"."img";
my $tilepath = "$imgpath/tiles";
my $uiimgpath = "$imgpath/ui";
my $configfile = "$execpath"."bgmapeditor.cfg";
my $langpath = "$execpath"."lang";

#==================================================================================#


# nettoie le répertoire temporaire
eval {
	&rmtree("$execpath/tmp");
	&mkpath("$execpath/tmp")
} or print STDERR "$@\n";

# lit la configuration
my %cfg = ConfigReader::readcfg($configfile);

# charge les textes 
unless (-f $langpath."/".$cfg{lang}) {
	$cfg{lang} = "fr";
} 

my %lang = ();
open(LANG, $langpath . "/" . $cfg{lang}) or die "No language pack available!";
while (<LANG>) {
	/^(.*?)=(["']?)(.*?)(\2)$/;
	$lang{$1} = $3;
}
close(LANG);

$cfg{area} = "" unless $cfg{area};

#==================================================================================#

# Options générales du GUI
$main = MainWindow->new(-title => $lang{title});
$main->fontCreate("bgnormal", -size => "9", -family => "Helvetica");
$main->optionAdd("*font", "bgnormal");
$main->optionAdd("*borderWidth", 1);
my $tabber = $main->Tabber(-border => 1, -font=>"bgnormal")->pack(qw/-expand 1 -fill both/);
my $status = "";
$main->Label(-textvariable => \$status)->pack(qw/-side left -fill y/);

# Mise en place de l'éditeur

# Images de l'interface
my %ui = ();
opendir(IMAGESDIR, $uiimgpath);
my @uiimages = readdir IMAGESDIR or die $lang{w_corrupted};
closedir(IMAGESDIR);

foreach (@uiimages) {
	next if /^\./;
	next if /^licence$/;
	my $imagefullname = $uiimgpath."/".$_;
	next if -d $imagefullname;
	my $tkimage = $main->Photo(-data => &ImageData::encode_image64($imagefullname));
	$ui{$_} = $tkimage; 
} 



#==================================================================================#
# Menu

my $menubar = $main->Menu(-type => 'menubar', -relief => 'fl');
$main->configure(-menu => $menubar);

$menubar->Cascade(-label => $lang{m_file}, -menuitems =>
	[
		[Button => $lang{m_new}, 
			-command => sub {	&command_new_tab() },
			-image => $ui{"filenew.png"},
			-accelerator => 'Control-n',
			-compound => "left",
		],
		[Button => $lang{m_open}, 
			-command => sub {	&command_open_map },
			-image => $ui{"fileopen.png"},
			-accelerator => 'Control-o',
			-compound => "left",
		],
		[Separator => ''],
		[Button => $lang{m_save}, 
			-command => sub {	&command_save_map },
			-image => $ui{"filesave.png"},
			-accelerator => 'Control-s',
			-compound => "left",
		],
		[Button => $lang{m_save_all}, 
			-command => sub {	&command_save_all },
			-image => $ui{"save_all.png"},
			-accelerator => 'Control-s',
			-compound => "left",
		],
		[Button => $lang{m_saveas}, 
			-command => sub {	&command_saveas_map },
			-image => $ui{"filesaveas.png"},
			-accelerator => 'Control-Shift-s',
			-compound => "left",
		],
		[Button => $lang{m_convertPNG}, 
			-command => sub {	&command_convert_map },
			-image => $ui{"thumbnail.png"},
			-accelerator => 'Control-p',
			-compound => "left",
		],
		[Separator => ''],
		[Button => $lang{m_close_tab}, 
			-command => sub { &command_close_tab },
			-image => $ui{"tab_remove.png"},
			-accelerator => 'Control-w',
			-compound => "left",
		],
		[Button => $lang{m_quit}, 
			-command => sub { $main->destroy },
			-image => $ui{"exit.png"},
			-accelerator => 'Alt-F4',
			-compound => "left",
		],
	]
);

$menubar->Cascade(-label => $lang{m_edit}, -menuitems =>
	[
		[Button => $lang{m_undo}, 
			-command => sub {$tabber->raised_widget->get_map->undo_undo},
			-image => $ui{"undo.png"},
			-accelerator => 'Control-z',
			-compound => "left",
		],
		[Button => $lang{m_redo}, 
			-command => sub {$tabber->raised_widget->get_map->undo_redo},
			-image => $ui{"redo.png"},
			-accelerator => 'Control-y',
			-compound => "left",
		],
		[Separator => ''],
		[Button => $lang{m_insert}, 
			-command => sub {&command_add_tile},
			-image => $ui{"editpaste.png"},
			-accelerator => 'n',
			-compound => "left",
		],
		[Button => $lang{m_drag}, 
			-command => sub {&command_drag_map},
			-image => $ui{"view_fullscreen.png"},
			-accelerator => 'h',
			-compound => "left",
		],
		[Button => $lang{m_move}, 
			-command => sub {&command_move_tile},
			-image => $ui{"move.png"},
			-accelerator => 'Space',
			-compound => "left",
		],
		[Button => $lang{m_rotate}, 
			-command => sub {&command_rotate_tile},
			-image => $ui{"rotate_cw.png"},
			-accelerator => 'r',
			-compound => "left",
		],
		
		[Button => $lang{m_delete}, 
			-command => sub {&command_delete_tile},
			-image => $ui{"no.png"},
			-accelerator => 'd',
			-compound => "left",
		],
		[Button => $lang{m_text}, 
			-command => sub {&command_text},
			-image => $ui{"fonts.png"},
			-accelerator => 't',
			-compound => "left",
		],
	]
);

$menubar->Cascade(-label => $lang{m_packs}, -menuitems =>
	[
		[Button => $lang{m_add}, 
			-command => sub {	&command_add_package },
			-image => $ui{"edit_add.png"},
			-accelerator => 'Control-a',
			-compound => "left",
		],
		[Button => $lang{m_delete}, 
			-command => sub { &command_delete_package() },
			-image => $ui{"edit_remove.png"},
			-accelerator => 'Control-d',
			-compound => "left",
		],
	]
);

$menubar->Separator();

$menubar->Cascade(-label => $lang{m_help}, -menuitems =>
	[
		[Button => $lang{m_manual}, 
			-command => sub { 
				&command_prompt(
				-text => $lang{i_manual}
				)
			},
			-image => $ui{"help.png"},
			-hidemargin => 1,
			-compound => "left",
		],
		[Button => $lang{m_about}, 
			-command => sub { 
				&command_prompt(
					-text => $lang{i_about}
					
				) 
			},
			-image => $ui{"messagebox_info.png"},
			-compound => "left",
		],
	]
);


#==================================================================================#

$main->bind("<Control-n>" => sub {	&command_new_tab() });
$main->bind("<Control-o>" => sub {	&command_open_map() });
$main->bind("<Control-s>" => sub {	&command_save_map() });
$main->bind("<Control-S>" => sub {	&command_saveas_map() });
$main->bind("<Control-w>" => sub {	&command_close_tab() });

$main->bind("<Control-p>" => sub {	&command_convert_map() });
$main->bind("<Control-a>" => sub {	&command_add_package() });
$main->bind("<Control-d>" => sub {	&command_delete_package() });

# FIXME make cmd?
$main->bind("<Control-z>" => sub {	$tabber->raised_widget->get_map->undo_undo });
$main->bind("<Control-y>" => sub {	$tabber->raised_widget->get_map->undo_redo });

$main->bind("<d>" => sub { &command_delete_tile	});
$main->bind("<space>" => sub { &command_move_tile; });
$main->bind("<r>" => sub {	&command_rotate_tile });
$main->bind("<n>" => sub {	&command_add_tile});
$main->bind("<h>" => sub {	&command_drag_map});
$main->bind("<t>" => sub {	&command_text});


# FIXME location
#$mw->get_tile_chooser->bind("<ButtonPress-3>" => sub { $mw->show_licence });

#==================================================================================#
# Préparation des tabs

&command_new_tab unless @ARGV;
foreach (@ARGV) {
	&command_open_map($_)
}


MainLoop();

#==================================================================================#
# Actions
#
# file actions
sub command_prompt { 
	&prompt(@_) 
}
sub command_show_licence { 
	$tabber->raised_widget->show_licence() 
}
sub command_new_tab {
	my ($label) = @_;

	$label = $lang{"l_unnamed"} unless $label;
	
	my $new_tab = $tabber->tab_add(
		-label => $label,
		-raisecmd => sub {},
		-widget => 'Mapeditor',
		-options => {
			-border => 0
		}
	);
	my $editor = $tabber->tab_widget($new_tab);
	$editor->configure(-ui => \%ui);
	my $tileregistry = TileRegistry->new(listeners => [$editor->get_tile_chooser]);
	$editor->configure(-tileregistry => $tileregistry);
	$editor->configure(-lang => \%lang);
	$editor->configure(-tilepath => $tilepath);
	$editor->init_canvas_buttons;
	$editor->init_tile_chooser;
	$editor->init_map;
	$tabber->raise($new_tab);
}

sub command_close_tab {
	my $current = $tabber->raised;
	$tabber->delete($current) if $current;
}

sub command_open_map { 
	my $file = shift;
	$file =	&file_dialog(
		"open",
		-filetypes =>	[
		[$lang{"b_map"},   [qw/.map/]],
		[$lang{"b_all"},		'*']
		],
		-defaultextension => ".map"		
	) unless $file;
	return 0 unless $file;
	my $editor = $tabber->raised_widget;
	foreach my $page ($tabber->pages) {
		my $tabfile = $tabber->{_tabs}{$page}{widget}{_file};
		if ($tabfile and $tabfile eq $file) {
			$tabber->raise($page);
			&command_close_tab();
		}
	}
	if (scalar $tabber->pages == 0) {
		&command_new_tab;
		$editor = $tabber->raised_widget;
	};
	$editor->{_file} = $file; # FIXME BAD
	$tabber->label($tabber->raised, &basename_noext($file));
	&msg($lang{"i_loading"} . " $file... ");
	$editor->load_file( $file );
	&msg($lang{"i_done"} . " [". localtime() ."]", 1);
	$editor->eventGenerate("<ButtonRelease-1>");
}

sub command_save_map { 
	my $editor = $tabber->raised_widget;
	my $file = $editor->{_file} if $editor->{_file}; # FIXME BAD 
	&file_write_as_string( $file	); 
	$tabber->label($tabber->raised, &basename_noext($file));
}
sub command_saveas_map { 
	&file_write_as_string( ); 
}

#= Subroutine ========================================#
sub  command_save_all
#=====================================================#
{
	my $current = $tabber->raised;
	map { 
		$tabber->raise($_); 
		&command_saveas_map();
	} $tabber->pages;
	$tabber->raise($current);
}

#= Subroutine ========================================#
sub command_convert_map 
#=====================================================#
{ 
	my $editor = $tabber->raised_widget;
	my $file = &file_dialog(
		"save",
		-filetypes =>	[
		[$lang{'b_png'},   [qw/.png/]],
		[$lang{'b_all'},		'*']
		],
		-defaultextension => ".png"	
	);
	&msg($lang{'i_saving'} . " $file... ");
	$editor->file_write_as_img($file);
	&msg($lang{"i_done"} . " [". localtime() ."]", 1);
}


#= Subroutine ========================================#
sub  command_add_package
#=====================================================#
{
		my $pack = &TilePack::collection_build("$tilepath", &file_dialog(
			"open", 
			-filetypes =>	[
			[$lang{'b_zip'},           [qw/.zip/]],
			[$lang{'b_all'},		'*']
			],
			-defaultextension => ".zip"		
		) );
	foreach my $w ($tabber->tab_widgets) {
			my $tree = $w->get_tile_chooser();
			my $tilepath = $w->cget("-tilepath");
	
		$w->configure("-images", {%{$w->cget("-images")}, $tree->load_tilepack("$pack")});
		#map { $_->configure(-images => $w->cget("-images")) } $tabber->tab_widgets();
	}
}

#= Subroutine ========================================#
sub  command_delete_package
#=====================================================#
{
	my $current = $tabber->raised_widget;
	my $current_tree = $current->get_tile_chooser();
	my %buttons = ();
	foreach ($current_tree->info("children", "")) { 
		$buttons{$current_tree->info("data", $_)->{name}} = $_
	}

	my $pack = &prompt(
		-text => $lang{'i_delete_package'},
		-buttons => [sort keys %buttons, $lang{"m_cancel"}]
	);
	return 0	if $pack eq $lang{"m_cancel"};

	foreach my $w ($tabber->tab_widgets) {
		my $tree = $w->get_tile_chooser();
		my $tilepath = $w->cget("-tilepath");
		$tree->remove_tilepack($pack);
	}
	&rmtree($tilepath."/".$pack) or return 0;
}

#= Subroutine ========================================#
sub command_quit {
	my $break = 0;
	map { 
		$tabber->raise($_);
		$break = &command_close_tab;
	} $tabber->pages;
	return 0 if $break;
	$main->destroy;
}


# edit actions

#= Subroutine ========================================#
sub command_add_tile 
#=====================================================#
{
	my $editor = $tabber->raised_widget;
	my $tile_last = $editor->get_map->tile_last;
	return 0 unless $tile_last;
	$editor->action_toggle('add', @{$tile_last});
}

#= Subroutine ========================================#
sub command_text
#=====================================================#
{
	my $editor = $tabber->raised_widget;
	$editor->action_toggle('text')
}

#= Subroutine ========================================#
sub command_delete_tile 
#=====================================================#
{
	my $editor = $tabber->raised_widget;
	$editor->action_toggle('delete'); 
}

#= Subroutine ========================================#
sub command_rotate_tile 
#=====================================================#
{
	my $editor = $tabber->raised_widget;
	$editor->action_toggle('rotate');	
}

#= Subroutine ========================================#
sub command_move_tile 
#=====================================================#
{
	my $editor = $tabber->raised_widget;
	$editor->action_toggle('select'); 
}

#= Subroutine ========================================#
sub command_drag_map 
#=====================================================#
{
	my $editor = $tabber->raised_widget;
	$editor->action_toggle('scan'); 
}

#= Subroutine ========================================#
sub file_dialog 
#=====================================================#
{
  my ($mode, @options) = @_;
	my $fileName;
  if ($mode eq "open") { $fileName = $main->getOpenFile(@options); } 
	elsif ($mode eq "save") { $fileName = $main->getSaveFile(@options); } 
	else { $fileName = ""; }
#  if ($fileName and $mode eq "save") { 
#		$fileName = encode("utf-8", $fileName);
#	}
	return $fileName; 
}

#= Subroutine ========================================#
sub file_write_as_string 
#=====================================================#
{
	my ($file) = @_;
 	$file = &file_dialog(
		"save", 
		-filetypes => [ 
			[$lang{"b_map"}, [".map"] ], 
			[$lang{"b_all"}, ["*"] ] 
			],
		 -defaultextension => ".map"
	) unless $file;
	&msg($lang{'i_saving'} . " $file... ");
	my $editor = $tabber->raised_widget;
	$editor->{_file} = $file;
	$tabber->label($tabber->raised, &basename_noext($file));
	$editor->file_write($file, join("\n",$editor->get_map->to_string) );
	&msg($lang{"i_done"} . " [". localtime() ."]", 1);
}

#= Subroutine ========================================#
sub basename_noext 
#=====================================================#
{
	my ($name) = @_;
	return "" unless $name and -f $name;
	($name) = fileparse($name, qw/.map/);
	return $name;
}

#= Subroutine ========================================#
sub  prompt
#=====================================================#
{
	my (%args) = @_;
	%args = ( -text => $lang{"w_not_implemented"} ) unless %args;
	my $dialog = $main->Dialog(-font => "bgnormal", %args);
#	my $dialog = $main->Dialog(%args);
	return $dialog->Show("-global");
	
}

#= Subroutine ========================================#
sub msg 
#=====================================================#
{
	my ($text, $concat) = @_;
	if ($concat) {
		$status .= $text;
	} else {
		print STDERR "\n";
		$status = $text;
	}
	print STDERR $text;
	$main->{_delayed}->cancel if $main->{_delayed};
	$main->{_delayed} = $main->after(
		3000 => sub {$status = ""}
	);
}


1;

# vim:sw=2 ts=2 

