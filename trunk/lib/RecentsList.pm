#######################################################
package RecentsList;
#######################################################

use strict;

sub push_front {
	my ($file, $recentsfile, $recentslimit) = @_;
	
	my @recents = load($recentsfile);
	
	# Supprimer tout les doublons
	@recents = grep { $_ ne $file } @recents;
	
	# Insérer en avant de la liste
	unshift(@recents, $file);
	
	# Honorer la limite de taille
	if (@recents > $recentslimit) {
		@recents = @recents[0..$recentslimit-1];
	}
	
	# Écrire
	@recents = join("\n", @recents);
	
	open(WH, '>', $recentsfile);
	print WH @recents;
	close(WH);
}

sub load {
	my $recentsfile = shift;
	
	if (!open(FH, $recentsfile)) {
		return ();
	}
	
	my @recents = <FH>;
	chomp @recents;
	close(FH);
	
	return @recents;
}


1;
