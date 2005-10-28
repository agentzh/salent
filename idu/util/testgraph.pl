#: testgraph.pl
#: Modified by Agent Zhang to fit the taste of Salent
#: 2005-08-02 2005-08-26

use warnings;
use strict;

use YAML qw/Load Dump/;
use Getopt::Long;
use Test::TAP::HTMLMatrix;
use Test::TAP::Model::Visual;

GetOptions \our %Config, qw(inlinecss|e cssfile|c=s help|h);
$Config{cssfile} ||= Test::TAP::HTMLMatrix->css_file();
usage() if $Config{help};

my $yamlfile = shift || 'tests.yml';

open(my $yamlfh, '<', $yamlfile) or die "Couldn't open $yamlfile for reading: $!";
binmode $yamlfh, ":utf8" or die "binmode: $!";
local $/=undef;

my $data = Load(<$yamlfh>);
undef $yamlfh;

my $tap = My::Model->new_with_struct(delete $data->{meat});
my $v = Test::TAP::HTMLMatrix->new($tap, Dump($data));
$v->has_inline_css($Config{inlinecss});

my $fh;
if (my $out = shift) {
    open $fh, '>', $out or die $!;
}
else {
    $fh = \*STDOUT;
}
binmode $fh, ":utf8" or die "binmode: $!";
print $fh "$v";
close $fh;

sub usage {
  print <<"USAGE";
usage: $0 [OPTIONS] > output_file.html

Generates an HTML summary of a YAML test run. Options:

   --inlinecss, -e      inline css in HTML header (for broken webservers)
   --cssfile,  -c FILE  location of css. [default: $Config{cssfile}]

See also:
   util/yaml_harness.pl  - produce the data for this tool
   util/catalog_tests.pl - produce cross-linkable tests
   util/run-smome.pl     - automate the smoke process

USAGE
  exit 0;
}

my $astfile;
my $testfile;
my $lineno;
my $in;

{
	package My::Model;
	use base qw/Test::TAP::Model::Visual/;
	sub file_class { "My::File" }

	package My::File;
	use base qw/Test::TAP::Model::File::Visual/;
	sub subtest_class { "My::Subtest" }
    use Carp 'carp';

	sub link {
		my $self = shift;
		my $link = $self->SUPER::link;
        $lineno = 0;
        $testfile = $link;
        if ($testfile =~ m/_cover/i) {
            $astfile = 't/pat_cover.ast.ast';
        } else {
            ($astfile = $testfile) =~ s/\.t$/.ast/oi;
        }
        if (-f $astfile) {
            close $in if defined $in;
            #warn "Openning $astfile...";
            undef $in;
            unless (open $in, $astfile) {
                carp "can't open $astfile for reading: $!";
                undef $in;
            }
            #warn "$astfile - $. ------------------------\n";
        }
		$link =~ s/\.t$/.t.html/;
		$link;
	}

	package My::Subtest;
	use base qw/Test::TAP::Model::Subtest::Visual/;
	sub link {
		my $self = shift;
        #warn Data::Dumper->Dump([$self], [qw(self)]);
        #warn $self->test_file;
		#my $link = $self->SUPER::link;
        #warn "Test file: $testfile";
        my $info = $self->line;
        #warn $astfile;
        if (-f $astfile) {
            my $mac;
            my $hexd = qr/[A-F0-9]/i;
            if ($info =~ m/ok \d+ - ((?:$hexd{2} )*$hexd{2})\b/i) {
                $mac = $1;
                $lineno = get_line_no($astfile, $mac);
            }
            if ($lineno == 0 && $astfile =~ m/pat_cover/) {
                #warn "$astfile($.) - $mac";
            }
            return "$astfile.html#line_$lineno";
        }
        return "$testfile.html";
	}

    sub get_line_no {
        my ($astfile, $mac) = @_;
        #warn "$astfile $mac";
        local $/ = "\n";
        while (<$in>) {
            if (/'mac'\s*=>\s*'\s*$mac\s*'/i) {
                return $.;
            }
        }
        return 0;
    }
}

sub END { close $in if defined $in; warn "Closing linked file...\n"; }
