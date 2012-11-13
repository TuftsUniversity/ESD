package ESD::Controller::Root;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';

use Scalar::Util qw( looks_like_number );
use List::MoreUtils qw( each_array all any );

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

ESD::Controller::Root - Root Controller for ESD

=head1 DESCRIPTION

This is ESD's root controller. It's basically Catalyst's default
root controller, pretty much unchanged except for the documentation
you are now reading. More interesting controller activity occurs in
the various ESD::Controller::* modules.

=cut

# If the user gets anywhere and is not logged in, bring
# them straight to the login page
sub auto :Private {
    my ( $self, $c ) = @_;

        # Allow unauthenticated users to reach the login page.
        # This allows unauthenticated users to reach any action in the
        # Login controller. 
        if ( $c->controller eq $c->controller('Auth') ) {
            return 1;
        }
    
        # If a user doesn't exist, force login
        if ( !$c->user_exists ) {

            # Redirect the user to the login page 
            $c->response->redirect($c->uri_for('/auth/login', $c->request->path));

            # Return 0 to cancel 'post-auto' processing and
            # prevent use of application
            return 0;
        }
    
        # User found, so return 1 to continue with processing
        # after this 'auto'
        return 1;
}

sub index :Path :Args(0) {
}


sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
    
}

sub end : ActionClass('RenderView') {}

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
