# Copyright (c) 2006-2012, Nicolas Mazziotta
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#######################################################
package Tk::TileChoser::AvButton;
#######################################################
use strict;
use base qw/ Tk::Derived Tk::Frame /;
use utf8;

Construct Tk::Widget "AvButton";

sub ClassInit{
	my ($class,$mw) = @_;
	$class->SUPER::ClassInit($mw);
}

sub Populate {
	my ($w, $args) = @_;
	$w->SUPER::Populate($args);
	$w->{button} = $w->Button()->pack(qw/-side top -expand 1 -fill both -anchor s/);
	$w->{label} = $w->Label(-text => "-/-")->pack(qw/-side left -expand 0/);
	$w->ConfigSpecs(
   'DEFAULT' => [$w->{button}],
	);
}

sub set_available {
	my ($w, $n) = @_;
	my $text = $w->{label}->cget("-text");
	$text =~ s!.*(/\d+)!$n$1!g;
	$w->{label}->configure("-text", $text);
}

sub set_max {
	my ($w, $n) = @_;
	my $text = $w->{label}->cget("-text");
	$text =~ s!/.*!/$n!g;
	$w->{label}->configure("-text", $text);
}




1;
