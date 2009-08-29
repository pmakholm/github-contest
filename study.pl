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

my %user;
my %repo;
my %lang;
my %owners;


{
    open my $fh, "<", "download/data.txt";
    while (defined( my $line = <$fh> )) {
        chomp $line;
        my ($user, $repo) = split /:/, $line;
        $user{$user}->{repos}->{$repo} = 1;
        $repo{$repo}->{users}->{$user} = 1;
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

	$repo{$repo}->{network} = $fork ? $repo{$fork}->{network} : { };
	$repo{$repo}->{network}->{$repo} = 1;

	$owners{$owner}->{$repo} = 1;
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
            $user{$_}->{lang}->{$lang}    += $count for keys %{ $repo{$repo}->{users} };

            $lang{$lang}->{$repo}         += $count;
        }

        my @mainlangs = (sort { $repo{$repo}->{lang}->{$b} <=> $repo{$repo}->{lang}->{$a} } keys %{ $repo{$repo}->{lang} })[0..2]; 
        
        $repo{$repo}->{mainlang}        = \@mainlangs;
        for my $user ( keys %{ $repo{$repo}->{users} } ) {
            $user{$user}->{lang}->{$_} += $repo{$repo}->{lang}->{$_} for @mainlangs;

        }
    }
}

my @top = (map { $_->[0] } sort { $b->[1] <=> $a->[1] } map { [ $_, scalar( keys %{ $repo{$_}->{users} } ) ] } keys %repo)[0..49];

store \%user, 'user.study';
store \%repo, 'repo.study';
store \%lang, 'lang.study';
store \%owners, 'owners.study';
store \@top,  'top.study';


