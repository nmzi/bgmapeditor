# Copyright (c) 2012, Nicolas Mazziotta
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

#######################################################
package TileRegistry;
#######################################################

# Permet de fixer un nombre d'utilisations maximale pour chaque tuile. Gère le
# recto-verso en associant les tuiles deux à deux.


use strict;		

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $o = {
		listeners => [],
		images => { 
# image data structure is the following:
#
#			image_name => {
#				count => 0,
#				max => 0,
#				really_used => 0
#			}
#
		},
		pairs => {},
    @_
  };
	bless $o;
	return $o;
}

sub reset {
	my ($o) = @_;
	map {
		while ($o->get_count($_) > 0) {
			$o->decrement_count($_);
		}
	} keys %{$o->{images}}
}

#= Subroutine ========================================#
sub  get_listeners
#=====================================================#
{
	my ($o) = @_;
	return @{$o->{listeners}}
}

#= Subroutine ========================================#
sub  add_image
#=====================================================#
{
	my ($o, $image, $max) = @_;
	$o->{images}{$image} = {
		max => $max, 
		count => 0, 
		really_used => 0
	};
	return $image;
}

#= Subroutine ========================================#
sub  increment_count
#=====================================================#
{
	my ($o, $img, $other_than) = @_;
	unless ($other_than) {
		$other_than = {} ;
		$o->increment_really_used($img)
	}
	$other_than->{$img} = 1;

	if ($o->get_available_count($img)) {
		my $data = $o->_get_image_data($img);
		$data->{count}++;
		#	map { $_->increment_count($img) } $o->get_listeners();
	}

  my $av = $o->get_available_count($img);
	unless ($av) {
		map { 
			$_->set_available($img, 0);
			#		$_->button_disable($img) 
		} $o->get_listeners();
	} else {
		map { 
			$_->set_available($img, $av);
		} $o->get_listeners();
	}

	my $paired_list = $o->get_paired_image_list($img);
	foreach my $paired (@$paired_list) {
		if (
			!$other_than->{$paired}
				and
			defined $paired 
				and
			$o->get_available_count($img) < $o->get_available_count($paired)
		) {
			$o->increment_count($paired, $other_than);
		}
	}
}

#= Subroutine ========================================#
sub  get_really_used
#=====================================================#
{
	my ($o, $img) = @_;
	return $o->_get_image_data($img)->{really_used}
}

#= Subroutine ========================================#
sub  increment_really_used
#=====================================================#
{
	my ($o, $img) = @_;
		my $data = $o->_get_image_data($img);
		$data->{really_used}++;
}

#= Subroutine ========================================#
sub  decrement_really_used
#=====================================================#
{
	my ($o, $img) = @_;
	my $data = $o->_get_image_data($img);
	$data->{really_used}--;
}

#= Subroutine ========================================#
sub  decrement_count
#=====================================================#
{
	my ($o, $img, $other_than) = @_;
	unless ($other_than) {
		$other_than = {} ;
		$o->decrement_really_used($img)
	}
	$other_than->{$img} = 1;
	if ($o->get_count($img) > 0) {
	#	map { $_->button_enable($img) } $o->get_listeners();
		my $data = $o->_get_image_data($img);
		$data->{count}--;
		map { 
			$_->decrement_count($img);
			$_->set_available($img, $o->get_available_count($img));
		} $o->get_listeners();
	}
	my $paired_list = $o->get_paired_image_list($img);
	foreach my $paired (@$paired_list) {
			if ( 
				!$other_than->{$paired}
					and 
			 	$o->get_really_used($paired) < $o->get_max($paired)
			) {
				$o->decrement_count($paired, $other_than) if defined $paired;
			}
	}
}

#= Subroutine ========================================#
sub  get_paired_image_list
#=====================================================#
{
	my ($o, $img) = @_;
	return $o->{pairs}{$img};
}

#= Subroutine ========================================#
sub  pair_with
#=====================================================#
{
	my ($o, $img1, $img2) = @_;
	if ($o->{pairs}{$img1}) {
		push @{$o->{pairs}{$img1}}, $img2;
	} else {
		$o->{pairs}{$img1} = [$img2]
	}
	if ($o->{pairs}{$img2}) {
		push @{$o->{pairs}{$img2}}, $img1;
	} else {
		$o->{pairs}{$img2} = [$img1]
	}
}

#= Subroutine ========================================#
sub  set_max
#=====================================================#
{
	my ($o, $img, $n) = @_;
	my $data = $o->_get_image_data($img);
	return unless $data;
	$data->{max} = $n;
	map { 
			$_->set_max($img, $n);
	} $o->get_listeners();
}

#= Subroutine ========================================#
sub  increment_whole_pack
#=====================================================#
{
	my ($o, $img) = @_;
	map {
		$_->increment_whole_pack($img);
	} $o->get_listeners();
}


#= Subroutine ========================================#
sub  get_max
#=====================================================#
{
	my ($o, $img) = @_;
	my $data = $o->_get_image_data($img);
	return $data->{max} if $data;
}

#= Subroutine ========================================#
sub  get_count
#=====================================================#
{
	my ($o, $img) = @_;
	my $data = $o->_get_image_data($img);
	return $data->{count} if $data;
}

#= Subroutine ========================================#
sub  get_available_count
#=====================================================#
{
	my ($o, $img) = @_;
	my $max = $o->get_max($img);
	return 1 unless defined $max;
	return $max - $o->get_count($img);
}

#= Subroutine ========================================#
sub  _get_image_data
#=====================================================#
{
	my ($o, $img) = @_;
	return $o->{images}{$img};
}

#######################################################
package  TileRegistry::Pack;
#######################################################


use strict;		

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $o = {
		images => {},
		available => 1,
		listeners => [],
		pairs => {},
		@_
	};
	bless $o;
	return $o;
}

#= Subroutine ========================================#
sub  add_image
#=====================================================#
{
	my ($o, $image) = @_;
	$o->{images}{$image} = $image;
}

#= Subroutine ========================================#
sub  get_images
#=====================================================#
{
	my ($o, $image) = @_;
	return keys %{$o->{images}}
}

1;

# vim:ts=2 sw=2

