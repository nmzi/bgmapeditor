# Copyright (c) 2006, Nicolas Mazziotta
# $Id: Map.pm 280 2006-07-07 07:31:03Z mzi $
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#######################################################
package Tk::Map;
#######################################################
use strict;
use base qw/ Tk::Derived Tk::Canvas /;

use POSIX;
use GD;
use Switch;
use ImageData;
use Tk::TextUndo;

GD::Image->trueColor(1);

Construct Tk::Widget "Map";

sub ClassInit{
	my ($class,$mw) = @_;
	$class->SUPER::ClassInit($mw);
}

sub Populate {
	my ($w, $args) = @_;
	$w->SUPER::Populate($args);
	$w->ConfigSpecs(-tilepath => ["PASSIVE", "tilePath", "TilePath"]);
	$w->ConfigSpecs(-tileregistry => ["PASSIVE", "tileRegistry", "TileRegistry"]);
	$w->ConfigSpecs(-ui => ["PASSIVE", "uI", "UI"]); # images de l'interface
	$w->ConfigSpecs(-images => ["PASSIVE", "images", "Images"]);
	$w->ConfigSpecs(-wallpaper => ["PASSIVE", "wallpaper", "Wallpaper"]);
	
#	$args->{-xscrollincrement} = 1;
#	$args->{-yscrollincrement} = 1;

	$w->CanvasBind('<3>' => [\&tile_rotate]);

	$w->CanvasBind('<Motion>' => [\&map_position]);
	$w->CanvasBind('<B1-Motion>' => [\&tile_move_or_select]);
	$w->CanvasBind('<1>' => [\&tile_select]);
	$w->CanvasBind('<Double-1>' => [\&tile_add]);
	$w->CanvasBind('<Shift-1>' => [\&tile_delete]);
	$w->CanvasBind('<B1-ButtonRelease>' => [\&undo_stack]);
	$w->CanvasBind('<B3-ButtonRelease>' => [\&undo_stack]);
	
	$w->{_tiles} = {} ;
	$w->{_i} = 0 ;
	$w->{_pos} = "x: 0 y:0";
	$w->{_wallpaper} = $args->{-wallpaper};
	
	$w->wallpaper_set;
}

#= Subroutine ========================================#
sub  get_tileregistry
#=====================================================#
{
	my ($w) = @_;
	return $w->cget("-tileregistry")
}

#=================================================================================#

sub from_file {
	my ($c, $filename, $autoincrement_available) = @_;
	return 0 unless $filename;
	$c->get_tileregistry()->reset;
	open(IN, $filename) or return 0;
	map {
		$c->delete($_)
	} $c->find("all");
	my @smallestcoords = ();
	my $eval = "";
	while (<IN>) {	
		next if /^\s*$/;
		chomp;
		my @item = split('(?<!\\\\);', $_);
		if ($item[1] eq "text") {
			$item[0] =~ s/\\;/;/g;
			$item[0] =~ s/\\n/\n/g;
			$c->text_add($item[2], $item[0], $item[3])
		} else {
			$c->tile_add($c->cget("-tilepath") . $item[0], $item[1], $item[2], $item[3], $autoincrement_available);
		}
		my @coords = split("x", $item[2]);
		$smallestcoords[0] = $coords[0] if !defined($smallestcoords[0]) or $smallestcoords[0] > $coords[0];
		$smallestcoords[1] = $coords[1] if !defined($smallestcoords[1]) or $smallestcoords[1] > $coords[1];
		$eval = $@ if $@;
	}
	$@ = $eval if $eval;
	close(IN);
	$c->xviewScroll($smallestcoords[0] - 10, "units");
	$c->yviewScroll($smallestcoords[1] - 10, "units");
	$c->undo_stack;
	
}

sub from_string {
	my ($c, @data) = @_;
	$c->get_tileregistry()->reset;
	map {
		$c->delete($_)
	} $c->find("all");
	foreach (@data) {	
		s/\n$//g;
		my @item = split('(?<!\\\\);', $_);
		if ($item[1] eq "text") {
			$item[0] =~ s/\\;/;/g;
			$item[0] =~ s/\\n/\n/g;
			$c->text_add($item[2], $item[0], $item[3])
		} else {
			$c->tile_add($c->cget("-tilepath") . $item[0], $item[1], $item[2], $item[3]);
		}
	}
}

#=================================================================================#

sub to_img {
	my ($canvas, $format) = @_;
	my $tilepath = $canvas->cget("-tilepath");
	my @items = $canvas->to_string();
	return "" unless @items;

	my @clip = qw/0 0 0 0/;
	my @toCopy = ();
	my @toText = ();
	my $first = 1;
	my ($name, $type, $pos, $align) ;
	
	ADD: foreach (@items) {
		($name, $type, $pos, $align) = split("(?<!\\\\);", $_);
		# TODO
		my $image;
		my @bounds;
		my @pos = split("x",$pos);

		switch ($type) {
			case "text" { 
				$image = GD::Image->new($tilepath."/background.png");
				$name =~ s/\\;/;/g;
				$name =~ s/\\n/\n/g;
				# on copie le texte dans une image pour voir la place qu'il prend
				my $black = $image->colorAllocate(0,0,0);
				my @b = $image->stringFT($black,"$tilepath/../../fonts/FreeSans.ttf",9,0,0,0,$name);
				#my @b = $image->stringFT($black,GD::gdSmallFont,9,0,0,0,$name);
				if ($b[2] < 0) {
					$b[2] += -$b[2];
					$b[0] += -$b[2];
				} 
				if ($b[1] < 0) {
					$b[1] += -$b[1];
					$b[7] += -$b[1];
				} 
				# on calcule le rectangle où le mettre
				@bounds = ($b[2] - $b[0], $b[1] - $b[7]);
			}
			else {
				$image = GD::Image->new($tilepath.$name);
				next ADD unless $image;
				@bounds = $image->getBounds;
			}
		}
		for my $i (0 .. 1) {
			# les dimensions de l'image finale sont ajustées en fonction 
			# des images qui la composent
			if ($first) {	$clip[$i] = $pos[$i] } 
			$clip[$i] = $pos[$i] if $clip[$i] > $pos[$i]; 
			$clip[$i + 2] = ($pos[$i] + $bounds[$i]) if $clip[$i + 2] < ($pos[$i] + $bounds[$i]);
		}
		switch ($type) {
			case "text" { push @toText, [$name, @pos, 0, 0, @bounds];	}
			else { push @toCopy, [$image, @pos, 0, 0, @bounds];	}
		}
		$first = 0;
	}

	my $plan = GD::Image->new($clip[2] - $clip[0], $clip[3] - $clip[1]);
	
	if (-f $tilepath . "/" . "background.png") {
		my $background = GD::Image->new($tilepath . "/" . "background.png");
		$plan->saveAlpha(1);
		$plan->alphaBlending(0);
		$plan->copyResized($background,qw/0 0 0 0/,$clip[2] - $clip[0], $clip[3] - $clip[1],qw/1 1/) if $background;
	}
	
	$plan->alphaBlending(1);
		
	foreach (@toCopy) {
		# on adapte la position en fonction des dimensions de l'image finale
		my @args = @$_;
		$args[1] -= $clip[0];
		$args[2] -= $clip[1];
	 	$plan->copy(@args);
	}

	foreach (@toText) {
		my @args = @$_;
		$args[1] -= $clip[0];
		$args[2] -= $clip[1]-9; # on doit rajouter la hauteur de la police
		my $black = $plan->colorAllocate(0,0,0);
		my @b = $plan->stringFT($black,"$tilepath/../../fonts/FreeSans.ttf",9,0,$args[1],$args[2],$args[0]);
	}
	
	return $plan->$format();
	
}

sub to_string {
	my ($canvas) = @_;
	my $tilepath = $canvas->cget("-tilepath");
	my @items = ();
	foreach my $type (qw/tile zone chip/) {
		TILES: foreach ($canvas->find(withtag => "$type")) {
			my $imagefile = $canvas->{_tiles}{$_}{"-imagename"};
			my $align = $canvas->{_tiles}{$_}{"-align"};
			my $line = "";
			my $file = "";
			$file = $imagefile . ";";
			$file =~ s/^$tilepath//;
			$line .= $file;
			$line .= "$type;";
			my @coords = $canvas->coords($_);
			$line .= sprintf('%.0f',$coords[0]) . "x" . sprintf('%.0f',$coords[1]);
			$line .= ";$align";
			push @items, $line;
		} ;
	}
	foreach ($canvas->find(withtag => "text")) {
		my $line = "";
		my $text = $canvas->itemcget($_, '-text');
		my $width = $canvas->itemcget($_, '-width');
		$text =~ s/;/\\;/g;
		$text =~ s/\n/\\n/g;
		$line .= "$text;text;";
		my @coords = $canvas->coords($_);
		$line .= sprintf('%.0f',$coords[0]) . "x" . sprintf('%.0f',$coords[1]);
		$line .= ";$width";
		push @items, $line;
	}
	return @items;
}

sub to_tgml {
	# Under development;
	my ($canvas) = @_;
	my $string = $canvas->to_string;
	my $output = qq{<?xml version="1.0"?>
	<pandocreon:tabula-genius>
	<board>};
	foreach (split("\n",$string)) {
		my @data = split(";",$_);
		my $file = &rel2abs($data[0]);
		my ($x, $y) = split("x", $data[2]);
		$output .= "\n<image x='$x' y='$y' file='$file'>"
	}
	$output.= q{</card>
	  </board>
	</pandocreon:tabula-genius>}
}

#=================================================================================#

sub binding_toggle {
	my ($c, $action, @args) = @_;
	return "" unless $action =~ /^(text|add|delete|rotate|select|scan)$/;
	my $method = "";
	my %cursor = (
		'add' => 'plus',
		'delete' => 'X_cursor',
#		'text' => 'text', # FIXME
		'rotate' => 'sb_right_arrow',
		'select' => 'arrow',
		'scan' => 'fleur'
	);
	$c->configure(-cursor => $cursor{$action});
	switch ($action) {
		case "scan" { 
			$method = "map_$action"; 
			$c->CanvasBind("<1>" => sub { $c->scanMark($Tk::event->x, $Tk::event->y) });
			$c->CanvasBind('<B1-Motion>' => [\&map_scan]);
			$c->CanvasBind('<B1-ButtonRelease>' => sub {});
			$c->CanvasBind('<Double-B1-ButtonRelease>' => sub{});
			$c->CanvasBind('<B3-ButtonRelease>' => sub {});
		}
		case "select" {
			$method = "tile_$action"; 
			$c->CanvasBind("<1>" => sub { $c->$method(@args) });
			$c->CanvasBind('<B1-Motion>' => [\&tile_move_or_select]);
			$c->CanvasBind('<Control-1>' => [\&tile_group]);
			$c->eventGenerate('<1>');
			$c->CanvasBind('<B1-ButtonRelease>' => [\&undo_stack]);
			$c->CanvasBind('<Double-B1-ButtonRelease>' => [\&undo_stack]);
			$c->CanvasBind('<B3-ButtonRelease>' => [\&undo_stack]);
		}
		case "text" {
			$c->CanvasBind("<1>" => sub { $c->text_add_or_modify() });
			$c->CanvasBind('<B1-Motion>' => sub {&Tk::break;});
			$c->CanvasBind('<B1-ButtonRelease>' => sub {});
			$c->CanvasBind('<Double-B1-ButtonRelease>' => sub{});
			$c->CanvasBind('<B3-ButtonRelease>' => sub {});
		}
		else {
			$method = "tile_$action" ;
			$c->CanvasBind("<1>" => sub { $c->$method(@args) });
			$c->CanvasBind('<B1-Motion>' => sub {&Tk::break;});
			$c->CanvasBind('<B1-ButtonRelease>' => [\&undo_stack]);
			$c->CanvasBind('<Double-B1-ButtonRelease>' => [\&undo_stack]);
			$c->CanvasBind('<B3-ButtonRelease>' => [\&undo_stack]);
		}
	}
	return $action;
}

#=================================================================================#

sub undo_stack {
	my ($c) = @_;
	my @data = $c->to_string;
	return 0 unless @data;
	my $cursor = $c->undo_cursor(+1);
	$c->{_undo_stack} = [[]] unless $c->{_undo_stack};
	eval {splice @{$c->{_undo_stack}}, $cursor};
	push @{$c->{_undo_stack}}, [@data];
	# print "\nSTACK($cursor)" . join "\n", @data; 
}

sub undo_undo {
	my ($c) = @_;
	my $cursor = $c->undo_cursor(-1);
	my $data = $c->{_undo_stack}[$cursor];
	$data = [] unless $data;
	$c->from_string(@$data);
	# print "\nUNDO($cursor)" . join "\n", @$data; 
}

sub undo_redo {
	my ($c) = @_;
	my $cursor = $c->undo_cursor(+1);
	my $data = $c->{_undo_stack}[$cursor];
	unless ($data) {
		$c->undo_cursor(-1);
		return 0 ;
	}
	$c->from_string(@$data);
}

sub undo_cursor {
	my ($c, $direction) = @_;
	$direction = 0 unless $direction;
	$c->{_undo_cursor} += $direction;
	$c->{_undo_cursor} = 0 if $c->{_undo_cursor} < 0;
	return $c->{_undo_cursor};
}

#=================================================================================#

sub tile_last {
	my ($c, @last) = @_;
	$c->{_last} = [@last] if @last;
	return $c->{_last};
}


#=================================================================================#
sub tile_add {
	my ($canvas, $name, $type, $pos, $align, $autoincrement_available) = @_;
	$align=0 unless $align;
	unless ($name) {
		my $last = $canvas->tile_last;
		if ($last) {
			($name, $type, $pos, $align) = @$last 
		} else {
			return 0;
		}
	}
	my $images = $canvas->cget("-images");
	my $x = 0;
	my $y = 0;
	eval {
		$x = $Tk::event->x;
		$y = $Tk::event->y;	
	};
	$type = "tile" unless $type;
	my @pos;
	my $n = $align;
	if ($pos) {
		@pos = split("x", $pos);
	} else {
		@pos = (
			# FIX IT XXX
			#$canvas->map_coords_snap($x,$y,$n), 
			$canvas->canvasx($x,$n),
			$canvas->canvasy($y,$n)
		);
	}

	return 0 unless $name ;

	my ($base_image_name) = $name =~ /^(.*)\/.*$/;

	my $available = $canvas->get_tileregistry()->get_available_count($base_image_name) > 0;
	if ($autoincrement_available and not $available) {
		#my $n = $canvas->get_tileregistry()->get_max($base_image_name);
		#$canvas->get_tileregistry()->set_max($base_image_name, ++$n);
		$canvas->get_tileregistry()->increment_whole_pack($base_image_name);
	} else {
		return unless $available
	}
	

	$canvas->_create_image_on_demand($name);
	
	return 0 unless $images->{$name};


	my $tag = "t".$canvas->{_i}++;
	my $tile = $canvas->createImage(
		@pos, 
		-image => $images->{$name},
		-tags => [$type, $tag],
		-anchor => "nw"
	);
	foreach (qw/chip text zone/) {
		eval { $canvas->lower($tag, $_) unless $type eq "chip" };
	}
  $canvas->configure(-scrollregion => [ $canvas->bbox("all") ]);
	$canvas->{_tiles}{$tag}{'-imagename'} = $name;
	$canvas->{_tiles}{$tile}{'-imagename'} = $name;
	$canvas->{_tiles}{$tile}{'-align'} = $align;
	$canvas->tile_last($name, $type, "", $align);
	# FIXME XXX XXX Structurer l'objet pour ne pas avoir un appel event;
	# Il faut que l'obet retienne le type d'action actif pour que le cadre 
	# autour du bouton actif soit déplacé en conséquence
	$canvas->eventGenerate("<space>");

	# register
	$canvas->get_tileregistry()->increment_count($base_image_name);
#	use Data::Dumper;
#	print Dumper(	$canvas->get_tileregistry()->{images});

	return $tile
}



sub tile_delete {
	my ($c) = @_;
	my $x = $c->canvasx($Tk::event->x);
	my $y = $c->canvasy($Tk::event->y);
	return 0 unless $c->find("overlapping", $x, $y, $x, $y);
	$c->addtag("current", "closest", $x, $y);
	my ($current) = $c->find("withtag", "current");
	my @tags = $c->gettags("current");


	foreach my $tag (@tags) {
		if ($tag =~ /^t\d/) {
			my ($base_image_name) = $c->{_tiles}{$tag}{-imagename} =~ /^(.*)\/.*$/;
			delete $c->{_tiles}{$tag}{-imagename} ;
			delete $c->{_tiles}{$current}{-imagename} ;
			# register
			$c->get_tileregistry()->decrement_count($base_image_name);
		}
	}
	$c->delete("current");
}


sub tile_rotate {
	my ($c) = @_;
	my $x = $c->canvasx($Tk::event->x);
	my $y = $c->canvasy($Tk::event->y);
	$c->dtag("rotate");
	
	return 0 unless $c->find("overlapping", $x, $y, $x, $y);
	
	my $images = $c->cget("-images") ;
	
	$c->addtag("rotate", "closest", $x, $y);
	my @tags = $c->gettags("rotate");

	my $newimagename = "";
	my $tkimage;

	foreach my $tag (@tags) {
		if ($tag =~ /^t\d/) {
			$c->{_tiles}{$tag}{-imagename} =~ /^(.*)_(\d+)\.png$/; 
			my $imagename = $1;
			my $rotate = $2;
			$rotate += 90;
			$rotate = 0 if $rotate == 360;
			my $name = $imagename."_".$rotate.".png";
			$c->{_tiles}{$tag}{-imagename} = $name;
			my ($id) = $c->find("withtag", 'rotate');
			$c->{_tiles}{$id}{-imagename} = $name;
			$tkimage = $c->_create_image_on_demand($c->{_tiles}{$tag}{-imagename});
			$c->itemconfigure("rotate", -image => $tkimage);
		}
	}

	
	
	$c->dtag("rotate");
}

sub _tile_under_mouse_is_current {
	my ($c) = @_;
	my $x = $c->canvasx($Tk::event->x);
	my $y = $c->canvasy($Tk::event->y);
	return 0 unless $c->find("overlapping", $x, $y, $x, $y);
	$c->dtag("current");
	$c->addtag("current", "closest", $x, $y);
	return 1;
}

sub tile_select {
	my ($c, $tile) = @_;
	my $x = $c->canvasx($Tk::event->x);
	my $y = $c->canvasy($Tk::event->y);
	$c->dtag("current");
	unless ($tile) {
		return 0 unless $c->find("overlapping", $x, $y, $x, $y);
		$c->addtag("current", "closest", $x, $y);
	} else {
		return 0 unless $c->find("withtag" => $tile);
		$c->addtag("current", "withtag" => $tile);
	}
	$c->{_tiles}{current}{lastX} = $x;
	$c->{_tiles}{current}{lastY} = $y;
}

sub tile_move_or_select {
	&tile_move(@_);
	&map_position;
}

sub tile_move {
	my ($c) = @_;
	my @current = $c->find("withtag" => 'current');
	my $current = shift @current;
	return 0 unless $current;
	return 0 if join(';', $c->gettags($current)) =~ /\bwallpaper\b/;
	my $x = $Tk::event->x;
	my $y = $Tk::event->y;
	my %tags = ();
	map { $tags{$_} = 1 } $c->gettags("current");
	my $xoffset = $c->{_tiles}{current}{lastX};
	my $yoffset = $c->{_tiles}{current}{lastY};
	my $xm = $x; 
	$xm -= $xoffset if $xoffset;
	my $ym = $y; 
	$ym -= $yoffset if $yoffset;
	if ($current) {
		my $align = $c->{_tiles}{$current}{'-align'};
		my $n = $align;
		$n = 0 unless $align;
		$xm = $c->canvasx($xm, $n);
		$ym = $c->canvasy($ym, $n);
		$x = $c->canvasx($x, $n);
		$y = $c->canvasy($y, $n);
	}
	
	$c->{_tiles}{current}{lastX} = $x;
	$c->{_tiles}{current}{lastY} = $y;
	$c->move("current", $xm, $ym);
  $c->configure(-scrollregion => [ $c->bbox("all") ]);
}

sub map_coords_snap {
	# FIXME
	# permet d'aligner les images pour qu'elles positionnées à l'intérieur du carré 
	# pointé à l'insertion, et non en fonction des coordonnées adaptées les plus proches.
	my ($c, $x, $y, $n) = @_;
	return ($x,$y) unless $n;
	my $modulusx = $x % $n ;
	my $modulusy = $y % $n ;
	$x = $c->canvasx($x);
	$y = $c->canvasx($y);
	print ($x,"x",$y);
	$modulusx = -$n-$modulusx if 0>$modulusx;
	$modulusy = -$n-$n-$modulusy if 0>$modulusy;
	return ($x-$modulusx, $y-$modulusy);
}

#=====================================================#
sub  tile_group
#=====================================================#
{
	my ($c, $group) = @_;
	$c->tile_select;
	map { print $c->bbox($_) } $c->gettags("current");
}

#=====================================================#
sub  text_dialog
#=====================================================#
{
	# TODO: widget séparé
	my ($c, $x, $y, $text, $replace, $width) = @_;
	$c->delete($c->{_dialog}) if $c->{_dialog};
	my %ui = %{$c->cget("-ui")};
	$x = $c->canvasx($Tk::event->x) unless $x;
	$y = $c->canvasy($Tk::event->y) unless $y;
	my $edition_frame = $c->Frame(
		-bd => 1,
		-relief => "solid"
	);
	my $text_widget = $edition_frame->Scrolled(
		"TextUndo",
		-scrollbars => "e",
		-width => 40,
		-wrap => "word",
		-height => 5
	)->pack;
	$text_widget->insert("e", $text) if $text;
	my $toolbar = $edition_frame->Frame()->pack(-fill => "x");
	$toolbar->Button(
		-image => $ui{"apply.png"},
		-relief => "fl",
		-command => sub {
			my $text = $text_widget->get("0.0", "e");
			$c->text_add("$x"."x$y", $text);
			$c->delete($replace) if defined $replace;
			$c->undo_stack;
			$c->delete($c->{_dialog});
			$c->eventGenerate("<ButtonRelease-1>");
		}
	)->pack(-side => "right");
	$toolbar->Button(
		-image => $ui{"cancel.png"},
		-relief => "fl",
		-command => sub { 
			$c->delete($c->{_dialog});
			$c->toplevel->focus;
		}
	)->pack(-side => "right");
	$c->{_dialog} = $c->createWindow($x, $y, -anchor => 'nw', -window => $edition_frame);
	$text_widget->Subwidget("scrolled")->bindtags(['Tk::TextUndo']);
	$text_widget->focus;
}

#=====================================================#
sub  text_add
#=====================================================#
{
	my ($c, $pos, $text, $width) = @_;
	return undef if $text =~ /^\s*$/;
	my $t = $c->createText(
		split("x",$pos),
		-anchor => "nw",
		-text => $text,
	);
	$c->itemconfigure(-width => $width) if $width;
	$c->addtag("text", withtag => $t);
	$c->toplevel->focus;
	# FIXME XXX XXX Structurer l'objet pour ne pas avoir un appel event;
	# Il faut que l'obet retienne le type d'action actif pour que le cadre 
	# autour du bouton actif soit déplacé en conséquence
	$c->eventGenerate("<space>");

	return $text;
	
}


#=====================================================#
sub  text_add_or_modify
#=====================================================#
{
	my ($c) = @_;
	if ($c->_tile_under_mouse_is_current) {
		my $text = "";
		my $width = 0;
		foreach ($c->find("withtag" => "current")) {
			eval {
				$text = $c->itemcget($_, '-text');
				$width = $c->itemcget($_, '-width');
			};
			my @pos = $text ? $c->coords($_) : ($Tk::event->x, $Tk::event->y);
			if ($text) {
				$c->text_dialog(@pos, $text, $_, $width);
			} else {
				$c->text_dialog();	
			}
			$c->dtag("current") if $width;
			last;	
		}
	} else {
		$c->text_dialog();	
	}
}

sub map_scan {
	my ($c) = @_;
  my ($x, $y) = ($Tk::event->x, $Tk::event->y);
	$c->scanDragto($x, $y, 1);
	# repositionne le fond d'écran éventuel
	if ( my @wallpaper = $c->find("withtag" => "wallpaper") ) {
		$c->tile_select(shift @wallpaper);
		my @coords = $c->coords("wallpaper");
		$c->move("wallpaper", 
			# position: dernière coordonnée - position du pointeur - coordonnée
			$c->{_tiles}{current}{lastX}  - $x - $coords[0], 
			$c->{_tiles}{current}{lastY}  - $y - $coords[1]
	 	);
	  $c->{_tiles}{current}{lastX} = $c->canvasx($x);
		$c->{_tiles}{current}{lastY} = $c->canvasy($y);
	}
}

sub map_position {
	my ($c) = @_;
  $c->{_pos} = "x: " . $c->canvasx($Tk::event->x) . " y: " . $c->canvasy($Tk::event->y);
}

#=================================================================================#

sub _create_image_on_demand {
	my ($canvas, $imagename) = @_;
	my $images = $canvas->cget(-images);
	$images->{$imagename} = $canvas->toplevel->Photo(-data => &ImageData::encode_image64($imagename)) unless $images->{$imagename};
	return $images->{$imagename};
}

	
sub wallpaper_set {
	my ($c, $wallpaper, @pos) = @_;
	$wallpaper = $c->{_wallpaper} unless $wallpaper;
	return 0 unless $wallpaper;
	map {$c->delete($_)} $c->find("withtag" => "wallpaper");
	@pos = qw/0 0/ unless @pos;
	$c->createImage(
		@pos, 
		-image => $wallpaper,
		-tags => ["wallpaper"],
		-anchor => "nw"
	);
	$c->lower("wallpaper", "tile") ;
}

1;

