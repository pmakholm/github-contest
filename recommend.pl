#!/usr/bin/perl

my $LICENSE = <<EOL;
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <peter@makholm.net> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return 
 * Peter Makholm
 * ----------------------------------------------------------------------------
EOL

use strict;
use Storable;

my $user = retrieve "user.study";
my $repo = retrieve "repo.study";
my $lang = retrieve "lang.study";
my $owners = retrieve "owners.study";
my $top  = retrieve "top.study";

sub original {
    my $look = shift;

    $look = $repo->{$look}->{forked} while( $repo->{$look}->{forked} );
    return $look;
}

sub recommend {
    my $id      = shift;
    my $current = $user->{$id};
    my %scores;

    {
        # Give the top 50 a base score
        my $i = 1;
        $scores{$_} += $i++ for reverse @$top;
    }

    # Add base score to repositories owned by users allready being followed
    for my $owner (map { $repo->{$_}->{owner} } keys %{ $current->{repos} }) {
        $scores{$_} += 200 for keys %{ $owners->{$owner} };
    }

    # Add base score to repositories in network with currently watched repositories
    my %network;
    for my $look (keys %{ $current->{repos}} ) {
	for my $node (keys %{ $repo->{$look}->{network} }) {
            $network{$node}++ or next;

            $scores{$node} += 200;
        }
    }

    # Correct according to language preferrence
    if (keys %{ $current->{lang} }) {
        my $lines=1;
        my %language;

        $lines += $current->{lang}->{$_}
            for keys %{ $current->{lang} };
        $language{$_} = 1 + (($current->{lang}->{$_} / $lines ) > 0.25 ? ($current->{lang}->{$_} / $lines ) : 0) 
            for keys %{ $current->{lang} };

        for my $look (keys %scores) {
            $scores{$look} *= $language{ $repo->{$look}->{mainlang}->[0] } // 0.5
		if defined $repo->{$look}->{mainlang}->[0];
            $scores{$look} *= $language{ $repo->{$look}->{mainlang}->[1] } // 0.75
		if defined $repo->{$look}->{mainlang}->[0];
            $scores{$look} *= $language{ $repo->{$look}->{mainlang}->[2] } // 0.9
		if defined $repo->{$look}->{mainlang}->[0];
        }
    }


    # Preferer the original repos 
#    for my $look (keys %scores) {
#	my $upstream = original($look);
#        next if $look == $upstream;
#
#        $scores{$upstream} = $scores{$upstream} > $scores{$look} ?  $scores{$upstream} : $scores{$look} ;
#        $scores{$repo} = 0;
#    }

    # Remove repos the user is already is watching
    for my $look (keys %scores) {
        $scores{$look} = 0 if grep { original($_) == $look } keys %{ $current->{repos} };
    }

    return ( sort { $scores{$b} <=> $scores{$a} } keys %scores)[0..9];
}

while (<>) {
    s/[\n\r]+$//;

    print "$_:";
    print join ",", recommend($_);
    print "\n";
}

