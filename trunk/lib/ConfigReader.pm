# Copyright (c) 2012, Nicolas Mazziotta
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

#######################################################
package ConfigReader;
#######################################################

use strict;		

sub readcfg {
	my $configfile = shift;
	my %cfg;
	open(CFG, $configfile);
	while (<CFG>) {
		next if /^\s*#.*$/;
		/^(.*?)=(["']?)(.*?)(\2)(#.*)?$/;
		$cfg{$1} = $3;
	}
	unless ($cfg{lang}) {
		$cfg{lang} = "fr";
	}
	close(CFG);
	return %cfg;
}


1;

# vim:ts=2 sw=2

