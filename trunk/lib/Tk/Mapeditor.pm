# Copyright (c) 2012, Nicolas Mazziotta
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#######################################################
package Tk::Mapeditor;
#######################################################
use strict;
use base qw/ Tk::Derived Tk::Frame /;
use TilePack;
use TileRegistry;
use ConfigReader;
use ImageData;
use Tk::Map;
use Tk::Mapeditor;
use Tk::TileChoser;
use Tk::TileChoser::AvButton;
use Tk::TileChoser::PackEntry;
use Encode;
use File::Path;
use File::Spec;
use File::Basename;

Construct Tk::Widget "Mapeditor";

sub ClassInit{
	my ($class,$mw) = @_;
	$class->SUPER::ClassInit($mw);

}

sub Populate {
	my ($w, $args) = @_;
	$w->SUPER::Populate($args);
	
	# opts
	$w->ConfigSpecs(
		-ui => ["PASSIVE", "uI", "UI"], # images de l'interface
		-lang => ["PASSIVE", "lang", "Lang"], # texte de l'interface
		-images => ["PASSIVE", "lang", "Lang"], # index des images en mémoire # FIXME: merge in the registry
		-tileregistry => ["PASSIVE", "tileRegistry", "TileRegistry"], # tile registry
		-tilepath => ["PASSIVE", "tilePath", "TilePath"] # Tile path
	); 

	# components
	my $treeframe = $w->Frame(qw/-relief gr -border 0/)
	->pack(qw/-side left -fill y -expand 0/);

	$w->{_tile_chooser} = $treeframe->Scrolled("TileChoser", qw/
		-width 45
		-highlightthickness 0 
		-indent 15 
		-scrollbars e 
		-relief fl 
		-columns 3
		/)->pack(qw/-expand 1 -fill both -side left/);
	$w->{_tile_chooser}->columnWidth(0, -char => 35);
	$w->{_tile_chooser}->columnWidth(2, 40);
	map {$_->pack(qw/-fill y/)} $w->{_tile_chooser}->packSlaves;

	$w->{_workframe} = $w->Frame(-relief => "gr", -border => 0)
	->pack(qw/-side left -expand 1 -fill both/);
	$w->{_map} = $w->{_workframe}->Map(
			-border=> 0
	)->pack(qw/-side bottom -expand 1 -fill both/);
	$w->{_toolbox} = $w->{_workframe}->Frame()->pack(qw/-side top -anchor w -fill x/);
	$w->{_tooltip} = $w->toplevel->Balloon;
}

#= Subroutine ========================================#
sub  init_tile_chooser
#=====================================================#
{
	my ($w) = @_;
	my $ts = $w->get_tile_chooser;
	$ts->configure(
		-tileregistry => $w->cget("-tileregistry"),
		-tilepath => $w->cget("-tilepath"),
		-ui => $w->cget("-ui")
	);
	$w->init_images;
}

#= Subroutine ========================================#
sub  init_map
#=====================================================#
{
	my ($w) = @_;
	$w->{_map}->configure(
			-tileregistry => $w->cget("-tileregistry"),
			-background => "dimgray",
			-tilepath => $w->cget("-tilepath"),
			-images => $w->cget("-images"),
			-ui => $w->cget("-ui"),
	);
}

#= Subroutine ========================================#
sub  init_images
#=====================================================#
{
	my ($w) = @_;
	my $tilepath = $w->cget("-tilepath");
	my $tree = $w->get_tile_chooser();
	my %images = ();

	opendir(TILESDIR, $tilepath);
	my @tilepacks = readdir TILESDIR;
	closedir(TILESDIR);

	foreach (sort @tilepacks) {	%images = (%images, $tree->load_tilepack($_)); }
	$w->configure("-images" => \%images);
}

#= Subroutine ========================================#
sub  lang
#=====================================================#
{
	my ($w, $str) = @_;
	my $lang = $w->cget("-lang");
	my $out = $lang->{$str};
	return $out if defined $out;
	return $str;
}

#= Subroutine ========================================#
sub  get_tile_chooser
#=====================================================#
{
	my ($w) = @_;
	return $w->{_tile_chooser};
}
#= Subroutine ========================================#
sub  get_toolbox
#=====================================================#
{
	my ($w) = @_;
	return $w->{_toolbox};
}
#= Subroutine ========================================#
sub  get_map
#=====================================================#
{
	my ($w) = @_;
	return $w->{_map};
}



#= Subroutine ========================================#
sub load_file
#=====================================================#
{
	my ($w, $file) = @_;
	unless ($file and -f $file) {
		$w->msg($w->lang("w_file_not_exist") . " $file");
		return "";
	};
	my $map = $w->get_map;
	my $return = $map->from_file($file, 1);
	return $return;
}



#= Subroutine ========================================#
sub file_write 
#=====================================================#
{
	my ($w, $file, $data, $img) = @_;
	return 0 unless $file;
	my $map = $w->get_map();
	open OUT, ">", encode("utf-8", $file);
	binmode(OUT) if $img;
	#flock(OUT, LOCK_SH) or return 0;
	print OUT $data;
	close OUT;
	unless ($img) {
		$w->{_file} = $file ;
	}
	return $file;
}



#= Subroutine ========================================#
sub file_write_as_img 
#=====================================================#
{
	my ($w, $file) = @_;
	return 0 unless $file;
	$w->file_write($file, $w->get_map->to_img("png"), 1)
}


#= Subroutine ========================================#
sub  action_toggle
#=====================================================#
{
	my ($w, $focus, @args) = @_;
	my $map = $w->get_map();
	$w->button_toggle($focus);
	$map->binding_toggle($focus, @args);
}

#= Subroutine ========================================#
sub  button_toggle
#=====================================================#
{
	my ($w, $focus) = @_;
	my $buttons_hash = $w->{_canvas_buttons};
	foreach (keys %$buttons_hash) {
		if ($_ eq $focus) {
			${$buttons_hash->{$_}}->configure(-relief => 'ri');
			next
		}
		${$buttons_hash->{$_}}->configure(-relief => 'fl');
	}
}

#= Subroutine ========================================#
sub  init_canvas_buttons
#=====================================================#
{
	my ($w) = @_;
	my $ui = $w->cget("-ui");
	my $tooltip = $w->{_tooltip};
	my $toolbox = $w->get_toolbox();

	$w->{_canvas_buttons} = {
		'delete' => \my $delete_button, 
		'select' => \my $move_button, 
		'scan' => \my $drag_button,
		'rotate' => \my $rotate_button,
		'add' => \my $insert_button,
		'text' => \my $text_button,
		'undo' => \my $undo_button,
		'redo' => \my $redo_button,
	};

	# edit actions
	$drag_button = $toolbox->Button(
		-image => $ui->{"view_fullscreen.png"},
		-relief => 'fl',
		-command => sub {	$w->action_toggle("scan") }
	)->pack(qw/-side left/);
	$tooltip->attach($drag_button, -balloonmsg => $w->lang('t_drag_map'));

	$move_button = $toolbox->Button(
		-image => $ui->{"move.png"},
		-relief => 'ri',
		-command => sub {	$w->action_toggle("select") }
	)->pack(qw/-side left/);
	$tooltip->attach($move_button, -balloonmsg => $w->lang('t_move_tile'));

	$rotate_button = $toolbox->Button(
		-image => $ui->{"rotate_cw.png"},
		-relief => 'fl',
		-command => sub {	$w->action_toggle("rotate") }
	)->pack(qw/-side left/);
	$tooltip->attach($rotate_button, -balloonmsg => $w->lang('t_rotate_tile'));

	$insert_button = $toolbox->Button(
		-image => $ui->{"editpaste.png"},
		-relief => 'fl',
		-command => sub {	
			my $map = $w->get_map();
			return 0 unless $map->tile_last;
			$w->action_toggle('add', @{$map->tile_last})}
	)->pack(qw/-side left/);
	$tooltip->attach($insert_button, -balloonmsg => $w->lang("t_insert_tile"));

	$delete_button = $toolbox->Button(
		-image => $ui->{"no.png"},
		-relief => 'fl',
		-command => sub {	$w->action_toggle("delete") }
	)->pack(qw/-side left/);
	$tooltip->attach($delete_button, -balloonmsg => $w->lang("t_delete_tile"));

	$text_button = $toolbox->Button(
		-image => $ui->{"fonts.png"},
		-relief => 'fl',
		-command => sub {	$w->action_toggle("text") }
	)->pack(qw/-side left/);
	$tooltip->attach($text_button, -balloonmsg => $w->lang("t_text"));


	# Undo/redo
	$toolbox->Frame->pack(qw/-expand 1 -fill x -side left/);

	$undo_button = $toolbox->Button(
		-image => $ui->{"undo.png"},
		-relief => 'fl',
		-command => sub {	
			my $map = $w->get_map();
			$map->undo_undo }
	)->pack(qw/-side left/);
	$tooltip->attach($undo_button, -balloonmsg => $w->lang('t_undo'));

	$redo_button = $toolbox->Button(
		-image => $ui->{"redo.png"},
		-relief => 'fl',
		-command => sub {	
			my $map = $w->get_map();
			$map->undo_redo 
		}
	)->pack(qw/-side left/);
	$tooltip->attach($redo_button, -balloonmsg => $w->lang('t_redo'));

}


1;

