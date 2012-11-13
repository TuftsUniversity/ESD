package ESD::Controller::DepositSubmission;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller::HTML::FormFu';
use Catalyst qw/ -Debug ConfigLoader Unicode::Encoding /;

use English;
use DateTime;
# FIXME: Something that recently happened made it necessary to
# bring this in manually where before it worked. I'm not sure
# what.
use File::Path qw(make_path);

use XML::LibXML;

use DBI;

use Readonly;
Readonly my $XMLS_NS =>'http://www.w3.org/2001/XMLSchema-instance';


__PACKAGE__->config->{namespace} = 'deposit_submission';
    
sub deposit_submission : PathPart('deposit_submission') Chained('/') CaptureArgs(0) FormConfig {
    my $self = shift;
    my ( $c ) = @_;

    $c->stash->{name} = $c->user->cn;

    my $form = $c->stash->{form};
}

# generate a report spreadsheet of all submissions thus far
# TODO: delivery of the file via browser; reports by date range; reports by
# stored value of previously reported
sub report_generator : PathPart('report_generator') Chained('deposit_submission') FormConfig {
    my $self = shift;
    my ( $c ) = @_;
    # read db variablesfrom the config
    my $db_user = $c->config->{ "Model::ESDDB" }->{ connect_info }->{ user };
    my $db_pw = $c->config->{ "Model::ESDDB" }->{ connect_info }->{ password };

    $c->log->debug("entering report generating sub");

    my $form = $c->stash->{form};

    if ($form->submitted_and_valid) {

        my $dbh = DBI->connect('dbi:mysql:esd;max_allowed_packet=500MB', $db_user, $db_pw)
            or die "Connection Error: $DBI::errstr\n";

        # Make a directory for report
        my $unique_name = get_free_dirname();
        my $report_file = $c->config->{staging_directory}
                        . "/reports/report-"
                        .  $unique_name
                        . ".csv";
    
    $c->log->debug("report file is $report_file");
        my $sth = $dbh->prepare( "SELECT * INTO outfile " 
               . $dbh->quote ( $report_file )  
               . "fields terminated by ',' "
               . "enclosed by '\"' " 
               . "escaped by '\\\\' "
               . "lines terminated by '\\n' "
               . "from submissions "
               . "left join filenames "
               . "on submissions.id=filenames.submissionsid"
               );
        $sth->execute or die "Cannot execute: " . $sth->errstr ();
        $sth->finish;

   
        # before we leave, close the db connection
        $dbh->disconnect or die "Can't close db handle";

    }

}


# This runs the form which lets the user choose which
# type of deposit will be made
sub upload : PathPart('') Chained('deposit_submission') Args(0) {
    my $self = shift;
    my ( $c ) = @_;

    # See if the form's been submitted.
    if ( my $user_type = $c->req->params->{user_type} ) {
        # Why yes. Redirect to the upload creation form, given
        # this metadata ID.
        $c->res->redirect(
            $c->uri_for( "/deposit_submission/$user_type" )
        );
    }
}

# Does what it says on the tin. Unique directory name for the deposit
my $counter = 0;
sub get_free_dirname :Private {
    while(1) {
        my $dir_name =
            sprintf("%s_%s_%s",$$,$^T,$counter++);
        return $dir_name if not -e $dir_name;
    };
}

# FIXME: There is far too much replication in the next set of subroutines;
# the logic of what form firlds to give per route should not neccesitate
# unique subroutines!
#
# The form for  education Department qualifying paper submissions
#
sub ed_qp : PathPart('ed_qp') Chained('deposit_submission') FormConfig {
    my $self = shift;
    my ( $c ) = @_;
    # read db variablesfrom the config
    my $db_user = $c->config->{ "Model::ESDDB" }->{ connect_info }->{ user };
    my $db_pw = $c->config->{ "Model::ESDDB" }->{ connect_info }->{ password };

    my $form = $c->stash->{form};

    if ($form->submitted_and_valid) {

        # writing to a database gives this maximal reporting and output flexibility.
        # create the database handle
        my $dbh = DBI->connect('dbi:mysql:esd;max_allowed_packet=500MB', $db_user, $db_pw)
            or die "Connection Error: $DBI::errstr\n";

        # prep the variables which will be used to hold things we
        # have to do tests on
        my $multimedia_present;

        # Make a directory for files and metadata
        my $unique_name = get_free_dirname();
        my $staging_dir = $c->config->{staging_directory} . "/" .  $unique_name;
        unless ( -e $staging_dir ) {
            unless ( make_path( $staging_dir ) ) {
                die "Can't create Staging directory at $staging_dir: "
                    . $OS_ERROR;
            }
        }
    
        # the multimedia Boolean only gets a value if the user
        # selects the checkbox, so let's give it a value either
        # way
        if ( ! $c->req->params->{multimedia} ) {
            $multimedia_present = 0;
        } else {
            $multimedia_present = 1;
        }

        # FIXME: how do I make it get the license version number
        # from the code?
        # create the statement handle
        my $sth = $dbh->prepare( "INSERT INTO submissions "
               . "set submitter=" . $dbh->quote ( $c->user->username ) . ", "
               . "fullname=" . $dbh->quote ( $c->user->cn ) . ", "
               . "department='ed_qp', "
               . "title=" . $dbh->quote ( $c->req->params->{title} ) . ", "
               . "directory=" . $dbh->quote ( $staging_dir ) . ", "
               . "license=" . $dbh->quote ( 'ed_qp1.0' ) . ", "
               . "multimedia=" . $dbh->quote ( $multimedia_present ) . ", "
               . "abstract=" . $dbh->quote ( $c->req->params->{abstract} )
               );
        $sth->execute or die "Cannot execute: " . $sth->errstr ();
	my $id = $dbh->last_insert_id(undef, undef, undef, undef)
	    or die "no insert id?";
        $sth->finish;

        # upload the file into the same directory
        my $files = $c->req->uploads->{file};
        unless ( ref $files && ref $files eq 'ARRAY' ) {
	    $files = [ $files ];
        }
    
        # make a variable to hold the list of filenames
        my $uploaded;

        for my $upload ( @$files ) {
	    my $filename = $upload->filename;
	    my $target   = File::Spec->catfile( $staging_dir, $filename );
    
            $uploaded .= $filename . " (" . int ( $upload->size / 1024 ) .  " KB) ";

	    unless ( $upload->link_to( $target)
		     || $upload->copy_to( $target ) ) {
	        die "Can't write $filename to $target: $OS_ERROR";
	    }
	 
	    $sth = $dbh->prepare( "INSERT into filenames "
	        . "set submissionsid=$id, "
		. "filename=" . $dbh->quote ( $filename )
                );
            $sth->execute or die "Cannot execute: " . $sth->errstr ();
    
            $sth->finish;

        }

 
        # put all of the variables into the stash so they can be
        # relayed in e-mail.
        # FIXME: I bet there is an easier way to do this.
        $c->stash->{dir} = $staging_dir;
        $c->stash->{uploaded} = $uploaded;
        $c->stash->{username} = $c->user->username;
        $c->stash->{title} = $c->req->params->{title};
        $c->stash->{multimedia} = $c->req->params->{multimedia};
        $c->stash->{abstract} = $c->req->params->{abstract};
   
       # before we leave, close the db connection
       $dbh->disconnect or die "Can't close db handle";

       $c->forward( 'mail_ed_qp_completed' );
    }

}

sub ed_qp_license : Chained('deposit_submission')
PathPart('ed_qp_license') Args(0) ActionClass('RenderView') {
    my $self = shift;
    my ( $c ) = @_;
    my $template = $c->stash->{template};
}




#
# The form for fletcher submissions
#
sub fletcher : PathPart('fletcher') Chained('deposit_submission') FormConfig {
    my $self = shift;
    my ( $c ) = @_;
    # read db variablesfrom the config
    my $db_user = $c->config->{ "Model::ESDDB" }->{ connect_info }->{ user };
    my $db_pw = $c->config->{ "Model::ESDDB" }->{ connect_info }->{ password };

    my $form = $c->stash->{form};

    if ($form->submitted_and_valid) {

        # writing to a database gives this maximal reporting and output flexibility.
        # create the database handle
        my $dbh = DBI->connect('dbi:mysql:esd;max_allowed_packet=500MB', $db_user, $db_pw)
            or die "Connection Error: $DBI::errstr\n";

        # prep the variables which will be used to hold things we
        # have to do tests on
        my $department;
        my $multimedia_present;

        # Make a directory for files and metadata
        my $unique_name = get_free_dirname();
        my $staging_dir = $c->config->{staging_directory} . "/" .  $unique_name;
        unless ( -e $staging_dir ) {
            unless ( make_path( $staging_dir ) ) {
                die "Can't create Staging directory at $staging_dir: "
                    . $OS_ERROR;
            }
        }

        # the multimedia Boolean only gets a value if the user
        # selects the checkbox, so let's give it a value either
        # way
        if ( ! $c->req->params->{multimedia} ) {
            $multimedia_present = 0;
        } else {
            $multimedia_present = 1;
        }

        # FIXME: how do I make it get the license version number
        # from the code?
         my $sth = $dbh->prepare( "INSERT INTO submissions "
                . "set submitter=" . $dbh->quote ( $c->user->username ) . ", "
                . "fullname=" . $dbh->quote ( $c->user->cn ) . ", "
                . "department=" . $dbh->quote ( $c->req->params->{department} ) . ", "
                . "title=" . $dbh->quote ( $c->req->params->{title} ) . ", "
                . "directory=" . $dbh->quote ( $staging_dir ) . ", "
                . "license=" . $dbh->quote ( 'fletcher1.0' ) . ", "
                . "multimedia=" . $dbh->quote ( $multimedia_present ) . ", "
                . "abstract=" . $dbh->quote ( $c->req->params->{abstract} )
                );
        $sth->execute or die "Cannot execute: " . $sth->errstr ();
	my $id = $dbh->last_insert_id(undef, undef, undef, undef)
	    or die "no insert id";
        $sth->finish;

        # upload the file into the same directory
        my $files = $c->req->uploads->{file};
        unless ( ref $files && ref $files eq 'ARRAY' ) {
	    $files = [ $files ];
        }
    
        # make a variable to hold the list of filenames
        my $uploaded;

        for my $upload ( @$files ) {
	    my $filename = $upload->filename;
	    my $target   = File::Spec->catfile( $staging_dir, $filename );
    
            $uploaded .= $filename . " (" . int ( $upload->size / 1024 ) .  " KB) ";

	    unless ( $upload->link_to( $target)
		     || $upload->copy_to( $target ) ) {
	        die "Can't write $filename to $target: $OS_ERROR";
	    }
	 
	    $sth = $dbh->prepare( "INSERT into filenames "
	        . "set submissionsid=$id, "
		. "filename=" . $dbh->quote ( $filename )
                );
            $sth->execute or die "Cannot execute: " . $sth->errstr ();
    
            $sth->finish;

        }

 
        # put all of the variables into the stash so they can be
        # relayed in e-mail.
        # FIXME: I bet there is an easier way to do this.
        $c->stash->{dir} = $staging_dir;
        $c->stash->{uploaded} = $uploaded;
        $c->stash->{username} = $c->user->username;
        $c->stash->{department} = $c->req->params->{department};
        $c->stash->{title} = $c->req->params->{title};
        $c->stash->{multimedia} = $c->req->params->{multimedia};
        $c->stash->{abstract} = $c->req->params->{abstract};
   
       # before we leave, close the db connection
       $dbh->disconnect or die "Can't close db handle";

       $c->forward( 'mail_fletcher_completed' );
    }
}

sub fletcher_license : Chained('deposit_submission')
PathPart('fletcher_license') Args(0) ActionClass('RenderView') {
    my $self = shift;
    my ( $c ) = @_;
    my $template = $c->stash->{template};
}


#
# The form for undergraduate submissions
#
sub undergrad : PathPart('undergrad') Chained('deposit_submission') FormConfig {
    my $self = shift;
    my ( $c ) = @_;
    # read db variablesfrom the config
    my $db_user = $c->config->{ "Model::ESDDB" }->{ connect_info }->{ user };
    my $db_pw = $c->config->{ "Model::ESDDB" }->{ connect_info }->{ password };

    my $form = $c->stash->{form};

    if ($form->submitted_and_valid) {

        # writing to a database gives this maximal reporting and output flexibility.
        # create the database handle
        my $dbh = DBI->connect('dbi:mysql:esd;max_allowed_packet=500MB', $db_user, $db_pw)
            or die "Connection Error: $DBI::errstr\n";

        # prep the variables which will be used to hold things we
        # have to do tests on
        my $department;
        my $department_select;
        my $multimedia_present;

        # Make a directory for files and metadata
        my $unique_name = get_free_dirname();
        my $staging_dir = $c->config->{staging_directory} . "/" .  $unique_name;
        unless ( -e $staging_dir ) {
            unless ( make_path( $staging_dir ) ) {
                die "Can't create Staging directory at $staging_dir: "
                    . $OS_ERROR;
            }
        }
    
        # If the department selected off the drop down is
        # "other", take the value from the text field
        if ( $c->req->params->{department} eq "other" ) {
            $department = $c->req->params->{otherdept};
            $department_select = 0;
        } else {
            $department = $c->req->params->{department};
            $department_select = 1;
        }

        # the multimedia Boolean only gets a value if the user
        # selects the checkbox, so let's give it a value either
        # way
        if ( ! $c->req->params->{multimedia} ) {
            $multimedia_present = 0;
        } else {
            $multimedia_present = 1;
        }

    $c->log->debug("department is $department, department_select is $department_select");

        # FIXME: how do I make it get the license version number
        # from the code?
         my $sth = $dbh->prepare( "INSERT INTO submissions "
                . "set submitter=" . $dbh->quote ( $c->user->username ) . ", "
                . "fullname=" . $dbh->quote ( $c->user->cn ) . ", "
                . "department=" . $dbh->quote ( $department ) . ", "
                . "department_select=" . $dbh->quote ( $department_select ) . ", "
                . "title=" . $dbh->quote ( $c->req->params->{title} ) . ", "
                . "directory=" . $dbh->quote ( $staging_dir ) . ", "
                . "license=" . $dbh->quote ( 'ugl1.0' ) . ", "
                . "multimedia=" . $dbh->quote ( $multimedia_present ) . ", "
                . "abstract=" . $dbh->quote ( $c->req->params->{abstract} )
                );
        $sth->execute or die "Cannot execute: " . $sth->errstr ();
	my $id = $dbh->last_insert_id(undef, undef, undef, undef)
	    or die "no insert id?";
        $sth->finish;

        # upload the file into the same directory
        my $files = $c->req->uploads->{file};
        unless ( ref $files && ref $files eq 'ARRAY' ) {
	    $files = [ $files ];
        }
    
        # make a variable to hold the list of filenames
        my $uploaded;
    
        for my $upload ( @$files ) {
	    my $filename = $upload->filename;
	    my $target   = File::Spec->catfile( $staging_dir, $filename );
    
            $uploaded .= $filename . " (" . int ( $upload->size / 1024 ) .  " KB) ";
    
	    unless ( $upload->link_to( $target)
		     || $upload->copy_to( $target ) ) {
	        die "Can't write $filename to $target: $OS_ERROR";
	    }
	 
	    $sth = $dbh->prepare( "INSERT into filenames "
	        . "set submissionsid=$id, "
		. "filename=" . $dbh->quote ( $filename )
                );
            $sth->execute or die "Cannot execute: " . $sth->errstr ();
    
            $sth->finish;

        }
 
        # put all of the variables into the stash so they can be
        # relayed in e-mail.
        # FIXME: I bet there is an easier way to do this.
        $c->stash->{dir} = $staging_dir;
        $c->stash->{username} = $c->user->username;
        $c->stash->{uploaded} = $uploaded;
        $c->stash->{department} = $c->req->params->{department};
        $c->stash->{title} = $c->req->params->{title};
        $c->stash->{multimedia} = $c->req->params->{multimedia};
        $c->stash->{abstract} = $c->req->params->{abstract};
   
       # before we leave, close the db connection
       $dbh->disconnect or die "Can't close db handle";

       $c->forward( 'mail_undergrad_completed' );
    }

}

sub undergrad_license : Chained('deposit_submission') PathPart('undergrad_license') Args(0) ActionClass('RenderView') {
    my $self = shift;
    my ( $c ) = @_;
    my $template = $c->stash->{template};
}


#
# The form for faculty submissions
#
sub faculty : PathPart('faculty') Chained('deposit_submission') FormConfig {
    my $self = shift;
    my ( $c ) = @_;
    # read db variablesfrom the config
    my $db_user = $c->config->{ "Model::ESDDB" }->{ connect_info }->{ user };
    my $db_pw = $c->config->{ "Model::ESDDB" }->{ connect_info }->{ password };

    my $form = $c->stash->{form};

    if ($form->submitted_and_valid) {

        # writing to a database gives this maximal reporting and output flexibility.
        # create the database handle
        my $dbh = DBI->connect('dbi:mysql:esd;max_allowed_packet=500MB', $db_user, $db_pw)
            or die "Connection Error: $DBI::errstr\n";

        # prep the variables which will be used to hold things we
        # have to do tests on
        my $department;
        my $department_select;
        my $multimedia_present;

        # Make a directory for files and metadata
        my $unique_name = get_free_dirname();
        my $staging_dir = $c->config->{staging_directory} . "/" .  $unique_name;
        unless ( -e $staging_dir ) {
            unless ( make_path( $staging_dir ) ) {
                die "Can't create Staging directory at $staging_dir: "
                    . $OS_ERROR;
            }
        }
    
        # If the department selected off the drop down is
        # "other", take the value from the text field
        if ( $c->req->params->{department} eq "other" ) {
            $department = $c->req->params->{otherdept};
            $department_select = 0;
        } else {
            $department = $c->req->params->{department};
            $department_select = 1;
        }

        # the multimedia Boolean only gets a value if the user
        # selects the checkbox, so let's give it a value either
        # way
        if ( ! $c->req->params->{multimedia} ) {
            $multimedia_present = 0;
        } else {
            $multimedia_present = 1;
        }

        # FIXME: how do I make it get the license version number
        # from the code?
         my $sth = $dbh->prepare( "INSERT INTO submissions "
                . "set submitter=" . $dbh->quote ( $c->user->username ) . ", "
                . "fullname=" . $dbh->quote ( $c->user->cn ) . ", "
                . "department=" . $dbh->quote ( $department ) . ", "
                . "department_select=" . $dbh->quote ( $department_select ) . ", "
                . "citation=" . $dbh->quote ( $c->req->params->{citation} ) . ", "
                . "title=" . $dbh->quote ( $c->req->params->{title} ) . ", "
                . "directory=" . $dbh->quote ( $staging_dir ) . ", "
                . "license=" . $dbh->quote ( 'fac1.0' ) . ", "
                . "multimedia=" . $dbh->quote ( $multimedia_present ) . ", "
                . "abstract=" . $dbh->quote ( $c->req->params->{abstract} ) . ", "
                . "otherauthor=" . $dbh->quote ( $c->req->params->{otherauthor} )
                );
        $sth->execute or die "Cannot execute: " . $sth->errstr ();
	my $id = $dbh->last_insert_id(undef, undef, undef, undef)
	    or die "no insert id?";
        $sth->finish;

        # upload the file into the same directory
        my $files = $c->req->uploads->{file};
        unless ( ref $files && ref $files eq 'ARRAY' ) {
	    $files = [ $files ];
        }
    
        # make a variable to hold the list of filenames
        my $uploaded;
    
        for my $upload ( @$files ) {
	    my $filename = $upload->filename;
	    my $target   = File::Spec->catfile( $staging_dir, $filename );
    
            $uploaded .= $filename . " (" . int ( $upload->size / 1024 ) .  " KB) ";
    
	    unless ( $upload->link_to( $target)
		     || $upload->copy_to( $target ) ) {
	        die "Can't write $filename to $target: $OS_ERROR";
	    }
	 
	    $sth = $dbh->prepare( "INSERT into filenames "
	        . "set submissionsid=$id, "
		. "filename=" . $dbh->quote ( $filename )
                );
            $sth->execute or die "Cannot execute: " . $sth->errstr ();
    
            $sth->finish;

        }
    
        # put all of the variables into the stash so they can be
        # relayed in e-mail.
        # FIXME: I bet there is an easier way to do this.
        $c->stash->{dir} = $staging_dir;
        $c->stash->{username} = $c->user->username;
        $c->stash->{uploaded} = $uploaded;
        $c->stash->{department} = $c->req->params->{department};
        $c->stash->{citation} = $c->req->params->{citation};
        $c->stash->{multimedia} = $c->req->params->{multimedia};
        $c->stash->{otherauthor} = $c->req->params->{otherauthor};
        # so we don't need multiple e-mail templates (faculty papers have a
        # citation instead of a title, but both are used in different ways
        # in the mail templates)
        $c->stash->{title} = $c->req->params->{citation};

       # before we leave, close the db connection
       $dbh->disconnect or die "Can't close db handle";

       $c->forward( 'mail_faculty_completed' );
    }

}

sub faculty_license : Chained('deposit_submission') PathPart('faculty_license') Args(0) ActionClass('RenderView') {
    my $self = shift;
    my ( $c ) = @_;
    my $template = $c->stash->{template};
}

sub mail_ed_qp_completed :Private {
    my $self = shift;
    my ( $c ) = @_;

    $c->log->debug('Sending mail to DCA staff ('
		   . $c->config->{dca_staff_email}
		   . ')' );
    # Mail DCA staff about the thesis
    $c->email(
        header =>
            [ To      => $c->config->{dca_staff_email},
              From    => $c->config->{from_name} 
	                 . ' <'
	                 . $c->config->{from_address}
	                 . '>',
              Subject => $c->view('NoWrapperTT')
                  ->render($c,'deposit_submission/subject_ed_qp.tt2'),
            ],
        attributes =>
            {
              content_type => 'text/plain',
              charset => 'UTF-8',
            },
        body   => $c->view('NoWrapperTT')->render($c,'deposit_submission/body_ed_qp.tt2'),
    );
 
    # Mail user about the paper
    $c->email(
        header =>
            [ To      => $c->user->username
                         . '@tufts.edu',
              From    => $c->config->{from_name}
                         . ' <'
	                 . $c->config->{from_address}
	                 . '>',
              Subject => $c->view('NoWrapperTT')
                  ->render($c,'deposit_submission/subject_response.tt2')
              ],
        attributes =>
            {
              content_type => 'text/plain',
              charset => 'UTF-8',
            },
        body   =>
        $c->view('NoWrapperTT')->render($c,'deposit_submission/body_response.tt2'),
    );
       
    # Kick the user back to the RSA-creation front page.
    $c->flash->{thesis_complete} = 1;
    $c->res->redirect( $c->uri_for( '/deposit_submission' ) );
}

sub mail_fletcher_completed :Private {
    my $self = shift;
    my ( $c ) = @_;

    $c->log->debug('Sending mail to DCA staff ('
		   . $c->config->{dca_staff_email}
		   . ')' );
    # Mail DCA staff about the thesis
    $c->email(
        header =>
            [ To      => $c->config->{dca_staff_email},
              From    => $c->config->{from_name} 
	                 . ' <'
	                 . $c->config->{from_address}
	                 . '>',
              Subject => $c->view('NoWrapperTT')
                  ->render($c,'deposit_submission/subject_fletcher.tt2'),
            ],
        attributes =>
            {
              content_type => 'text/plain',
              charset => 'UTF-8',
            },
        body   => $c->view('NoWrapperTT')->render($c,'deposit_submission/body_fletcher.tt2'),
    );
 
    # Mail user about the paper
    $c->email(
        header =>
            [ To      => $c->user->username
                         . '@tufts.edu',
              From    => $c->config->{from_name}
                         . ' <'
	                 . $c->config->{from_address}
	                 . '>',
              Subject => $c->view('NoWrapperTT')
                  ->render($c,'deposit_submission/subject_response.tt2')
              ],
        attributes =>
            {
              content_type => 'text/plain',
              charset => 'UTF-8',
            },
        body   =>
        $c->view('NoWrapperTT')->render($c,'deposit_submission/body_response.tt2'),
    );
       
    # Kick the user back to the RSA-creation front page.
    $c->flash->{thesis_complete} = 1;
    $c->res->redirect( $c->uri_for( '/deposit_submission' ) );
}


sub mail_faculty_completed :Private {
    my $self = shift;
    my ( $c ) = @_;

    $c->log->debug('Sending mail to DCA staff ('
		   . $c->config->{dca_staff_email}
		   . ')' );
    # Mail DCA staff about the thesis
    $c->email(
        header =>
            [ To      => $c->config->{dca_staff_email},
              From    => $c->config->{from_name} 
	                 . ' <'
	                 . $c->config->{from_address}
	                 . '>',
              Subject => $c->view('NoWrapperTT')
                  ->render($c,'deposit_submission/subject_faculty.tt2')
              ],
        attributes =>
            {
              content_type => 'text/plain',
              charset => 'UTF-8',
            },
        body   => $c->view('NoWrapperTT')->render($c,'deposit_submission/body_faculty.tt2'),
    );
 
    # Mail user about the paper
    $c->email(
        header =>
            [ To      => $c->user->username
                         . '@tufts.edu',
              From    => $c->config->{from_name}
                         . ' <'
	                 . $c->config->{from_address}
	                 . '>',
              Subject => $c->view('NoWrapperTT')
                  ->render($c,'deposit_submission/subject_response.tt2')
              ],
        attributes =>
            {
              content_type => 'text/plain',
              charset => 'UTF-8',
            },
        body   =>
        $c->view('NoWrapperTT')->render($c,'deposit_submission/body_response.tt2'),
    );
       
    # Kick the user back to the RSA-creation front page.
    $c->flash->{thesis_complete} = 1;
    $c->res->redirect( $c->uri_for( '/deposit_submission' ) );
}


sub mail_undergrad_completed :Private {
    my $self = shift;
    my ( $c ) = @_;

    $c->log->debug('Sending mail to DCA staff ('
		   . $c->config->{dca_staff_email}
		   . ')' );
    # Mail DCA staff about the thesis
    $c->email(
        header =>
            [ To      => $c->config->{dca_staff_email},
              From    => $c->config->{from_name} 
	                 . ' <'
	                 . $c->config->{from_address}
	                 . '>',
              Subject => $c->view('NoWrapperTT')
                  ->render($c,'deposit_submission/subject_undergrad.tt2')
              ],
        attributes =>
            {
              content_type => 'text/plain',
              charset => 'UTF-8',
            },
        body   => $c->view('NoWrapperTT')->render($c,'deposit_submission/body_undergrad.tt2'),
    );

    # Mail user about the paper
    $c->email(
        header =>
            [ To      => $c->user->username
                         . '@tufts.edu',
              From    => $c->config->{from_name}
                         . ' <'
	                 . $c->config->{from_address}
	                 . '>',
              Subject => $c->view('NoWrapperTT')
                  ->render($c,'deposit_submission/subject_response.tt2')
              ],
        attributes =>
            {
              content_type => 'text/plain',
              charset => 'UTF-8',
            },
        body   =>
        $c->view('NoWrapperTT')->render($c,'deposit_submission/body_response.tt2'),
    );


    # Kick the user back to the RSA-creation front page.
    $c->flash->{thesis_complete} = 1;
    $c->res->redirect( $c->uri_for( '/deposit_submission' ) );
}


1;

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
