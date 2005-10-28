#: draw_graph.pl
#: Paint the XML spec of a directed graph using GraphViz.
#: Copyright (c) 2005 Agent Zhang
#: 2005-09-21 2005-09-21

use strict;
use warnings;

use Getopt::Std;
use XML::Simple;
use GraphViz;
use Data::Dumper;

my %opts;
getopts('b', \%opts);
my $big = $opts{b};

my $DEBUG = 0;

my $xmlfile = shift;
$xmlfile || die "Usage: draw_graph <xml-file>\n";
my $outfile = $xmlfile;
unless ($outfile =~ s/\.xml$/.png/i) {
    $outfile .= '.png';
}

my $ast = XMLin($xmlfile);
#print Data::Dumper->Dump([$ast]);
#exit(0);
my $node_attr =
{
    shape => 'circle',
    style => 'filled',
    fillcolor => 'yellow',
};
$node_attr->{height} = 0.1 if $big;

my $edge_attr =
{
    color => 'red',
};
$edge_attr->{arrowsize} = 0.5 if $big;

my $graph = GraphViz->new(
    layout => $big ? 'twopi' : 'neato',
    ratio => 'auto',
    node => $node_attr,
    edge => $edge_attr,
);

my %nodes;
my ($node, $body);
while (($node, $body) = each %{$ast->{node}}) {
    unless ($nodes{$node}) {
        warn "Adding node $node\n" if $DEBUG;
        $graph->add_node($node, label => $big ? '' : $node);
        $nodes{$node} = 1;
    }
    my ($pat, $val);
    my $arc = $body->{arc};
    next unless $arc;
    if (defined $arc->{to}) {
        my $to = $arc->{to};
        unless ($nodes{$to}) {
            warn "Adding node $to\n" if $DEBUG;
            $graph->add_node($to, label => $big ? '' : $to);
            $nodes{$to} = 1;
        }
        warn "Adding edge $node => $to: $arc->{id}\n" if $DEBUG;
        $graph->add_edge($node => $to, label => $arc->{id});
        next;
    }
    while (($pat, $val) = each %{$body->{arc}}) {
        my $to = $val->{to};
        unless ($nodes{$to}) {
            warn "Adding node $to\n" if $DEBUG;
            $graph->add_node($to, label => $big ? '' : $to);
            $nodes{$to} = 1;
        }
        warn "Adding edge $node => $to : $pat\n" if $DEBUG;
        if ($big) {
            $graph->add_edge($node => $to);
        } else {
            $graph->add_edge($node => $to, label => $pat);
        }
    }
}

$graph->as_png($outfile);
print "$outfile generated.\n";
