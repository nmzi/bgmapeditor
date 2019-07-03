# Copyright (c) 2006-2012, Nicolas Mazziotta
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#######################################################
package Tk::TileChoser::PackEntry;
#######################################################
use strict;
use base qw/ Tk::Derived Tk::Frame /;
use utf8;

Construct Tk::Widget "PackEntry";

sub ClassInit{
	my ($class,$mw) = @_;
	$class->SUPER::ClassInit($mw);
}

sub Populate {
	my ($w, $args) = @_;
	$w->SUPER::Populate($args);
	$w->{label} = $w->Label()->pack(qw/-side left/);
	$w->{label_text} = $w->Label()->pack(qw/-side left/);
#	$w->Label(-text => " x ")->pack(qw/-side left/);
	$w->ConfigSpecs(
		'-text' => [$w->{label_text}],
		'DEFAULT' => [$w->{label}],
	);

}







1;
