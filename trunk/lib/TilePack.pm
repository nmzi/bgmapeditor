# Copyright (c) 2006, Nicolas Mazziotta
# $Id: TilePack.pm 262 2006-05-20 06:11:33Z mzi $
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

#######################################################
package TilePack;
#######################################################

use strict;		
use GD;
use Archive::Zip;
use File::Path;
use File::Copy;
use File::Temp qw/tempdir/;

GD::Image->trueColor(1);

sub collection_build {
	my ($tilepath, $zipfile) = @_;
	$tilepath .= "/";
	my $tmpdir = tempdir( DIR => $tilepath, CLEANUP=>1);
	$tmpdir =~ s/\\/\//g;
	return "" unless $zipfile and -f $zipfile;
	my $zip = Archive::Zip->new($zipfile) or return "";
	$zip->extractTree("", $tmpdir."/");
	my $pack;
	my @members = ();
	map {
		$pack = $_->fileName unless $pack;
		push @members, $tmpdir."/".$_->fileName if $_ 
	} $zip->members;

	foreach my $member (sort @members) {
		next if -d $member;
		$member =~ /^$tmpdir\/(.*\/)(.*?)$/;
		my $dir = $1;
		my $file = $2;
		my $parentdir = $tilepath . $dir . $file . "/";
		#	my $parentdir = $tilepath . $1 ."r". $2 . "/";
		my $image = GD::Image->new($member);
		if ($file =~ /^(licence|cfg)$/) {
			&mkpath($tilepath . $dir);
			&copy($member, $tilepath . $dir . "/" . "$file");
		}
		unlink($member);
		next unless $image;
		$image->alphaBlending(0);
		$image->saveAlpha(1);
		&mkpath("$parentdir");
		
		my %png = (
			thumb => &thumbnail($image, 150),
			0 => $image->png,
		);

		my $r_90 = $image->copyRotate90;
		my $r_180 = $image->copyRotate180;
		my $r_270 = $image->copyRotate270;
		
		$r_270->saveAlpha(1);
		$r_180->saveAlpha(1);
		$r_90->saveAlpha(1);

		$png{90} = $r_90->png;
		$png{270} = $r_270->png;
		$png{180} = $r_180->png;
		
		foreach (keys %png) {
			open(OUT, ">", $parentdir."r_".$_.".png");
			binmode(OUT);
			print OUT $png{$_};
			close(OUT);
		}
	};
	&rmtree($tmpdir);
	$pack =~ s/^(.*?)\/.*$/$1/;
	return $pack;
}

sub collection_remove {
	my ($tilepath, $pack)	= @_;
	unlink($tilepath."/".$pack) or return 0;
	return 1
}

sub thumbnail {
	my ($image, $width, $caption) = @_;
	my @bounds = $image->getBounds;
#	if ($bounds[0] < $bounds[1]) {
#		$image = $image->copyRotate90 ;
#		@bounds = $image->getBounds;
#	}
	if ($bounds[0] <= $width) {
		$image->saveAlpha(1);
		return $image->png;
	}
	my $ratio = $width / $bounds[0];
	my @thbounds = ($width, $bounds[1] * $ratio);
	my $thumb = new GD::Image(@thbounds);
	$thumb->copyResampled($image, 0, 0, 0 ,0, @thbounds, @bounds);
	my $black = $thumb->colorAllocate(0,0,0); 
	my $white = $thumb->colorAllocate(255,255,255); 
	my $dim = join(" x ", @bounds);
	#$thumb->string(gdTinyFont, 3, 3, $dim, $white);
	#$thumb->string(gdTinyFont, 1, 1, $dim, $white);
	#$thumb->string(gdTinyFont, 1, 3, $dim, $white);
	#$thumb->string(gdTinyFont, 3, 1, $dim, $white);
	#$thumb->string(gdTinyFont, 2, 2, $dim, $black);
	$thumb->saveAlpha(1);
	return $thumb->png;
}

1;

# vim:ts=2 sw=2

