package Amling::R4P::Operation::Aggregate;

use strict;
use warnings;

use Amling::R4P::Operation;
use Amling::R4P::OutputStream::Easy;
use Amling::R4P::Registry;
use Amling::R4P::Utils;
use Clone ('clone');

use base ('Amling::R4P::Operation');

sub new
{
    my $class = shift;

    my $this = $class->SUPER::new();

    $this->{'SPECS'} = [];
    $this->{'INCREMENTAL'} = 0;

    return $this;
}

sub options
{
    my $this = shift;

    my $specs = $this->{'SPECS'};

    return
    [
        @{$this->SUPER::options()},

        @{Amling::R4P::Registry::options('Amling::R4P::Aggregator', ['a', 'aggregator'], ['agg'], 1, $specs)},
        [['incremental'], 0, \$this->{'INCREMENTAL'}],
    ];
}

sub wrap_stream
{
    my $this = shift;
    my $os = shift;

    my $states = [];
    for my $spec (@{$this->{'SPECS'}})
    {
        my $name = $spec->{'label'};
        if(!defined($name))
        {
            $name = $spec->{'arg'};
            $name =~ s@/@_@g;
        }
        my $agg = $spec->{'instance'};
        push @$states, [$name, $agg, $agg->initial()];
    }
    my $incremental = $this->{'INCREMENTAL'};

    my $output_record = sub
    {
        my $clone = shift;

        my $r = {};
        for my $tuple (@$states)
        {
            my ($name, $agg, $state) = @$tuple;

            $state = clone($state) if($clone);

            Amling::R4P::Utils::set_path($r, $name, $agg->finish($state));
        }
        $os->write_record($r);
    };

    return Amling::R4P::OutputStream::Easy->new(
        $os,
        'BOF' => 'DROP',
        'LINE' => 'DECODE',
        'RECORD' => sub
        {
            my $r = shift;

            for my $tuple (@$states)
            {
                my ($name, $agg, $state) = @$tuple;

                $agg->update($state, $r);
            }

            $output_record->(1) if($incremental);
        },
        'CLOSE' => sub
        {
            $output_record->(0) unless($incremental);
        },
    );
}

sub names
{
    return ['aggregate'];
}

1;
