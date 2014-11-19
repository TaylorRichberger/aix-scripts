#!/usr/bin/perl
use Getopt::Std;

main:
{
    my %opts;
    getopts("b:c:d:h:", \%opts);
    unless (exists($opts{b}))
    {
        $opts{b} = "ifx1arch";
    }
    unless (exists($opts{d}))
    {
        $opts{d} = ".";
    }
    unless (exists($opts{c}))
    {
        $opts{c} = 7;
    }
    unless (exists($opts{h}))
    {
        $opts{h} = "v11100";
    }
    my @files;
    opendir(my $dir, $opts{d});
    while (my $file = readdir($dir))
    {
        if ($file =~ m/^\.+$/)
        {
            next;
        }
        my $filename = "$opts{d}/$file";
        if ($file =~ m/^$opts{b}_$opts{h}_(\d{2})(\d{2})(\d{2}).gz$/)
        {
            push(@files, {name => $file, fullname => $filename, mtime => "20$3$1$2"});
        }
    }
    my @sortedfiles = sort({$a->{mtime} <=> $b->{mtime}} @files);
    while (scalar(@sortedfiles) > $opts{c})
    {
        my $file = shift(@sortedfiles);
        print("Deleting $file->{fullname}\n");
        unlink($file->{fullname});
    }
    exit;
}
