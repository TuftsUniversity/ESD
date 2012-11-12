package ESD;

use strict;
use warnings;

use Catalyst::Runtime '5.70';

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root 
#                 directory

use parent qw/Catalyst/;
use Catalyst qw/
                Session
                Session::State::Cookie
                Session::Store::File
                ConfigLoader
                Static::Simple
                Authentication
                Authorization::Roles
                Cache
                Cache::Store::Memory
                Email
                DateTime
                Unicode::Encoding
               /;
our $VERSION = '0.01';

# All config's in esd.conf.
# Here are some defaults...

# Turn on Session's flash-to-stash feature.
__PACKAGE__->config( session => { flash_to_stash => 1 } );

# Check for an env var pointing to a different site-config file.
if ( defined $ENV{ESD_SITE_CONFIG} ) {
    __PACKAGE__->config( 'Plugin::ConfigLoader' => {
	file => $ENV{ESD_SITE_CONFIG},
    } );
}

#######################
# View configuration
#######################
# Here's the HTML view, which is the default.
__PACKAGE__->config->{'View::TT'} =
    {
        INCLUDE_PATH => [
            __PACKAGE__->path_to( qw ( root mail ) ),
            __PACKAGE__->path_to( qw ( root src ) ),
            __PACKAGE__->path_to( qw ( root lib ) ),
        ],
        CATALYST_VAR => 'Catalyst',
        WRAPPER => 'wrapper',
    };
__PACKAGE__->config->{default_view} = 'TT';

# Here's the plain-text view, whch is just like the HTML view except that
# it doesn't apply the wrapper template to it. Good for emails and stuff.
__PACKAGE__->config->{'View::NoWrapperTT'} =
    {
        INCLUDE_PATH => [
            __PACKAGE__->path_to( qw ( root mail ) ),
            __PACKAGE__->path_to( qw ( root src ) ),
            __PACKAGE__->path_to( qw ( root lib ) ),
        ],
        CATALYST_VAR => 'Catalyst',
    };

# Have the Static::Simple plugin handle everything _except_ TT files.                       
__PACKAGE__->config->{'Plugin::Static::Simple'}->{ignore_extensions} = [ qw/ tt tt2 / ];

# Set up role-based authorization.
#__PACKAGE__->config->{authorization}{dbic} = {
#    role_class           => 'ESDDB::Role',
#    role_field           => 'name',
#    user_role_user_field => 'user',
#    role_rel             => 'user_role',
#};

# Start the application
__PACKAGE__->setup();
=head1 NAME

ESD - Catalyst-based ESD support application

=head1 DESCRIPTION

This is the main module for the ESD web application. As with most Catalyst-based applications, most of the program logic is found in the various Controller, Schema and Logic modules. See L<"SEE ALSO"> for a complete list.

For more information about turning all this code into a working web application, see L<Catalyst>.
=cut

1;
