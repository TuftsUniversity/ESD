package ESD::Schema;

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_classes;


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-07-29 20:45:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:y5kXOvshX03x/5OGRaY7og


# You can replace this text with custom content, and it will be preserved on regeneration
1;

=head1 NAME

ESD::Schema - DBIC Schema for ESD

=head1 DESCRIPTION

All this module does is load all the ESD::Schema::* classes. You
probably want to look at those instead. See L<ESD::Model::ESDDB>
for the full list.

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

