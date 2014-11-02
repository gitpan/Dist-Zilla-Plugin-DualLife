package Dist::Zilla::Plugin::DualLife;
# git description: 0.03-12-gbb9762c
$Dist::Zilla::Plugin::DualLife::VERSION = '0.04';
# ABSTRACT: Distribute dual-life modules with Dist::Zilla

use Moose;
use List::Util 'first';
use namespace::autoclean;

with 'Dist::Zilla::Role::InstallTool';

#pod =head1 SYNOPSIS
#pod
#pod In your dist.ini:
#pod
#pod   [DualLife]
#pod
#pod =head1 DESCRIPTION
#pod
#pod Dual-life modules, which are modules distributed both as part of the perl core
#pod and on CPAN, sometimes need a little special treatment. This module tries
#pod provide that for modules built with C<Dist::Zilla>.
#pod
#pod Currently the only thing this module does is providing an C<INSTALLDIRS> option
#pod to C<ExtUtils::MakeMaker>'s C<WriteMakefile> function, so dual-life modules will
#pod be installed in the right section of C<@INC> depending on different versions of
#pod perl.
#pod
#pod As more things that need special handling for dual-life modules show up, this
#pod module will try to address them as well.
#pod
#pod The options added to your C<Makefile.PL> by this module are roughly equivalent
#pod to:
#pod
#pod     'INSTALLDIRS' => ($] >= 5.009005 && $] <= 5.011000 ? 'perl' : 'site'),
#pod
#pod (assuming a module that entered core in 5.009005).
#pod
#pod     [DualLife]
#pod     entered_core=5.006001
#pod
#pod =for Pod::Coverage setup_installer
#pod
#pod =attr entered_core
#pod
#pod Indicates when the distribution joined core.  This option is not normally
#pod needed, as L<Module::CoreList> is used to determine this.
#pod
#pod =cut

has entered_core => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        (my $name = $self->zilla->name) =~ s/-/::/g;
        require Module::CoreList;
        return Module::CoreList->first_release($name);
    },
);

#pod =attr eumm_bundled
#pod
#pod Boolean for distributions bundled with ExtUtils::MakeMaker.  Prior to v5.12,
#pod bundled modules might get installed into the core library directory, so
#pod even if they didn't come into core until later, they need to be forced into
#pod core prior to v5.12 so they take precedence.
#pod
#pod =cut

has eumm_bundled => (
    is => 'ro',
    isa => 'Bool',
    default => "0",
);

sub setup_installer {
    my ($self) = @_;

    my $entered = $self->entered_core;

    if ($entered > 5.011000 && not $self->eumm_bundled) {
        $self->log('this module entered core after 5.011 - nothing to do here');
        return;
    }

    # technically this only checks if the module is core, not dual-lifed, but a
    # separate repository shouldn't exist for non-dual modules anyway
    $self->log_fatal('this module is not dual-life!') if not $entered;

    my $makefile = first { $_->name eq 'Makefile.PL' } @{ $self->zilla->files };
    $self->log_fatal('No Makefile.PL. It needs to be provided by another plugin')
        unless $makefile;

    my $content = $makefile->content;

    my $dual_life_args = q[$WriteMakefileArgs{INSTALLDIRS} = 'perl'];

    if ( $self->eumm_bundled ) {
        $dual_life_args .= "\n    if \$] <= 5.011000;\n\n";
    }
    else {
        $dual_life_args .= "\n    if \$] >= $entered && \$] <= 5.011000;\n\n"
    }

    $content =~ s/(?=WriteMakefile\s*\()/$dual_life_args/
        or $self->log_fatal('Failed to insert INSTALLDIRS magic');

    $makefile->content($content);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::DualLife - Distribute dual-life modules with Dist::Zilla

=head1 VERSION

version 0.04

=head1 SYNOPSIS

In your dist.ini:

  [DualLife]

=head1 DESCRIPTION

Dual-life modules, which are modules distributed both as part of the perl core
and on CPAN, sometimes need a little special treatment. This module tries
provide that for modules built with C<Dist::Zilla>.

Currently the only thing this module does is providing an C<INSTALLDIRS> option
to C<ExtUtils::MakeMaker>'s C<WriteMakefile> function, so dual-life modules will
be installed in the right section of C<@INC> depending on different versions of
perl.

As more things that need special handling for dual-life modules show up, this
module will try to address them as well.

The options added to your C<Makefile.PL> by this module are roughly equivalent
to:

    'INSTALLDIRS' => ($] >= 5.009005 && $] <= 5.011000 ? 'perl' : 'site'),

(assuming a module that entered core in 5.009005).

    [DualLife]
    entered_core=5.006001

=head1 ATTRIBUTES

=head2 entered_core

Indicates when the distribution joined core.  This option is not normally
needed, as L<Module::CoreList> is used to determine this.

=head2 eumm_bundled

Boolean for distributions bundled with ExtUtils::MakeMaker.  Prior to v5.12,
bundled modules might get installed into the core library directory, so
even if they didn't come into core until later, they need to be forced into
core prior to v5.12 so they take precedence.

=for Pod::Coverage setup_installer

=head1 AUTHOR

Florian Ragwitz <rafl@debian.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 CONTRIBUTORS

=for stopwords Karen Etheridge David Golden

=over 4

=item *

Karen Etheridge <ether@cpan.org>

=item *

David Golden <dagolden@cpan.org>

=back

=cut
