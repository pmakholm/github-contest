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

my %user;
my %repo;
my %lang;


{
    open my $fh, "<", "download/data.txt";
    while (defined( my $line = <$fh> )) {
        chomp $line;
        my ($user, $repo) = split /:/, $line;
        push @{ $user{$user}->{repos} }, $repo;
        push @{ $repo{$repo}->{users} }, $user;
    }
    close $fh;
}

{
    open my $fh, "<", "download/repos.txt";
    while (defined( my $line = <$fh> )) {
        chomp $line;
        my ($repo, $owner, $name, $created, $fork) = $line =~ m!^(\d+):([^/]*)/([^,]+),([^,]+)(?:,(.*))?!;

        $repo{$repo}->{owner}   = $owner    // warn "no owner in [[$line]]";
        $repo{$repo}->{name}    = $name     // warn "no name  in [[$line]]";
        $repo{$repo}->{created} = $created  // '';
        $repo{$repo}->{forked}  = $fork     // ''; 

        push @{ $user{$owner}->{owns} }, $repo;

    }
    close $fh;
}

if (0) {
    open my $fh, "<", "download/lang.txt";
    while (defined( my $line = <$fh> )) {
        chomp $line;
        my ($repo, $langs) = split /:/, $line;

        for my $langcount (split /,/, $langs) {
            my ($lang, $count) = split /;/, $langcount;
            
            $repo{$repo}->{lang}->{$lang} += $count;
            $user{$_}->{lang}->{$lang}    += $count for @{ $repo{$repo}->{users} };

            $lang{$lang}->{$repo}         += $count;
        }
    }
}

my @top10 = (map { $_->[0] } sort { $b->[1] <=> $a->[1] } map { [ $_, scalar( @{ $repo{$_}->{users} } ) ] } keys %repo)[0..9];

sub recommend {
    my $user = shift;
    my %scores;

    # Give the top 10 a base score to ensure at least 10 recommendations
    $scores{$_} += 1 for @top10;

    my @up      = map { $repo{$_}->{owner} }      @{ $user{$user}->{repos} };
    my @down    = map { @{ $repo{$_}->{users} } } @{ $user{$user}->{owns}  };

    my %network;
    $network{$_} = 1 for @up, @down;

    for my $connection (keys %network) {
        $scores{$_} += 5 * $network{$connection} for @{ $user{$connection}->{owns} };
    }

    return ( sort { $scores{$b} <=> $scores{$a} } keys %scores)[0..9];
}

open my $fh, "<", "download/test.txt";
while (<$fh>) {
    s/[\n\r]+$//;

    print "$_:";
    print join ",", recommend($_);
    print "\n";
}

