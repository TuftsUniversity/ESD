package ESD::View::TT;

use strict;
use base 'Catalyst::View::TT';

__PACKAGE__->config( {
    TEMPLATE_EXTENSION => '.tt', 
    ENCODING     => 'utf-8',
});

=head1 NAME

ESD::View::TT - TT View for ESD

=head1 DESCRIPTION

TT View for ESD. 

=head1 AUTHOR

=head1 SEE ALSO

L<ESD>

notroot,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
