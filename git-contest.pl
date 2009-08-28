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

{
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

        my @mainlangs = (sort { $repo{$repo}->{lang}->{$b} <=> $repo{$repo}->{lang}->{$a} } keys %{ $repo{$repo}->{lang} })[0..2]; 
        
        $repo{$repo}->{mainlang}        = \@mainlangs;
        for my $user ( @{ $repo{$repo}->{users} } ) {
            $user{$user}->{lang}->{$_} += $repo{$repo}->{lang}->{$_} for @mainlangs;
        }
    }
}

my @top = (map { $_->[0] } sort { $b->[1] <=> $a->[1] } map { [ $_, scalar( @{ $repo{$_}->{users} } ) ] } keys %repo)[0..49];

sub recommend {
    my $user = shift;
    my %scores;

    {
        # Give the top 50 a base score
        my $i = 1;
        $scores{$_} += $i++ for reverse @top;
    }

    # Give repositories a network based score
    my %network;
    my @up      = map { $repo{$_}->{owner} }      @{ $user{$user}->{repos} };
    my @down    = map { @{ $repo{$_}->{users} } } @{ $user{$user}->{owns}  };

    $network{$_} = 1 for @up, @down;

    for my $connection (keys %network) {
        $scores{$_} += 200 * $network{$connection} for @{ $user{$connection}->{owns} };
    }

    # Correct according to language preferrence
    if (keys %{ $user{$user}->{lang} }) {
        my $lines=1;
        my %language;

        $lines += $user{$user}->{lang}->{$_}
            for keys %{ $user{$user}->{lang} };
        $language{$_} = 1 + ($user{$user}->{lang}->{$_} / $lines ) 
            for keys %{ $user{$user}->{lang} };

        for my $repo (keys %scores) {
            $scores{$repo} *= $language{ $repo{$repo}->{mainlang} } // 0.9;
        }
    }


    # Preferer the original repos 
    for my $repo (keys %scores) {
        my $upstream = $repo{$repo}->{forked}
            or next;

        $scores{$upstream} = $scores{$upstream} > $scores{$repo} ?  $scores{$upstream} : $scores{$repo} ;
        $scores{$repo} = 0;
    }

    # Remove repos the user is already is watching
    for my $repo (keys %scores) {
        $scores{$repo} = 0 if grep { $_ == $repo } @{ $user{$user}->{repos} };
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

