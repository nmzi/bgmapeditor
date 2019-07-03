# Copyright (c) 2006, Nicolas Mazziotta
# Previous copyright stated Université de Liège, which was an error.
# $Id: Tabber.pm 262 2006-05-20 06:11:33Z mzi $
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.



#######################################################
package Tk::Tabber;
#######################################################

use strict;		

use Tk::NoteBook;
use base qw/Tk::NoteBook/;

Construct Tk::Widget "Tabber";

sub ClassInit{
	my ($class,$mw) = @_;
	$class->SUPER::ClassInit($mw);
}

sub Populate {
	my ($w, $args) = @_;

	$args->{-tabpadx} = 2 unless $args->{-tabpadx} ; 
	$args->{-tabpady} = 2 unless $args->{-tabpady} ;
#	$args->{-font} = "" unless $args->{-font};
        # FIXME
        #$args->{-backpagecolor} = $w->optionGet("background" => ref $w) unless $args->{-backpagecolor};
	
	$w->SUPER::Populate($args);

	$w->{_tabs} = {};
	
	# Affichage
	my %defaultPack = qw(
		-expand 1
		-fill both
		-side left
	);
	my %defaultBorder = qw(
		-relief groove
		-borderwidth 2
	);
	my %onglet;
}

sub delete {
	my ($w, $page) = @_;
	my %pages = ();
	map { $pages{$_} = 1 } $w->pages;
	$w->SUPER::delete($page) if $pages{$page};
	delete $w->{_tabs}{$page};
	return $w;
}

sub clear {
	my $w = shift;
	map {$w->SUPER::delete($_)} $w->pages;
	$w->{_tabs} = {};
	return $w;
}

sub page {
	my ($w, $name) = @_;
	return $w->Subwidget($name);
}

sub label {
	my ($w, $page, $label) = @_;
	return $w->pageconfigure($page, -label => $label) if $label;
	return $w->pagecget($page, "-label");
}

sub raised_widget {
	my ($w, $name) = @_;
	if ($name) {
		$w->raise($name);
	} 
	else {
		$name = $w->raised;
	}
	return $w->{_tabs}{$name}{widget};
}

sub tab_widget {
	my ($w, $name) = @_;
	return $w->{_tabs}{$name}{widget};
}


sub tab_widgets {
	my ($w) = @_;
	my @widgets = ();
	map { push @widgets, $w->{_tabs}{$_}{widget} } $w->pages	;
	return @widgets;
}

sub tab_add {
	my ($w, %options) = @_;

	my %pages = ();
	map {$pages{$_} = 1} $w->pages;

	if (! $options{-name} or exists $pages{$options{-name}}) {
		my $n = 0;
		$options{-name} = "map" . $n; 
		while (exists $pages{$options{-name}}) {
			$options{-name} = "map" . $n++; 
		}
	}
	
	$options{-label} = $options{-name} unless $options{-label};
	my $basetabname = $options{-label};
	my $n = 1;
	map { $options{-label} = $basetabname . " " . ++$n if $w->pagecget($_, '-label') eq $options{-label} } $w->pages;
	my @pack = ();
	unless ($options{'-pack'}) {
		@pack = qw/-expand 1 -fill both/ ;
	} else {
		@pack = $options{'-pack'};
	}
	
	my $tab = $w->add(
		$options{-name}, 
		-label => $options{-label},
	);
	my $sub = $options{"-widget"};
	
	my $new = $tab->$sub(
		%{$options{-options}},
	)
	->pack( @pack );

	
	unless (exists $options{-advertised} and ! $options{-advertised}){
		$w->Advertise(
			$options{-name} => $new
		);
	}
	
	$w->{_tabs}{$options{-name}} = {
		tab => $tab, 
		widget => $new
	};
	
	return $options{-name};
}

1;

