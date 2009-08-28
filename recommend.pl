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
my $top  = retrieve "top.study";

my @NetworkLevels = ( 0, 1);
sub network {
    my $root = shift;
    my %network;

    $network{$root} = @NetworkLevels[0];

    for my $level (1..$#NetworkLevels) {
        for my $node (keys %network) {
	    my @up      = map { $repo->{$_}->{owner} }      @{ $user->{$node}->{repos} };
	    my @down    = map { @{ $repo->{$_}->{users} } } @{ $user->{$node}->{owns}  };
	
	    $network{$_} //= $NetworkLevels[$level] for @up, @down;
        }
    }

    return \%network;
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

    # Give repositories a network based score
    my $network = network($id);

    for my $connection (keys %{ $network }) {
        $scores{$_} += 200 * $network->{$connection} for @{ $user->{$connection}->{owns} };
    }

    # Correct according to language preferrence
    if (keys %{ $current->{lang} }) {
        my $lines=1;
        my %language;

        $lines += $current->{lang}->{$_}
            for keys %{ $current->{lang} };
        $language{$_} = 1 + ($current->{lang}->{$_} / $lines ) 
            for keys %{ $current->{lang} };

        for my $look (keys %scores) {
            $scores{$look} *= $language{ $_ } // 0.9 for @{ $repo->{$look}->{mainlang} };
        }
    }


    # Preferer the original repos 
    for my $look (keys %scores) {
        my $upstream = $repo->{$look}->{forked}
            or next;

        $upstream = $repo->{$upstream}->{forked} while $repo->{$upstream}->{forked};

        $scores{$upstream} = $scores{$upstream} > $scores{$look} ?  $scores{$upstream} : $scores{$look} ;
        $scores{$repo} = 0;
    }

    # Remove repos the user is already is watching
    for my $look (keys %scores) {
        $scores{$look} = 0 if grep { $_ == $look } @{ $current->{repos} };
    }

    return ( sort { $scores{$b} <=> $scores{$a} } keys %scores)[0..9];
}

while (<>) {
    s/[\n\r]+$//;

    print "$_:";
    print join ",", recommend($_);
    print "\n";
}

