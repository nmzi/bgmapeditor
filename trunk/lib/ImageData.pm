# Copyright (c) 2006, Nicolas Mazziotta
# $Id: ImageData.pm 262 2006-05-20 06:11:33Z mzi $
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

#######################################################
package ImageData;
#######################################################

use strict;
use MIME::Base64;

sub encode_image64 {
	# solution posted on 060208 in comp.lang.perl by tkthundergnat <thundergnat@hotmail.com>
	my $filename = shift;
	open my $filehandle, '<', $filename or die "Can't open $filename. $!\n";
	local $/;
	binmode($filehandle);
	return encode_base64(<$filehandle>);
}

1;

# vim:ts=2 sw=2

