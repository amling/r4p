package Amling::R4P::Operation::Chain;

use strict;
use warnings;

use Amling::R4P::Operation::Base::WithSubOperation;
use Amling::R4P::Operation;
use Amling::R4P::OutputStream::Easy;

use base ('Amling::R4P::Operation');

sub new
{
    my $class = shift;

    my $this = $class->SUPER::new();

    $this->{'KEEP_BOF'} = 0;

    return $this;
}

sub options
{
    my $this = shift;

    return
    [
        [[undef], undef, sub
        {
            my $args = [@_];

            my $cmds = [];
            TOP: while(1)
            {
                my @cmd;
                while(1)
                {
                    if(!@$args)
                    {
                        push @$cmds, [@cmd];
                        last TOP;
                    }
                    my $arg = shift @$args;
                    if($arg eq '|')
                    {
                        push @$cmds, [@cmd];
                        next TOP;
                    }
                    push @cmd, $arg;
                }
            }

            my $wrappers = [];
            my $files = undef;
            for my $cmd (@$cmds)
            {
                my ($wrapper, $files1) = @{Amling::R4P::Operation::Base::WithSubOperation::construct_wrapper($cmd)};
                push @$wrappers, $wrapper;
                if(!defined($files))
                {
                    $files = $files1;
                }
                else
                {
                    die 'Non-initial chain stages must expect STDIN.' if(@$files1);
                }
            }

            $this->{'WRAPPERS'} = $wrappers;
            $this->extra_args($files);

            return 0;
        }],

        [['keep-bof'], 0, \$this->{'KEEP_BOF'}],

        @{$this->SUPER::options()},
    ];
}

sub validate
{
    my $this = shift;

    die 'No command?' unless($this->{'WRAPPERS'});

    return $this->SUPER::validate();
}

sub wrap_stream
{
    my $this = shift;
    my $os = shift;

    for my $wrapper (reverse(@{$this->{'WRAPPERS'}}))
    {
        if(!$this->{'KEEP_BOF'})
        {
            $os = Amling::R4P::OutputStream::Easy->new(
                $os,
                'BOF' => 'DROP',
                'LINE' => 'PASS',
                'RECORD' => 'PASS',
            );
        }
        $os = $wrapper->($os);
    }

    return $os;
}

sub names
{
    return ['chain'];
}

1;
