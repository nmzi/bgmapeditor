# Copyright (c) 2006-2012, Nicolas Mazziotta
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#######################################################
package Tk::TileChoser;
#######################################################
use strict;
use base qw/ Tk::Derived Tk::Tree /;


Construct Tk::Widget "TileChoser";

sub ClassInit{
	my ($class,$mw) = @_;
	$class->SUPER::ClassInit($mw);

}

sub Populate {
	my ($w, $args) = @_;
	$w->{imageNodeMap} = {};
	$w->{_pack_path} = {};
	$w->SUPER::Populate($args);
	$w->ConfigSpecs(-tileregistry => ["PASSIVE", "tileRegistry", "TileRegistry"]);
	$w->ConfigSpecs(-tilepath => ["PASSIVE", "tilePath", "TilePath"]);
	$w->ConfigSpecs(-ui => ["PASSIVE", "uI", "UI"]); # images de l'interface
	$w->bind("<Return>" => ["entry_activate"]);
	$w->bind("<Double-1>" => ["entry_activate"]);
}



#= Subroutine ========================================#
sub from_used
#=====================================================#
{
	my ($w, @used) = @_;
}


#= Subroutine ========================================#
sub  remove_tilepack
#=====================================================#
{
	my ($w, $pack_name) = @_;
	my $path = $w->get_pack_path($pack_name);
	$w->delete("entry", $path);
}


#= Subroutine ========================================#
sub  load_tilepack
#=====================================================#
{
	my ($w, $pack) = @_;
	return () unless $pack;
	return () if $pack =~ /^\./;
	$pack =~ s/\/$//g;
	
	# needed components
	my $tilepath = $w->cget("-tilepath");
	my $tileregistry = $w->cget("-tileregistry");
	my $ui = $w->cget("-ui"); 
	my $style = $w->ItemStyle("window", -pady => 0);

	# tiles location
	my $itempath = $tilepath."/".$pack;
	return () unless -d $itempath;

	# new image index
	my %images = ();

	opendir(ITEMSDIR, $itempath);
	my @tilepackitems = readdir ITEMSDIR;
	closedir(ITEMSDIR);

	# specific config
	my %cfg = (
		"z-index" => 1,
		"align" => 0,
	);

	if (-f $itempath."/cfg") {
		# si le répertoire comporte un fichier de configuration
		# le lire 
		%cfg = (%cfg, ConfigReader::readcfg($itempath."/cfg"));
	}
	
	my $folder_image = $ui->{'folder_orange.gif'};
	$folder_image = $w->toplevel->Photo(-data => &ImageData::encode_image64("$itempath/" . $cfg{image} . "/r_0.png")) if $cfg{image};
	
	my $mainbranch = $w->addchild("");
	my $pe = $w->PackEntry(-image =>  $folder_image, -text => $cfg{name}? $cfg{name} : $pack);
	$w->itemCreate($mainbranch, 0, -itemtype => "window", -widget => $pe, -style => $style);

	my $current_spin_value;
	my $sb = $w->Spinbox(
		-width => 2,
		-state => "readonly",
	 	-value => [0 .. 100],
#		-validate => "key", # -invcmd ne fonctionne pas => j'ai dû tout mettre dans -command
	);
	$sb->set(1);
	$sb->configure(-command =>  sub { 
		my ($n, $dir) = @_;
		my $old_max_multiplier = $n;
		my $new_max_multiplier = $n;
		if ($dir eq "up") {
			$old_max_multiplier -= 1
		} else {
			$old_max_multiplier += 1
		}
		$w->_validate_spinbox($mainbranch, $new_max_multiplier, $old_max_multiplier);
	});
	
	$w->itemCreate($mainbranch, 1, -itemtype => "window", -widget => $sb, -style => $style);
	

	my $data = {name => $pack};
	foreach (sort @tilepackitems) {
		next if /^\./;
		next if /.png$/;

		if ($_ eq "licence") {
			open(LICENCE, "$itempath/$_");
			my @licence = <LICENCE>;
			my $licence = join("", @licence);
			$data->{licence} = $licence;
			close LICENCE;

			my $info_button = $w->Button(
				-relief => "fl", 
				-image => $ui->{"messagebox_info.png"},
				-command => sub {
					$w->prompt(-text => $licence) if $licence;
				}
			);
			$w->itemCreate($mainbranch, 2, -itemtype => "window", -widget => $info_button, -style => $style);

		}


		my $tokenpath = $itempath."/".$_;
		next unless -d $tokenpath;

		my $branchname = $_;
		$branchname =~ s/^[_-]//;

		my $itembranch = $w->addchild($mainbranch);
		$w->itemConfigure($itembranch, 0, -image => $ui->{'folder_yellow.gif'}, -text => $branchname);

		opendir(TOKENSDIR, $tokenpath);
		my @tilepackitems = readdir TOKENSDIR;
		closedir(TOKENSDIR);

		@tilepackitems = sort @tilepackitems;

		# gestion de la configuration
		my %cfg = (
			"z-index" => 1,
			"name" => undef,
			"align" => 0,
			%cfg,
		);

		if ($tokenpath =~ /^.*\/([_-])[^\/].*$/) {
			$cfg{"z-index"} = 3 if $1 eq "_";
			$cfg{"z-index"} = 2 if $1 eq "-";
		} 

		if (-f $tokenpath."/cfg") {
			# si le répertoire comporte un fichier de configuration
			# le lire 
			%cfg = (%cfg, ConfigReader::readcfg($tokenpath."/cfg"));
		}

		if ($cfg{name}) {	$w->itemConfigure($itembranch, 0, -text => $cfg{name});	}
		$cfg{"z-index"}--;

		my @types = qw/tile zone chip/;
		my $type = $types[$cfg{"z-index"}];
		
		my $align = $cfg{align};

		# nombre d'occurrences maximal
		my $max_option = $cfg{max};
		my %max_count = ();
		map { 
			/^(.*):(.*)$/;
			$max_count{$1} = $2;
		} split ";", $max_option if $max_option;
	
		# images appariées
		my $pairs_option = $cfg{pairs};
		map { 
			/^(.*):(.*)$/;
			$tileregistry->pair_with($tokenpath."/".$1,  $tokenpath."/".$2);
		} split ";", $pairs_option if $pairs_option;
	


		foreach (@tilepackitems) {
			next if /^\./;
			my $imagepath = $tokenpath."/".$_;
			next unless -d $imagepath;
			my $max = $max_count{$_};
			$tileregistry->add_image($imagepath, $max);


			opendir(IMAGESDIR, $imagepath);
			my @images = readdir IMAGESDIR;
			closedir(IMAGESDIR);


			foreach (@images) {
				next if /^\./;
				my $imagefullname = $imagepath."/".$_;
				next if -d $imagefullname;

				my $tkimage = ""; 
				$images{$imagefullname} = $tkimage; 


				if (/^(.?)_thumb.png$/) {
					$tkimage = $w->toplevel->Photo(-data => &ImageData::encode_image64($imagefullname));
					my $realimage = $1."_0.png";
					my $imagebranch = $w->addchild($itembranch);
					my $b = $w->AvButton(
						-relief => "fl",
						-image => $tkimage,
						-anchor => "w",
						-command => sub  { 	
							# &command_close_tree($itembranch);
							$w->anchorSet($imagebranch);
							$w->selectionClear();
							$w->selectionSet($imagebranch);
							# FIXME
							$w->parent->parent->parent->action_toggle('add', $imagepath."/".$realimage, $type, '', $align); 
							}	
					);
					$w->itemCreate($imagebranch, 0, -itemtype => "window", -widget => $b, -style => $style);
					$w->image_register($imagepath, $imagebranch);
					$w->entryconfigure($imagebranch, -data => {widget => $b, imagepath => $imagepath});

					# set max/available counts in the registry
					$w->set_max($imagepath, $max) if $max;
					$w->set_available($imagepath, $max) if $max;
				}
			} 


		}
	}
	$w->entryconfigure($mainbranch, -data => $data);
	$w->{_pack_path}{$pack} = $mainbranch;
	$w->autosetmode;
	map { $w->close($_); map {$w->close($_)} $w->info("children", $_)} $w->info("children", "");
	return %images;

}

#= Subroutine ========================================#
sub  get_pack_path
#=====================================================#
{
	my ($w, $pack_name) = @_;
	return $w->{_pack_path}{$pack_name}
}

#= Subroutine ========================================#
sub  increment_whole_pack
#=====================================================#
{
	my ($w, $img) = @_;
	my $node = $w->{imageNodeMap}{$img};
	$node =~ /^(\d+)/;
	my $spinbox = $w->itemCget($1, 1, "-widget");
	$w->set_pack_count($1, $spinbox->get() + 1)
}


#= Subroutine ========================================#
sub  set_pack_count
#=====================================================#
# WITHOUT VALIDATION
{
	my ($w, $mainbranch, $new_max_multiplier) = @_;
	my $tileregistry = $w->cget("-tileregistry");
	my $spinbox = $w->itemCget($mainbranch, 1, "-widget");
	my $old_max_multiplier = $spinbox->get();

	foreach ($w->info("children",$mainbranch)) {
		foreach ($w->info("children",$_)) {
			my $data = $w->infoData($_);
			next unless $data;
			my $current_max = $tileregistry->get_max($data->{imagepath});	
			next unless defined $current_max;
			my $current_av = $tileregistry->get_available_count($data->{imagepath});	
			my $new_max = $current_max / $old_max_multiplier * $new_max_multiplier;
			$tileregistry->set_max($data->{imagepath}, $new_max);
			$w->set_available($data->{imagepath}, $current_av - $current_max + $new_max);
		}
	}
	$spinbox->set($new_max_multiplier);
}

sub _validate_spinbox {
	my ($w, $mainbranch, $new_max_multiplier, $old_max_multiplier) = @_;
	my $spinbox = $w->itemCget($mainbranch, 1, "-widget");
	my $tileregistry = $w->cget("-tileregistry");
	#	Vérifie si on n'enlève pas des tuiles utilisées
	my @items = ();
	foreach ($w->info("children",$mainbranch)) {
		foreach ($w->info("children",$_)) {
			my $data = $w->infoData($_);
			next unless $data;
			push @items, $_;
			my $current_max = $tileregistry->get_max($data->{imagepath});	
			next unless defined $current_max;
			my $current_av = $tileregistry->get_available_count($data->{imagepath});	
			my $new_max = $current_max / $old_max_multiplier * $new_max_multiplier;
			my $new_av = $current_av - $current_max + $new_max;
			if ($new_av < 0 or $new_max_multiplier == 0) {
				$spinbox->set($old_max_multiplier);
				return 1;
			}
		}
	}
	# Change le nombre de tuiles dispo
	foreach (@items) {
		my $data = $w->infoData($_);
		next unless $data;
		my $current_max = $tileregistry->get_max($data->{imagepath});	
		next unless defined $current_max;
		my $current_av = $tileregistry->get_available_count($data->{imagepath});	
		my $new_max = $current_max / $old_max_multiplier * $new_max_multiplier;
		$tileregistry->set_max($data->{imagepath}, $new_max);
		$w->set_available($data->{imagepath}, $current_av - $current_max + $new_max);
	}
	return 1;
}

sub OpenCmd
{
 my( $w, $ent ) = @_;
 # The default action
 foreach my $kid ($w->infoChildren( $ent ))
  {
   $w->show( -entry => $kid );
  }
}

sub CloseCmd
{
 my( $w, $ent ) = @_;

 # The default action
 foreach my $kid ($w->infoChildren( $ent ))
  {
   $w->hide( -entry => $kid );
  }
}

sub button_disable
{
	my ($w, $img) = @_;
	my $node = $w->{imageNodeMap}{$img};
	$b = $w->itemCget($node, 0,"-widget");
	$b->configure('-state' => "disabled") if $b;
}

sub button_enable
{
	my ($w, $img) = @_;
	my $node = $w->{imageNodeMap}{$img};
	$b = $w->itemCget($node, 0,"-widget");
	$b->configure('-state' => "normal") if $b;
}

sub set_available
{
	my ($w, $img, $n) = @_;
	my $node = $w->{imageNodeMap}{$img};
	$b = $w->itemCget($node, 0,"-widget");
	$b->set_available($n) if $b;
	if ($n) {
		$w->button_enable($img) 
	} else {
		$w->button_disable($img) 
	}

}

sub set_max
{
	my ($w, $img, $n) = @_;
	my $node = $w->{imageNodeMap}{$img};
	$b = $w->itemCget($node, 0,"-widget");
	$b->set_max($n) if $b;
}

sub image_register
{
	my ($w, $img, $node) = @_;
	$w->{imageNodeMap}{$img} = $node;
}

sub entry_activate {
	my ($w, $node) = @_;
	$node = $w->info("anchor") unless $node;
	my $data = $w->info("data", $node);
	my $widget = $data->{widget} if $data;
	if ($widget) {
		return $w->button_activate($widget);
	} 
	return $w->folder_toggle($node);
}

sub increment_count {
	my ($w, $img) = @_;
	# TODO
}

sub decrement_count {
	my ($w, $img) = @_;
	# TODO
}

sub button_activate {
	my ($w, $b) = @_;
	$b->eventGenerate("<1>");
	$b->invoke;
	$b->after(100, sub {$b->eventGenerate("<ButtonRelease-1>")});
}

sub folder_open {
	my ($w, $node) = @_;
	$node = $w->info("anchor") unless $node;
	$node = $w->info("parent", $node);
	return 0 unless $node;
	return 0 unless $w->info("children", $node) ;
	$w->open($node);
}

sub folder_toggle {
	my ($w, $node) = @_;
	$node = $w->info("anchor") unless $node;
	return 0 unless $w->info("children", $node) ;
	my $mode = $w->getmode($node);
	if ($mode eq "close") {return $w->close($node)}
	elsif ($mode eq "open") {return $w->open($node)}
	else {return 0}
}

sub licence {
	my ($w, $node) = @_;
	$node = $w->info("anchor") unless $node;
	my $data = $w->info("data", $node);
	my $licence = $data->{licence};
	return $licence if $licence;
	return "";
}

#= Subroutine ========================================#
sub  prompt
#=====================================================#
{
	my ($w, %args) = @_;
	my $dialog = $w->toplevel->Dialog(%args);
	return $dialog->Show("-global");
	
}







sub UpDown {
	my $w = shift;
	my $spec = shift;
	my $done = 0;
	my $anchor = $w->info('anchor');
	delete $w->{'shiftanchor'};
	unless( defined $anchor ) {
		$anchor = ($w->info('children'))[0] || '';
		return unless (defined($anchor) and length($anchor));
		if($w->entrycget($anchor, '-state') ne 'disabled') {
			# That's a good anchor
			$done = 1;
		}
		else {
			# We search for the first non-disabled entry (downward)
			$spec = 'next';
		}
	}

	my $ent = $anchor;

	# Find the prev/next non-disabled entry
	while(!$done) {
		$ent = $w->info($spec, $ent);
		last unless( defined $ent );
		next if( $w->entrycget($ent, '-state') eq 'disabled' );
		next if( $w->info('hidden', $ent) );
		next if( $w->_parentHidden($ent) );
		last;
	}

	unless( defined $ent ) {
		$w->yview('scroll', $spec eq 'prev' ? -1 : 1, 'unit');
		return;
	}
	$w->anchorSet($ent);
	$w->see($ent);
	if($w->cget('-selectmode') ne 'single') {
		$w->selectionClear;
		$w->selection('set', $ent);
		$w->Callback(-browsecmd =>$ent);
	}
}

sub _parentHidden {
	my ($w, $ent) = @_;
	my $hidden = 0;
	my $parent = $w->infoParent($ent) || ""; 
	while ($hidden == 0 && $parent ne "") {
		$hidden = 1 if $w->infoHidden($parent);
		$parent = $w->infoParent($parent) || "";
	} return $hidden;
}

1;
