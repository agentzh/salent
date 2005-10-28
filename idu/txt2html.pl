#: t2html.pl
#: Convert perl test scripts (or other plain test files) to HTML file
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-08-01 2005-08-26

use strict;
use warnings;
use File::Spec;

my $prog = 'txt2html';
@ARGV or die "Usage: $prog <infile1> <infile2> ...\n";

my $out;
@ARGV = map glob, @ARGV;
foreach (@ARGV) { process_file($_); }

sub output {
    print $out @_;
}

sub process_file {
    my $infile = shift;
    my $abs_path = File::Spec->rel2abs($infile);
    my $outfile = $infile . ".html";
    #unless ($outfile =~ s/\.t$/.html/io) {
    #    $outfile .= '.html';
    #}
    open $out, ">$outfile" or
        die "$prog: Can't open $outfile for writing: $!\n";
    open my $in, $infile or
        die "$prog: Can't open $infile for reading: $!\n";

    output <<"_EOC_";
<html>
 <head>
  <title>$abs_path</title>
 </head>
 <body><tt><pre>
_EOC_
    while (<$in>) {
        my $lnno = sprintf("%6d", $.);
        output qq[<font color=gray>$lnno</font>  <a name="line_$."></a>$_];
    }
    close $in;

    output <<'_EOC_';
 </pre></tt></body>
</html>
_EOC_
    close $out;
    print "$outfile\n";
}
