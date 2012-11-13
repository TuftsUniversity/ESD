package ESD::Model::ESDDB;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

# This module isn't anything beyond its inheritance and its configuration.
# For the latter, see esd.conf.

=head1 NAME

ESD::Model::ESDDB - Catalyst DBIC Schema Model

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<ESD::Schema>

This just sets up database model relationships in the usual
Catalyst/DBIC ways. Seek ye elsewhere for more information about that.

=head1 AUTHOR

Deborah Kaplan

=head1 COPYRIGHT

Copyright 2012 Tufts University

ESD is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.

ESD is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public
License along with ESD.  If not, see
<http://www.gnu.org/licenses/>.

=cut

1;
