use strict;
use warnings;
use Template::Ast;

my $ast = Template::Ast->read(shift) or
    die Template::Ast->error();
my @list = @{$ast->{ops}};
foreach (@list) {
    my $ins;
    my $asm = $_->{asm};
    ($ins, $asm) = process_asm($asm);
    print $ins, "\n";
}

sub process_asm {
    my $asm = shift;
    $asm =~ s/;[^;]+$//;
    $asm =~ s/\s+$//;
    my $pref_pat = qr/rep\w*|lock|O16|a16|a32|O32|[scdefg]s/i;
    unless ($asm =~ m/^(?:$pref_pat\s+)+\w+/io or $asm =~ m/^\w+/oi) {
        warn $_;
        next;
    }
    my $ins = $&;
    $ins =~ s/^($pref_pat\s+)+//i;
    return (uc($ins), $asm);
}
