package Bio::GMOD::CMap::Apache::HelpViewer;
# vim: set ft=perl:

# $Id: HelpViewer.pm,v 1.12 2003-10-29 20:42:11 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.12 $)[-1];

use Apache::Constants;

use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATES     => {
    default                => 'help_map_viewer.tmpl',
    correspondence_details => 'help_correspondence.tmpl',
    evidence_type_info     => 'help_evidence_type_info.tmpl',
    feature_alias_details  => 'help_feature_alias_details.tmpl',
    feature_details        => 'help_feature_details.tmpl',
    feature_search         => 'help_feature_search.tmpl',
    feature_type_info      => 'help_feature_type_info.tmpl',
    matrix                 => 'help_matrix.tmpl',
    map_set_info           => 'help_map_set_info.tmpl',
    map_type_info          => 'help_map_type_info.tmpl',
    map_details            => 'help_map_details.tmpl',
    map_viewer             => 'help_map_viewer.tmpl',
    species_info           => 'help_species_info.tmpl',
};

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;

    my $section  = $apr->param('section') || '';
    $section     = 'default' unless defined TEMPLATES->{ $section };
    my $template = TEMPLATES->{ $section };

    my $html;
    my $t = $self->template;
    $t->process( 
        $template, 
        { 
            page       => $self->page,
            stylesheet => $self->stylesheet,
        }, 
        \$html 
    ) or $html = $t->error;

    $apr->content_type('text/html');
    $apr->send_http_header;
    $apr->print( $html );
    return OK;
}

1;

# ----------------------------------------------------
# A burnt child loves the fire.
# Oscar Wilde
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::HelpViewer - show help

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/help>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::HelpViewer->super
  </Location>

=head1 DESCRIPTION

Displays the user help document for the maps. It's actually a minimal handler
that does little more than display an static HTML page. The reason the user
help isn't just static HTML is because it was deemed necessary to include the
help in other pages generated by Template Toolkit; therefore, the HTML was
moved into a template file in the "templates" directory so that Template
Toolkit could find and use it easily.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
