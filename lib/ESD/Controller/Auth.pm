package ESD::Controller::Auth;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller::HTML::FormFu';

sub login : Local FormConfig CaptureArgs(3) {
}

sub login_FORM_SUBMITTED {
    my $self = shift;
    my ( $c, @args ) = @_;
    

    my $form = $c->stash->{form};

    my $username = $form->param_value( 'username' );
    my $password = $form->param_value( 'password' );

    my $auth_params = {
	id       => $username,
	password => $password,
    };
    
    if ( $c->authenticate( $auth_params ) ) {

        my $destination;

        # The redirect path comes in an array. Rejoin it into
        # the redirect path. If there is an easier way to do this
        # directly in Catalyst, I haven't found it.
        my $path = join( "/", @args );

        # If they went straight to the general login page, send them to
        # the home page once they have authenticated. Otherwise,
        # send them back to whereever they came from.
        if ( $c->request->path eq 'auth/login' ) {
            $destination = $c->uri_for("/");
        } else {
            $destination = $c->uri_for( "/" . $path );
        }

        $c->response->redirect($destination);
        $c->detach();
    }
    else {
	# User failed LDAP authentication.
	# Display an error and let them try again.
	$form->force_error_message(1);
	$form->form_error_message($form->stash->{bad_auth_message});
    }
}

sub login_f : Local FormConfig CaptureArgs(3) {
}

# Fletcher school requires a different post-login action
sub login_f_FORM_SUBMITTED {
    my $self = shift;
    my ( $c, @args ) = @_;
    

    my $form = $c->stash->{form};

    my $username = $form->param_value( 'username' );
    my $password = $form->param_value( 'password' );

    my $auth_params = {
	id       => $username,
	password => $password,
    };
    
    if ( $c->authenticate( $auth_params ) ) {

        my $destination;

        # The redirect path comes in an array. Rejoin it into
        # the redirect path. If there is an easier way to do this
        # directly in Catalysts, I haven't found it.
        my $path = join( "/", @args );

        # send them to the fletcher page once they have authenticated. 
        $c->log->debug("REACHED direct to fletcher login");
        $destination = $c->uri_for("/deposit_submission/fletcher");

        $c->response->redirect($destination);
        $c->detach();
    }
    else {
	# User failed LDAP authentication.
	# Display an error and let them try again.
	$form->force_error_message(1);
	$form->form_error_message($form->stash->{bad_auth_message});
    }
}

sub unregistered :Local {
}

sub logout : Local {
    my $self = shift;
    my ($c) = @_;

    if ($c->user) {
        $c->logout;
    }

    $c->res->redirect($c->uri_for('/'));
}

1;

=head1 NAME

ESD::Controller::Auth

=head1 DESCRIPTION

Catalyst controller for handling user authentication in the ESD app.

=head1 ACTIONS

=head2 Public Actions

The following documention describes, for each action, not just the
logic this module supplies, but a description of forms and other
information shown to the user via the associated TT templates and
FormFu forms.

=over

=item login
=item login_FORM_SUBMITTED
=item login_f
=item login_f_FORM_SUBMITTED

Path: auth/login

Displays and handles the login form.

If username and password are both supplied, then it tries to
authenticate the user against Tufts LDAP. On success, it then checks
ESD's own DB to make sure that the user's present there, as well. If
I<that> works, the user is forwarded the application root. Otherwise,
they're sent to the 'unregistered' action (see below).

=item unregistered

Path: auth/unregistered

Displays a page explaining that the user seems to be present in Tufts
LDAP, but is not a registered ESD user, and suggests some paths they
can take to rectify this.

Doesn't do any logic, otherwise.

=item logout

Path: auth/logout

Logs out the user, and returns them to the root path.

=back

=head1 AUTHOR

Deborah Kaplan

=head1 COPYRIGHT

Copyright (c) 2009 by Tufts University.


