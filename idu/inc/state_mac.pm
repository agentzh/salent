#: state_mac.pm
#: Library for state_mac.pl
#: Salent v0.13
#: Copyright (c) 2005 Agent Zhang
#: 2005-07-22 2005-08-13

use strict;
use warnings;
use Data::Dumper;

sub build_state_mac {
    my ($machine, $tree, $rcount) = @_;
    unless ($rcount) { # It's the first calling:
        my $count = 0;
        $rcount = \$count;
    }
    my %next_nodes = %{$tree->{next}};
    my %info = %$tree;
    delete $info{next};
    # delete $info{pattern};
    if ($next_nodes{ins}) { # encounter a leaf:
        push @$machine, {
            state_id => $$rcount++,
            ins => $next_nodes{ins},
            %info
        };
        return;
    }
    my @next_states;
    push @$machine, {
        state_id => $$rcount++,
        next => \@next_states,
        %info,
    };
    while (my($enc, $subtree) = each %next_nodes) {
        my $pat = $subtree->{pattern};
        push @next_states, { state => $$rcount };
        $next_states[-1]->{pattern} = $pat if $pat;
        build_state_mac($machine, $subtree, $rcount);
        # $$rcount++;
    }
}

# Sort the next state list of each state according to
#   its RegExp's generality:
sub sort_next_states {
    my $machine = shift;
    foreach my $state (@$machine) {
        my $next = $state->{next};
        next unless $next;
        my @classes = group(@$next);

        my $nulls  = pop @classes;
        my $others = pop @classes;
        @$next = @$others;
        map {
            push @$next, sort {
                cmp_pat($a->{pattern}, $b->{pattern});
            } @$_;
        } @classes;
        push @$next, @$nulls;
        #warn Data::Dumper->Dump([$next], ['next']);
    }
}

sub group {
    my @elems = @_;
    my @classes;
    # warn Data::Dumper->Dump([\@elems], ['elems']);
    my @others;
    my @nulls;
    while (@elems) {
        my $elem = shift @elems;
        my $pat = $elem->{pattern};
        unless ($pat) {
            push @nulls, $elem;
            next;
        }
        my @temp;
        my @equiv = grep {
            my $pat2 = $_->{pattern};
            if ($pat =~ m/^$pat2$/ or $pat2 =~ m/^$pat$/) {
                1;
            } else {
                push @temp, $_;
                0;
            }
        } @elems;
        unless (@equiv) {
            push @others, $elem;
            next;
        }
        if (grep { $_->{pattern} ne $pat } @equiv) {
            unshift @equiv, $elem;
            push @classes, [@equiv];
        }
        @elems = @temp;
        #warn Data::Dumper->Dump([\@elems], ['elems']);
    }
    return (@classes, \@others, \@nulls);
}

sub cmp_pat {
    my ($pat1, $pat2) = @_;
    return -1 unless $pat2;
    return 1 unless $pat1;
    return $pat1 =~ m/$pat2/ ? -1 : 1;
}

1;
