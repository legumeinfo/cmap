package Bio::GMOD::CMap::Drawer::AppLayout;

# vim: set ft=perl:

# $Id: AppLayout.pm,v 1.25 2007-02-06 07:03:07 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Drawer::AppLayout - Layout Methods

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer::AppLayout;

=head1 DESCRIPTION

This module contains methods to layout the drawing surface

=head1 EXPORTED SUBROUTINES

=cut 

use strict;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Drawer::AppGlyph;
use Bio::GMOD::CMap::Utils qw[
    simple_column_distribution
    presentable_number
];

require Exporter;
use vars qw( $VERSION @EXPORT @EXPORT_OK );
$VERSION = (qw$Revision: 1.25 $)[-1];

use constant ZONE_SEPARATOR_HEIGHT => 3;
use constant ZONE_Y_BUFFER         => 30;
use constant MAP_Y_BUFFER          => 15;
use constant MAP_X_BUFFER          => 15;
use constant SMALL_BUFFER          => 2;
use constant MIN_MAP_WIDTH         => 40;
use constant BETWEEN_ZONE_BUFFER   => 5;

use base 'Exporter';

my @subs = qw[
    layout_new_window
    layout_zone
    layout_overview
    overview_selected_area
    layout_head_maps
    layout_sub_maps
    layout_zone_with_current_maps
    add_zone_separator
    add_correspondences
    set_zone_bgcolor
    move_zone
    move_map
];
@EXPORT_OK = @subs;
@EXPORT    = @subs;

my %SHAPE = (
    'default'  => \&_draw_box,
    'box'      => \&_draw_box,
    'dumbbell' => \&_draw_dumbbell,
    'I-beam'   => \&_draw_i_beam,
    'i-beam'   => \&_draw_i_beam,
    'I_beam'   => \&_draw_i_beam,
    'i_beam'   => \&_draw_i_beam,
);

# ----------------------------------------------------
sub layout_new_window {

    #print STDERR "AL_NEEDS_MODDED 1\n";

=pod

=head2 layout_new_window

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $head_zone_key    = $args{'head_zone_key'};
    my $app_display_data = $args{'app_display_data'};
    my $width            = $args{'width'} || 900;
    my $window_layout    = $app_display_data->{'window_layout'}{$window_key};

    # Initialize bounds
    # But have a height of 0.
    $window_layout->{'bounds'} = [ 0, 0, $width, 0, ];

    layout_zone(
        window_key       => $window_key,
        zone_key         => $head_zone_key,
        zone_bounds      => $window_layout->{'bounds'},
        app_display_data => $app_display_data,
    );
    my $window_height_change
        = $app_display_data->{'zone_layout'}{$head_zone_key}{'bounds'}[3]
        - $app_display_data->{'zone_layout'}{$head_zone_key}{'bounds'}[1];

    $app_display_data->modify_window_bottom_bound(
        window_key    => $window_key,
        bounds_change => $window_height_change,
    );

    $window_layout->{'changed'}     = 1;
    $window_layout->{'sub_changed'} = 1;

    return;
}

# ----------------------------------------------------
sub layout_overview {

    #print STDERR "AL_NEEDS_MODDED 2\n";

=pod

=head2 layout_overview



=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $app_display_data = $args{'app_display_data'};
    my $width            = $args{'width'} || 500;

    my $overview_layout = $app_display_data->{'overview_layout'}{$window_key};
    my $head_zone_key
        = $app_display_data->{'overview'}{$window_key}{'zone_key'};

    my $map_height = 5;
    $overview_layout->{'map_buffer_y'} = 5;
    my $zone_buffer_y = 15;
    my $zone_buffer_x = 15;

    $overview_layout->{'bounds'} = [ 0, 0, $width, 0 ];
    $overview_layout->{'maps_min_x'}
        = $overview_layout->{'bounds'}[0] + $zone_buffer_x;
    $overview_layout->{'maps_max_x'}
        = $overview_layout->{'bounds'}[2] - $zone_buffer_x;
    my $zone_min_y = 0;
    my $zone_max_y = 0;

    $zone_min_y += $zone_buffer_y;

    # zone_max_y is going to be used to place maps.
    $zone_max_y = $zone_min_y;

    my $zone_width
        = $overview_layout->{'maps_max_x'} - $overview_layout->{'maps_min_x'}
        + 1;

    # Layout Top Slot
    my $main_zone_layout = $app_display_data->{'zone_layout'}{$head_zone_key};
    my $top_pixel_factor = $zone_width / ( $main_zone_layout->{'maps_max_x'}
            - $main_zone_layout->{'maps_min_x'} );
    my $overview_zone_layout = $overview_layout->{'zones'}{$head_zone_key};
    $overview_zone_layout->{'scale_factor_from_main'} = $top_pixel_factor;
    $overview_zone_layout->{'bounds'}                 = [
        $overview_layout->{'maps_min_x'}, $zone_min_y,
        $overview_layout->{'maps_max_x'}, $zone_min_y
    ];

    $overview_layout->{'main_pixel_offset'}
        = $main_zone_layout->{'maps_min_x'};

    my @sorted_map_keys = sort {
        $app_display_data->{'map_layout'}{$a}{'bounds'}[1]
            <=> $app_display_data->{'map_layout'}{$b}{'bounds'}[1]

    } @{ $app_display_data->{'map_order'}{$head_zone_key} };

    return unless (@sorted_map_keys);

    my $last_y
        = $app_display_data->{'map_layout'}{ $sorted_map_keys[0] }{'bounds'}
        [1];
    foreach my $map_key (@sorted_map_keys) {
        my $map_layout = $app_display_data->{'map_layout'}{$map_key};
        unless ( $last_y == $map_layout->{'bounds'}[1] ) {
            $zone_max_y += $map_height + $overview_layout->{'map_buffer_y'};

            $last_y = $map_layout->{'bounds'}[1];
        }

        my $o_map_x1 = $top_pixel_factor * $map_layout->{'bounds'}[0];
        my $o_map_x2 = $top_pixel_factor * $map_layout->{'bounds'}[2];

        my $draw_sub_ref = $map_layout->{'shape_sub_ref'};

        my ( $bounds, $map_coords ) = &$draw_sub_ref(
            map_layout       => $overview_zone_layout->{'maps'}{$map_key},
            app_display_data => $app_display_data,
            min_x            => $o_map_x1,
            min_y            => $zone_max_y,
            max_x            => $o_map_x2,
            color            => $map_layout->{'color'},
            thickness        => $map_height,
        );

        $overview_zone_layout->{'maps'}{$map_key}{'changed'} = 1;
    }
    $overview_zone_layout->{'bounds'}[3]
        = $zone_max_y + $overview_layout->{'map_buffer_y'};
    $overview_zone_layout->{'changed'}     = 1;
    $overview_zone_layout->{'sub_changed'} = 1;
    $zone_max_y += $map_height + $zone_buffer_y;

    # create selected region
    # BF COME BACK TO THIS
    #overview_selected_area(
    #    zone_key         => $head_zone_key,
    #    window_key        => $window_key,
    #    app_display_data => $app_display_data,
    #);

    foreach my $child_zone_key ( @{ $overview_layout->{'child_zone_order'} } )
    {
        $main_zone_layout
            = $app_display_data->{'zone_layout'}{$child_zone_key};
        $overview_zone_layout = $overview_layout->{'zones'}{$child_zone_key};
        $overview_zone_layout->{'bounds'}[0]
            = $main_zone_layout->{'bounds'}[0] * $top_pixel_factor;
        $overview_zone_layout->{'bounds'}[1]
            = $zone_max_y - $overview_layout->{'map_buffer_y'};
        $overview_zone_layout->{'bounds'}[2]
            = $main_zone_layout->{'bounds'}[2] * $top_pixel_factor;

        my $child_pixel_factor = $top_pixel_factor
            * $app_display_data->{'scaffold'}{$child_zone_key}{'scale'};
        $overview_zone_layout->{'scale_factor_from_main'}
            = $child_pixel_factor;

        @sorted_map_keys = sort {
            $app_display_data->{'map_layout'}{$a}{'bounds'}[1]
                <=> $app_display_data->{'map_layout'}{$b}{'bounds'}[1]

        } @{ $app_display_data->{'map_order'}{$child_zone_key} };

        next unless (@sorted_map_keys);

        my $last_y = $app_display_data->{'map_layout'}{ $sorted_map_keys[0] }
            {'bounds'}[1];
        foreach my $map_key (@sorted_map_keys) {
            my $map_layout = $app_display_data->{'map_layout'}{$map_key};
            unless ( $last_y == $map_layout->{'bounds'}[1] ) {
                $zone_max_y
                    += $map_height + $overview_layout->{'map_buffer_y'};

                $last_y = $map_layout->{'bounds'}[1];
            }
            my $o_map_x1 = $child_pixel_factor * ( $map_layout->{'bounds'}[0]
                    - $overview_layout->{'main_pixel_offset'} )
                + $overview_layout->{'maps_min_x'};
            my $o_map_x2 = $child_pixel_factor * ( $map_layout->{'bounds'}[2]
                    - $overview_layout->{'main_pixel_offset'} )
                + $overview_layout->{'maps_min_x'};

            my $draw_sub_ref
                = _map_shape_sub_ref( map_layout => $map_layout, );

            my ( $bounds, $map_coords ) = &$draw_sub_ref(
                map_layout       => $overview_zone_layout->{'maps'}{$map_key},
                app_display_data => $app_display_data,
                min_x            => $o_map_x1,
                min_y            => $zone_max_y,
                max_x            => $o_map_x2,
                color            => $map_layout->{'color'},
                thickness        => $map_height,
            );

            $overview_zone_layout->{'maps'}{$map_key}{'changed'} = 1;
        }

        $zone_max_y += $map_height;
        $overview_zone_layout->{'bounds'}[3]   = $zone_max_y;
        $overview_zone_layout->{'changed'}     = 1;
        $overview_zone_layout->{'sub_changed'} = 1;
        $zone_max_y += $zone_buffer_y;

        # create selected region
        # BF COME BACK TO THIS
        #overview_selected_area(
        #    zone_key         => $child_zone_key,
        #    window_key        => $window_key,
        #    app_display_data => $app_display_data,
        #);
    }

    $overview_layout->{'bounds'}[3]   = $zone_max_y;
    $overview_layout->{'changed'}     = 1;
    $overview_layout->{'sub_changed'} = 1;

    return;
}

# ----------------------------------------------------
sub layout_zone {

    #print STDERR "AL_NEEDS_MODDED 3\n";

=pod

=head2 layout_zone

Lays out a zone

$zone_bounds only needs the first three (min_x,min_y,max_x)

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $zone_bounds      = $args{'zone_bounds'};
    my $app_display_data = $args{'app_display_data'};
    my $relayout         = $args{'relayout'} || 0;
    my $move_offset_x    = $args{'move_offset_x'} || 0;
    my $move_offset_y    = $args{'move_offset_y'} || 0;
    my $depth            = $args{'depth'} || 0;
    my $zone_layout      = $app_display_data->{'zone_layout'}{$zone_key};
    my $zone_width;

    if ($relayout) {

        $zone_width
            = $zone_layout->{'bounds'}[2] - $zone_layout->{'bounds'}[0];

        # This is being layed out again
        # Meaning we can reuse some of the work that has been done.
        if ( $depth == 0 ) {

            # This is the head zone for this relayout
            # We just need to modify the x_offset
            $app_display_data->{'scaffold'}{$zone_key}{'x_offset'}
                += $move_offset_x;
        }
        else {

            # This is one of the first levels of children.
            # We need to modify the bounds in relation to the parent zone
            $zone_layout->{'bounds'}[0] += $move_offset_x;
            $zone_layout->{'bounds'}[2] += $move_offset_x;
            $zone_layout->{'bounds'}[1] += $move_offset_y;
            $zone_layout->{'bounds'}[3] += $move_offset_y;

            # Now check to see if the visibility of this slot has changed
            my $parent_zone_key = $app_display_data->{'scaffold'}{$zone_key}
                {'parent_zone_key'};
            my $parent_zone_layout
                = $app_display_data->{'zone_layout'}{$parent_zone_key};
            my $new_viewable_internal_x1 = 0;
            my $new_viewable_internal_x2 = $zone_width;
            if ( $parent_zone_layout->{'viewable_internal_x1'}
                > $zone_layout->{'bounds'}[0] )
            {
                $new_viewable_internal_x1
                    = $zone_layout->{'internal_bounds'}[0]
                    + ( $parent_zone_layout->{'viewable_internal_x1'}
                        - $zone_layout->{'bounds'}[0] );
            }

            if ( $parent_zone_layout->{'viewable_internal_x2'}
                < $zone_layout->{'bounds'}[2] )
            {
                $new_viewable_internal_x2
                    = $zone_layout->{'internal_bounds'}[2]
                    - ( $zone_layout->{'bounds'}[2]
                        - $parent_zone_layout->{'viewable_internal_x1'} );
            }
            if ( $new_viewable_internal_x1
                == $zone_layout->{'viewable_internal_x1'}
                and $new_viewable_internal_x2
                == $zone_layout->{'viewable_internal_x2'} )
            {

                # Visibility hasn't changed, simpley move the zone
                move_zone(
                    zone_key         => $zone_key,
                    window_key       => $window_key,
                    app_display_data => $app_display_data,
                    app_interface    => $app_display_data->app_interface(),
                    x                => $move_offset_x,
                    y                => $move_offset_y,
                );
                return 0;
            }
        }
    }
    else {

        # Initialize bounds to the bounds of the window
        # starting at the lowest point available.
        # But have a height of 0.
        $zone_layout->{'bounds'} = [
            $zone_bounds->[0], $zone_bounds->[1],
            $zone_bounds->[2], $zone_bounds->[1],
        ];
        $zone_layout->{'internal_bounds'} = [ 0, 0, 0, 0, ];
        $zone_width = $zone_bounds->[2] - $zone_bounds->[0];
        unless ( $app_display_data->{'scaffold'}{$zone_key}{'is_top'} ) {

            # Make room for border if it is possible to have one.
            $zone_layout->{'bounds'}[3]
                += ZONE_SEPARATOR_HEIGHT + SMALL_BUFFER;
        }
    }

    my $zone_height_change = 0;
    if ( $app_display_data->{'scaffold'}{$zone_key}{'is_top'} ) {

        # These maps are "head" maps
        $zone_height_change = layout_head_maps(
            window_key       => $window_key,
            zone_key         => $zone_key,
            zone_width       => $zone_width,
            app_display_data => $app_display_data,
            relayout         => $relayout,
            move_offset_x    => $move_offset_x,
            move_offset_y    => $move_offset_y,
            depth            => $depth,
        );
    }
    else {

        # These maps are features of the parent map
        $zone_height_change = layout_sub_maps(
            window_key       => $window_key,
            zone_key         => $zone_key,
            zone_width       => $zone_width,
            app_display_data => $app_display_data,
            relayout         => $relayout,
            move_offset_x    => $move_offset_x,
            move_offset_y    => $move_offset_y,
            depth            => $depth,
        );
    }
    unless ( $app_display_data->{'scaffold'}{$zone_key}{'attached_to_parent'}
        or $app_display_data->{'scaffold'}{$zone_key}{'is_top'} )
    {

        # BF THIS NEEDS TO HANDLE RELAYOUTS
        add_zone_separator( zone_layout => $zone_layout, );
    }

    $zone_layout->{'sub_changed'} = 1;

    return $zone_height_change;
}

# ----------------------------------------------------
sub layout_head_maps {

    #print STDERR "AL_NEEDS_MODDED 6\n";

=pod

=head2 layout_head_maps

Lays out head maps in a zone

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $zone_width       = $args{'zone_width'};
    my $app_display_data = $args{'app_display_data'};
    my $relayout         = $args{'relayout'} || 0;
    my $move_offset_x    = $args{'move_offset_x'} || 0;
    my $move_offset_y    = $args{'move_offset_y'} || 0;
    my $depth            = $args{'depth'} || 0;
    my $zone_layout      = $app_display_data->{'zone_layout'}{$zone_key};

    #  Options that should be defined elsewhere
    my $stacked = 0;

    my $x_offset = $app_display_data->{'scaffold'}{$zone_key}{'x_offset'}
        || 0;

    if ( !$relayout ) {
        $zone_layout->{'internal_bounds'} = [ 0, 0, $zone_width, 0, ];
        $zone_layout->{'master_x1'}       = 0;
        $zone_layout->{'master_y1'}       = 0;
    }

    $zone_layout->{'viewable_internal_x1'} = 0;
    $zone_layout->{'viewable_internal_x2'} = $zone_width;

    my $left_bound        = MAP_X_BUFFER;
    my $right_bound       = $zone_width - MAP_X_BUFFER;
    my $active_zone_width = $right_bound - $left_bound;
    return 0 unless ($active_zone_width);

    my @ordered_map_ids = map { $app_display_data->{'map_key_to_id'}{$_} }
        @{ $app_display_data->{'map_order'}{$zone_key} || [] };
    my $map_data_hash = $app_display_data->app_data_module()
        ->map_data_hash( map_ids => \@ordered_map_ids, );

    unless ( $app_display_data->{'scaffold'}{$zone_key}{'map_set_id'} ) {
        my $map_set_id
            = $map_data_hash->{ $ordered_map_ids[0] }{'map_set_id'};
        $app_display_data->{'scaffold'}{$zone_key}{'map_set_id'}
            = $map_set_id;
    }

    # Set the background color
    $app_display_data->zone_bgcolor( zone_key => $zone_key, );

    my $pixels_per_unit = _pixels_per_map_unit(
        map_data_hash    => $map_data_hash,
        ordered_map_ids  => \@ordered_map_ids,
        zone_width       => $active_zone_width,
        zone_key         => $zone_key,
        stacked          => $stacked,
        app_display_data => $app_display_data,
    );

    # Store pixels_per_unit
    $app_display_data->{'scaffold'}{$zone_key}{'pixels_per_unit'}
        = $pixels_per_unit;

    my $map_min_x = $left_bound;
    my $row_min_y = MAP_Y_BUFFER;
    my $row_max_y = $row_min_y;
    my $row_index = 0;

    $zone_layout->{'maps_min_x'} = $map_min_x;

    foreach
        my $map_key ( @{ $app_display_data->{'map_order'}{$zone_key} || [] } )
    {
        my $map_id = $app_display_data->{'map_key_to_id'}{$map_key};
        my $map    = $map_data_hash->{$map_id};
        my $length = $map->{'map_stop'} - $map->{'map_start'};
        my $map_container_width = $length * $pixels_per_unit;

        # If the map is the minimum width,
        # Set the individual ppu otherwise clear it.
        if ( $map_container_width < MIN_MAP_WIDTH ) {
            $map_container_width = MIN_MAP_WIDTH;
            $app_display_data->{'map_pixels_per_unit'}{$map_key}
                = $map_container_width / $length;
        }
        elsif ( $app_display_data->{'map_pixels_per_unit'}{$map_key} ) {
            delete $app_display_data->{'map_pixels_per_unit'}{$map_key};
        }

        my $map_pixels_per_unit
            = $app_display_data->{'map_pixels_per_unit'}{$map_key}
            || $pixels_per_unit;

        if ( $stacked and $map_min_x != $left_bound ) {
            $map_min_x = $left_bound;
            $row_min_y = $row_max_y + MAP_Y_BUFFER;
            $row_index++;
        }
        my $map_max_x = $map_min_x + $map_container_width;

        # Set bounds so overview can access it later even if it
        # isn't on the screen.
        $app_display_data->{'map_layout'}{$map_key}{'bounds'}[0] = $map_min_x;
        $app_display_data->{'map_layout'}{$map_key}{'bounds'}[1] = $row_min_y;
        $app_display_data->{'map_layout'}{$map_key}{'bounds'}[2] = $map_max_x;

        # Set the shape of the map
        _map_shape_sub_ref(
            map_layout => $app_display_data->{'map_layout'}{$map_key},
            map        => $map,
        );

        if ( ( not defined $zone_layout->{'maps_max_x'} )
            or $zone_layout->{'maps_max_x'} < $map_max_x )
        {
            $zone_layout->{'maps_max_x'} = $map_max_x;
        }

        # If map is not on the screen, don't lay it out.
        if ( ( $map_min_x + $map_container_width + $x_offset )
            < $zone_layout->{'viewable_internal_x1'}
            or $map_min_x + $x_offset
            > $zone_layout->{'viewable_internal_x2'} )
        {
            next;
        }

        # Set the row index in case this zone needs to be split
        $app_display_data->{'map_layout'}{$map_key}{'row_index'} = $row_index;

        # Add info to zone_info needed for creation of correspondences
        _add_to_slot_info(
            app_display_data => $app_display_data,
            zone_key         => $zone_key,
            min_bound        => $left_bound,
            max_bound        => $right_bound,
            map_min_x        => $zone_layout->{'viewable_internal_x1'},
            map_max_x        => $zone_layout->{'viewable_internal_x2'},
            map_start        => $map->{'map_start'},
            map_stop         => $map->{'map_stop'},
            map_id           => $map->{'map_id'},
            x_offset         => $x_offset,
            pixels_per_unit  => $map_pixels_per_unit,
        );

        my $tmp_map_max_y = _layout_contained_map(
            app_display_data => $app_display_data,
            window_key       => $window_key,
            zone_key         => $zone_key,
            map_key          => $map_key,
            map              => $map,
            min_x            => $map_min_x,
            max_x            => $map_max_x,
            min_y            => $row_min_y,
            viewable_x1      => $zone_layout->{'viewable_internal_x1'},
            viewable_x2      => $zone_layout->{'viewable_internal_x2'},
            left_bound       => $left_bound,
            right_bound      => $right_bound,
            pixels_per_unit  => $map_pixels_per_unit,
            relayout         => $relayout,
            move_offset_x    => $move_offset_x,
            move_offset_y    => $move_offset_y,
            depth            => $depth,
        );
        if ( $row_max_y < $tmp_map_max_y ) {
            $row_max_y = $tmp_map_max_y;
        }

        $map_min_x += $map_container_width + MAP_X_BUFFER;
        $app_display_data->{'map_layout'}{$map_key}{'changed'} = 1;
    }

    my $height_change
        = $row_max_y + ZONE_Y_BUFFER - $zone_layout->{'bounds'}[3];
    $app_display_data->modify_zone_bottom_bound(
        window_key    => $window_key,
        zone_key      => $zone_key,
        bounds_change => $height_change,
    );
    if ( $depth == 0 ) {
        $app_display_data->modify_zone_bottom_bound(
            window_key    => $window_key,
            bounds_change => $height_change,
        );
    }

    $zone_layout->{'sub_changed'} = 1;
    $zone_layout->{'changed'}     = 1;

    # BF DON'T KNOW IF I NEED THIS ANYMORE
    #$app_display_data->create_zone_coverage_array( zone_key => $zone_key, );

    return $height_change;
}

# ----------------------------------------------------
sub layout_sub_maps {

    #print STDERR "AL_NEEDS_MODDED 7\n";

=pod

=head2 layout_sub_maps

Lays out sub maps in a slot. 

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $zone_width       = $args{'zone_width'};
    my $app_display_data = $args{'app_display_data'};
    my $relayout         = $args{'relayout'} || 0;
    my $move_offset_x    = $args{'move_offset_x'} || 0;
    my $move_offset_y    = $args{'move_offset_y'} || 0;
    my $depth            = $args{'depth'} || 0;
    my $zone_layout      = $app_display_data->{'zone_layout'}{$zone_key};

    my $parent_zone_key
        = $app_display_data->{'scaffold'}{$zone_key}{'parent_zone_key'};
    my $parent_map_key
        = $app_display_data->{'scaffold'}{$zone_key}{'parent_map_key'};
    my $parent_zone_layout
        = $app_display_data->{'zone_layout'}{$parent_zone_key};
    my $parent_map_layout
        = $app_display_data->{'map_layout'}{$parent_zone_key};
    my $scale = $app_display_data->{'scaffold'}{$zone_key}{'scale'} || 1;
    my $x_offset = $app_display_data->{'scaffold'}{$zone_key}{'x_offset'}
        || 0;

    my $row_min_y = MAP_Y_BUFFER;
    my $row_max_y = $row_min_y;

    if ($relayout) {

    }
    $zone_layout->{'internal_bounds'} = [ 0, 0, $zone_width, 0, ];
    $zone_layout->{'master_x1'}
        = $zone_layout->{'bounds'}[0] + $parent_zone_layout->{'master_x1'}
        + $app_display_data->{'scaffold'}{$parent_zone_key}{'x_offset'};
    $zone_layout->{'master_y1'}
        = $zone_layout->{'bounds'}[1] + $parent_zone_layout->{'master_y1'};
    $zone_layout->{'viewable_internal_x1'} = 0;
    $zone_layout->{'viewable_internal_x2'} = $zone_width;
    if ( $parent_zone_layout->{'viewable_internal_x1'}
        > $zone_layout->{'bounds'}[0] )
    {
        $zone_layout->{'viewable_internal_x1'}
            = $zone_layout->{'internal_bounds'}[0]
            + ( $parent_zone_layout->{'viewable_internal_x1'}
                - $zone_layout->{'bounds'}[0] );
    }

    if ( $parent_zone_layout->{'viewable_internal_x2'}
        < $zone_layout->{'bounds'}[2] )
    {
        $zone_layout->{'viewable_internal_x2'}
            = $zone_layout->{'internal_bounds'}[2]
            - ( $zone_layout->{'bounds'}[2]
                - $parent_zone_layout->{'viewable_internal_x1'} );
    }

    my $left_bound  = $zone_layout->{'internal_bounds'}[0];
    my $right_bound = $zone_layout->{'internal_bounds'}[2];

    # Sort maps for easier layout
    my @sub_map_keys = sort {
        $app_display_data->{'sub_maps'}{$a}
            {'parent_map_key'} <=> $app_display_data->{'sub_maps'}{$b}
            {'parent_map_key'}
            || $app_display_data->{'sub_maps'}{$a}
            {'feature_start'} <=> $app_display_data->{'sub_maps'}{$b}
            {'feature_start'}
            || $app_display_data->{'sub_maps'}{$a}
            {'feature_stop'} <=> $app_display_data->{'sub_maps'}{$b}
            {'feature_stop'}
            || $a cmp $b
    } @{ $app_display_data->{'map_order'}{$zone_key} || [] };

    my $first_map_data = $app_display_data->app_data_module()
        ->map_data(
        map_id => $app_display_data->{'map_key_to_id'}{ $sub_map_keys[0] }, );
    unless ( $app_display_data->{'scaffold'}{$zone_key}{'map_set_id'} ) {
        my $map_set_id = $first_map_data->{'map_set_id'};
        $app_display_data->{'scaffold'}{$zone_key}{'map_set_id'}
            = $map_set_id;
    }

    # Set the background color
    $app_display_data->zone_bgcolor( zone_key => $zone_key, );

    my @row_distribution_array = ();
    my @rows;

    my $parent_map_id = $app_display_data->{'map_key_to_id'}{$parent_map_key};
    my $parent_data   = $app_display_data->app_data_module()
        ->map_data( map_id => $parent_map_id, );
    my $parent_start = $parent_data->{'map_start'};
    my $parent_stop  = $parent_data->{'map_stop'};
    my $parent_pixels_per_unit
        = $app_display_data->{'map_pixels_per_unit'}{$parent_map_key}
        || $app_display_data->{'scaffold'}{$parent_zone_key}
        {'pixels_per_unit'};

    # Figure our where the parent start is in this zone's coordinate system
    my $parent_x1 = $parent_map_layout->{'coords'}[0]
        + $parent_zone_layout->{'bounds'}[0] - $zone_layout->{'bounds'}[0];
    my $parent_pixel_width = $parent_map_layout->{'coords'}[2]
        - $parent_map_layout->{'coords'}[0] + 1;

    foreach my $sub_map_key (@sub_map_keys) {
        my $feature_start
            = $app_display_data->{'sub_maps'}{$sub_map_key}{'feature_start'};
        my $feature_stop
            = $app_display_data->{'sub_maps'}{$sub_map_key}{'feature_stop'};

        my $x1_on_map
            = ( ( $feature_start - $parent_start ) * $parent_pixels_per_unit )
            * $scale;
        my $x2_on_map
            = ( ( $feature_stop - $parent_start ) * $parent_pixels_per_unit )
            * $scale;
        my $x1        = $parent_x1 + $x1_on_map;
        my $x2        = $parent_x1 + $x2_on_map;
        my $row_index = simple_column_distribution(
            low        => $x1_on_map,
            high       => $x2_on_map,
            columns    => \@row_distribution_array,
            map_height => ($parent_pixel_width) * $scale,    # actually width
            buffer     => MAP_X_BUFFER,
        );

        # BF DO I NEED TO STORE THIS?
        # Set the row index in case this zone needs to be split
        $app_display_data->{'map_layout'}{$sub_map_key}{'row_index'}
            = $row_index;

        push @{ $rows[$row_index] }, [ $sub_map_key, $x1, $x2 ];
    }

    my $map_pixels_per_unit;

    foreach my $row (@rows) {
        foreach my $row_sub_map ( @{ $row || [] } ) {
            my $sub_map_key = $row_sub_map->[0];
            my $x1          = $row_sub_map->[1];
            my $x2          = $row_sub_map->[2];
            my $sub_map_id
                = $app_display_data->{'map_key_to_id'}{$sub_map_key};
            my $sub_map_data = $app_display_data->app_data_module()
                ->map_data( map_id => $sub_map_id, );
            my $parent_map_key = $app_display_data->{'sub_maps'}{$sub_map_key}
                {'parent_map_key'};

            # Set map_pixels_per_unit
            $app_display_data->{'map_pixels_per_unit'}{$sub_map_key}
                = ( $x2 - $x1 + 1 ) / (
                $sub_map_data->{'map_stop'} - $sub_map_data->{'map_start'} );

            # Set bounds so overview can access it later even if it
            # isn't on the screen.
            $app_display_data->{'map_layout'}{$sub_map_key}{'bounds'}[0]
                = $x1;
            $app_display_data->{'map_layout'}{$sub_map_key}{'bounds'}[1]
                = $row_min_y;
            $app_display_data->{'map_layout'}{$sub_map_key}{'bounds'}[2]
                = $x2;

            # Set the shape of the map
            _map_shape_sub_ref(
                map_layout => $app_display_data->{'map_layout'}{$sub_map_key},
                map        => $sub_map_data,
            );

            if ( ( not defined $zone_layout->{'maps_min_x'} )
                or $zone_layout->{'maps_min_x'} > $x1 )
            {
                $zone_layout->{'maps_min_x'} = $x1;
            }
            if ( ( not defined $zone_layout->{'maps_max_x'} )
                or $zone_layout->{'maps_max_x'} < $x2 )
            {
                $zone_layout->{'maps_max_x'} = $x2;
            }

            # If map is not on the screen, don't lay it out.
            if (   $x2 + $x_offset < $zone_layout->{'viewable_internal_x1'}
                or $x1 + $x_offset > $zone_layout->{'viewable_internal_x2'} )
            {
                next;
            }

            $map_pixels_per_unit
                = $app_display_data->{'map_pixels_per_unit'}{$sub_map_key}
                = ( $x2 - $x1 ) / (
                $sub_map_data->{'map_stop'} - $sub_map_data->{'map_start'} );

            # Add info to slot_info needed for creation of correspondences
            _add_to_slot_info(
                app_display_data => $app_display_data,
                zone_key         => $zone_key,
                min_bound        => $left_bound,
                max_bound        => $right_bound,
                map_min_x        => $zone_layout->{'viewable_internal_x1'},
                map_max_x        => $zone_layout->{'viewable_internal_x2'},
                map_start        => $sub_map_data->{'map_start'},
                map_stop         => $sub_map_data->{'map_stop'},
                map_id           => $sub_map_data->{'map_id'},
                x_offset         => $x_offset,
                pixels_per_unit  => $map_pixels_per_unit,
            );

            my $tmp_map_max_y = _layout_contained_map(
                app_display_data => $app_display_data,
                window_key       => $window_key,
                zone_key         => $zone_key,
                map_key          => $sub_map_key,
                map              => $sub_map_data,
                min_x            => $x1,
                max_x            => $x2,
                viewable_x1      => $zone_layout->{'viewable_internal_x1'},
                viewable_x2      => $zone_layout->{'viewable_internal_x2'},
                min_y            => $row_min_y,
                left_bound       => $left_bound,
                right_bound      => $right_bound,
                pixels_per_unit  => $map_pixels_per_unit,
                relayout         => $relayout,
                move_offset_x    => $move_offset_x,
                move_offset_y    => $move_offset_y,
                depth            => $depth,
            );

            if ( $row_max_y < $tmp_map_max_y ) {
                $row_max_y = $tmp_map_max_y;
            }
            $app_display_data->{'map_layout'}{$sub_map_key}{'changed'} = 1;
        }
        $row_min_y = $row_max_y + MAP_Y_BUFFER;
    }

    my $height_change = $row_max_y + ZONE_Y_BUFFER - MAP_Y_BUFFER;
    $app_display_data->modify_zone_bottom_bound(
        window_key    => $window_key,
        zone_key      => $zone_key,
        bounds_change => $height_change,
    );
    if ( $depth == 0 ) {
        $app_display_data->modify_zone_bottom_bound(
            window_key    => $window_key,
            bounds_change => $height_change,
        );
    }

    $zone_layout->{'sub_changed'} = 1;
    $zone_layout->{'changed'}     = 1;

    # BF DON'T KNOW IF I NEED THIS ANYMORE
    #$app_display_data->create_zone_coverage_array( zone_key => $zone_key, );

    return $height_change;
}

## ----------------------------------------------------
#sub layout_zone_tree {
##print STDERR "AL_NEEDS_MODDED 3\n";
#
#=pod
#
#=head2 layout_zone_tree
#
#Lays out a zone and its children after they have been placed already.
#
#$zone_bounds only needs the first three (min_x,min_y,max_x)
#
#=cut
#
#    my %args             = @_;
#    my $window_key       = $args{'window_key'};
#    my $zone_key         = $args{'zone_key'};
#    my $app_display_data = $args{'app_display_data'};
#    my $zone_layout      = $app_display_data->{'zone_layout'}{$zone_key};
#    my $start_min_y      = $zone_bounds->[1];
#    my $start_max_y      = $zone_bounds->[3];
#
#    my $zone_width = $zone_bounds->[2]-$zone_bounds->[0];
#
#    if ( $app_display_data->{'scaffold'}{$zone_key}{'is_top'} ) {
#
#        # These maps are "head" maps
#        layout_head_maps(
#            window_key       => $window_key,
#            zone_key         => $zone_key,
#            zone_width       => $zone_width,
#            app_display_data => $app_display_data,
#        );
#    }
#    else {
#
#        # These maps are features of the parent map
#        layout_sub_maps(
#            window_key       => $window_key,
#            zone_key         => $zone_key,
#            zone_width       => $zone_width,
#            app_display_data => $app_display_data,
#        );
#    }
#    unless ( $app_display_data->{'scaffold'}{$zone_key}{'attached_to_parent'}
#        or $app_display_data->{'scaffold'}{$zone_key}{'is_top'} )
#    {
#        add_zone_separator( zone_layout => $zone_layout, );
#    }
#
#    $zone_layout->{'sub_changed'} = 1;
#
#    return;
#}

# ----------------------------------------------------
sub set_zone_bgcolor {

    #print STDERR "AL_NEEDS_MODDED 4\n";

=pod

=head2 set_zone_bgcolor



=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $app_display_data = $args{'app_display_data'};

    my $bgcolor = $app_display_data->zone_bgcolor( zone_key => $zone_key, );
    my $border_color =
        (       $app_display_data->{'selected_zone_key'}
            and $zone_key == $app_display_data->{'selected_zone_key'} )
        ? "black"
        : $bgcolor;

    my $background_id =
        defined( $app_display_data->{'zone_layout'}{$zone_key}{'background'} )
        ? $app_display_data->{'zone_layout'}{$zone_key}{'background'}[0][1]
        : undef;
    my $zone_layout = $app_display_data->{'zone_layout'}{$zone_key};
    $app_display_data->{'zone_layout'}{$zone_key}{'background'} = [
        [   1,
            $background_id,
            'rectangle',
            [   @{  $app_display_data->{'zone_layout'}{$zone_key}
                        {'internal_bounds'}
                    }
            ],
            { -fill => $bgcolor, -outline => $border_color, -width => 3 }
        ]
    ];

    $app_display_data->{'zone_layout'}{$zone_key}{'changed'}         = 1;
    $app_display_data->{'window_layout'}{$window_key}{'sub_changed'} = 1;

    return;
}

# ----------------------------------------------------
sub add_zone_separator {

    #print STDERR "AL_NEEDS_MODDED 5\n";

=pod

=head2 add_zone_separator

Lays out reference maps in a new zone

=cut

    my %args        = @_;
    my $slot_layout = $args{'slot_layout'};

    my $border_x1 = $slot_layout->{'bounds'}[0];
    my $border_y1 = $slot_layout->{'bounds'}[1];
    my $border_x2 = $slot_layout->{'bounds'}[2];
    $slot_layout->{'separator'} = [
        [   1, undef,
            'rectangle',
            [   $border_x1, $border_y1,
                $border_x2, $border_y1 + ZONE_SEPARATOR_HEIGHT
            ],
            { -fill => 'black', }
        ]
    ];
}

# ----------------------------------------------------
sub layout_zone_with_current_maps {

    #print STDERR "AL_NEEDS_MODDED 8\n";

=pod

=head2 layout_zone_with_current_maps

Lays out maps in a zone where they are already placed horizontally. 

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $panel_key        = $args{'panel_key'};
    my $old_slot_key     = $args{'old_slot_key'};
    my $new_slot_key     = $args{'new_slot_key'};
    my $row_index        = $args{'row_index'};
    my $start_min_y      = $args{'start_min_y'};
    my $map_keys         = $args{'map_keys'};
    my $app_display_data = $args{'app_display_data'};

    unless ( @{ $map_keys || [] } ) {
        die "No map keys provided to layout_slot_with_current_maps\n";
    }

    my $old_slot_layout = $app_display_data->{'slot_layout'}{$old_slot_key};
    my $new_slot_layout = $app_display_data->{'slot_layout'}{$new_slot_key};
    my $panel_layout    = $app_display_data->{'panel_layout'}{$panel_key};

    # DO ZONE STUFF

    # Initialize bounds to the bounds of the panel
    # But have a height of 0.
    $new_slot_layout->{'bounds'} = [
        $panel_layout->{'bounds'}[0], $start_min_y,
        $panel_layout->{'bounds'}[2], $start_min_y,
    ];

    unless (
        $app_display_data->{'scaffold'}{$new_slot_key}{'attached_to_parent'}
        or $app_display_data->{'scaffold'}{$new_slot_key}{'is_top'} )
    {
        add_slot_separator( slot_layout => $new_slot_layout, );
    }
    unless ( $app_display_data->{'scaffold'}{$new_slot_key}{'is_top'} ) {

        # Make room for border if it is possible to have one.
        $new_slot_layout->{'bounds'}[3]
            += ZONE_SEPARATOR_HEIGHT + SMALL_BUFFER;
    }

    # Move Maps

    my $new_min_y = $new_slot_layout->{'bounds'}[3] + MAP_Y_BUFFER;

    # Look at first map and work out vertical offset.

    my $ori_min_y
        = $app_display_data->{'map_layout'}{ $map_keys->[0] }{'bounds'}[1];

    my $y_offset = $new_min_y - $ori_min_y;

    my $max_y = $new_min_y;

    my $app_interface = $app_display_data->app_interface();

    foreach my $map_key ( @{ $map_keys || [] } ) {
        push @{ $app_display_data->{'map_order'}{$new_slot_key} }, $map_key;
        my $map_layout = $app_display_data->{'map_layout'}{$map_key};
        if ( $map_layout->{'bounds'}[3] + $y_offset > $max_y ) {
            $max_y = $map_layout->{'bounds'}[3] + $y_offset;
        }

        # Record max and min for overview
        if ( ( not defined $new_slot_layout->{'maps_min_x'} )
            or $new_slot_layout->{'maps_min_x'} > $map_layout->{'bounds'}[0] )
        {
            $new_slot_layout->{'maps_min_x'} = $map_layout->{'bounds'}[0];
        }
        if ( ( not defined $new_slot_layout->{'maps_max_x'} )
            or $new_slot_layout->{'maps_max_x'} < $map_layout->{'bounds'}[2] )
        {
            $new_slot_layout->{'maps_max_x'} = $map_layout->{'bounds'}[2];
        }

        move_map(
            app_display_data => $app_display_data,
            app_interface    => $app_interface,
            map_key          => $map_key,
            panel_key        => $panel_key,
            y                => $y_offset,
        );
    }

    my $height_change = $max_y - $start_min_y + MAP_Y_BUFFER;
    $app_display_data->modify_slot_bottom_bound(
        slot_key      => $new_slot_key,
        panel_key     => $panel_key,
        bounds_change => $height_change,
    );
    $panel_layout->{'sub_changed'}    = 1;
    $new_slot_layout->{'sub_changed'} = 1;
    $new_slot_layout->{'changed'}     = 1;
    $new_slot_layout->{'bounds'}[3]   = $max_y + MAP_Y_BUFFER;

    $app_display_data->create_slot_coverage_array( slot_key => $new_slot_key,
    );

    return $max_y;
}

# ----------------------------------------------------
sub _layout_contained_map {

    #print STDERR "AL_NEEDS_MODDED 9\n";

=pod

=head2 _layout_contained_map

Lays out a maps in a contained area.

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $map_key          = $args{'map_key'};
    my $map              = $args{'map'};
    my $min_x            = $args{'min_x'};
    my $max_x            = $args{'max_x'};
    my $min_y            = $args{'min_y'};
    my $viewable_x1      = $args{'viewable_x1'};
    my $viewable_x2      = $args{'viewable_x2'};
    my $left_bound       = $args{'left_bound'};
    my $right_bound      = $args{'right_bound'};
    my $pixels_per_unit  = $args{'pixels_per_unit'};
    my $relayout         = $args{'relayout'} || 0;
    my $move_offset_x    = $args{'move_offset_x'} || 0;
    my $move_offset_y    = $args{'move_offset_y'} || 0;
    my $depth            = $args{'depth'} || 0;
    my $font_height      = 15;

    my $map_layout = $app_display_data->{'map_layout'}{$map_key};

    if ($relayout) {

        # Check if we just need to move the map
        if (@{ $map_layout->{'bounds'} || [] }
            and ( $map_layout->{'coords'}[0] - $map_layout->{'bounds'}[0]
                == ( ( $min_x > $viewable_x1 ) ? $min_x : $viewable_x1 )
                - $min_x )
            and ( $map_layout->{'bounds'}[2] - $map_layout->{'coords'}[2]
                == $max_x
                - ( ( $max_x < $viewable_x2 ) ? $max_x : $viewable_x2 ) )
            )
        {
            my $app_interface = $app_display_data->app_interface();
            move_map(
                app_display_data => $app_display_data,
                app_interface    => $app_interface,
                map_key          => $map_key,
                zone_key         => $zone_key,
                window_key       => $window_key,
                x                => $move_offset_x,
                y                => $move_offset_y,
            );

            # return the lowest point for this map
            return $map_layout->{'bounds'}[3];
        }
        else {
            destroy_map_for_relayout(
                app_display_data => $app_display_data,
                map_key          => $map_key,
                window_key       => $window_key,
            );
        }
    }
    $map_layout->{'bounds'} = [ $min_x, $min_y, $max_x, $min_y ];

    my $max_y;

    # Work out truncation
    # 0: No Truncation
    # 1: Left Truncated
    # 2: Right Truncated
    # 3: Both Sides Truncated
    my $truncated = 0;
    if ( $min_x < $left_bound ) {
        $min_x = $left_bound;
        $truncated += 1;
    }
    if ( $max_x > $right_bound ) {
        $max_x = $right_bound;
        $truncated += 2;
    }

    push @{ $map_layout->{'items'} },
        (
        [   1, undef, 'text',
            [ ( $min_x > $viewable_x1 ) ? $min_x : $viewable_x1, $min_y ],
            {   -text   => $map->{'map_name'},
                -anchor => 'nw',
                -fill   => 'black',
            }
        ]
        );
    $min_y += $font_height * 2;

    # set the color of the map
    my $color = $map->{'color'}
        || $map->{'default_color'}
        || $app_display_data->config_data('map_color')
        || $map_layout->{'color'};
    $map_layout->{'color'} = $color;

    # set the thickness of the map
    my $thickness = $map->{'width'}
        || $map->{'default_width'}
        || $app_display_data->config_data('map_width');
    $map_layout->{'thickness'} = $thickness;

    # Get the shape of the map
    my $draw_sub_ref = _map_shape_sub_ref( map_layout => $map_layout, );

    my ( $bounds, $map_coords ) = &$draw_sub_ref(
        map_layout       => $map_layout,
        app_display_data => $app_display_data,
        min_x            => $min_x,
        min_y            => $min_y,
        max_x            => $max_x,
        viewable_x1      => $viewable_x1,
        viewable_x2      => $viewable_x2,
        color            => $color,
        thickness        => $thickness,
        truncated        => $truncated,
    );

    $map_layout->{'coords'} = $map_coords;

    # Unit tick marks
    my $tick_overhang = 8;
    _add_tick_marks(
        map              => $map,
        map_layout       => $map_layout,
        zone_key         => $zone_key,
        map_coords       => $map_coords,
        label_y          => $min_y - $font_height - $tick_overhang,
        label_x          => $min_x,
        app_display_data => $app_display_data,
    );
    $min_y = $max_y = $map_coords->[3];

    if ( $app_display_data->{'scaffold'}{$zone_key}{'show_features'} ) {
        $max_y = _layout_features(
            app_display_data => $app_display_data,
            zone_key         => $zone_key,
            map_key          => $map_key,
            map              => $map,
            min_x            => $min_x,
            max_x            => $max_x,
            min_y            => $min_y,
            viewable_x1      => $viewable_x1,
            viewable_x2      => $viewable_x2,
            pixels_per_unit  => $pixels_per_unit,
        );
    }

    foreach my $child_zone_key (
        @{ $app_display_data->{'scaffold'}{$zone_key}{'children'} || [] } )
    {
        next
            unless (
            $map_key == $app_display_data->{'scaffold'}{$child_zone_key}
            {'parent_map_key'} );
        my $zone_bounds = [
            $min_x
                + $app_display_data->{'zone_layout'}{$zone_key}{'bounds'}[0],
            $max_y
                + $app_display_data->{'zone_layout'}{$zone_key}{'bounds'}[1]
                + BETWEEN_ZONE_BUFFER,
            $max_x
                + $app_display_data->{'zone_layout'}{$zone_key}{'bounds'}[0],
        ];
        layout_zone(
            window_key       => $window_key,
            zone_key         => $child_zone_key,
            zone_bounds      => $zone_bounds,
            app_display_data => $app_display_data,
            relayout         => $relayout,
            move_offset_x    => $move_offset_x,
            move_offset_y    => $move_offset_y,
            depth            => $depth + 1,
        );
        $max_y
            += $app_display_data->{'zone_layout'}{$child_zone_key}{'bounds'}
            [3]
            - $app_display_data->{'zone_layout'}{$child_zone_key}{'bounds'}
            [1];
    }
    $map_layout->{'bounds'}[3] = $max_y;

    $map_layout->{'sub_changed'} = 1;

    return $max_y;
}

# ----------------------------------------------------
sub _layout_features {

    #print STDERR "AL_NEEDS_MODDED 10\n";

=pod

=head2 _layout_features

Lays out feautures 

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $zone_key         = $args{'zone_key'};
    my $map_key          = $args{'map_key'};
    my $map              = $args{'map'};
    my $min_x            = $args{'min_x'};
    my $min_y            = $args{'min_y'};
    my $max_x            = $args{'max_x'};
    my $viewable_x1      = $args{'viewable_x1'};
    my $viewable_x2      = $args{'viewable_x2'};
    my $pixels_per_unit  = $args{'pixels_per_unit'};

    my $max_y = $min_y;

    my $feature_height = 6;
    my $feature_buffer = 2;

    my $sorted_feature_data = $app_display_data->app_data_module()
        ->sorted_feature_data( map_id => $map->{'map_id'} );

    unless ( %{ $sorted_feature_data || {} } ) {
        return $min_y;
    }

    my $glyph = Bio::GMOD::CMap::Drawer::AppGlyph->new();

    my $map_start = $map->{'map_start'};

    for my $lane ( sort { $a <=> $b } keys %$sorted_feature_data ) {
        my $lane_features = $sorted_feature_data->{$lane};
        my $lane_min_y    = $max_y + SMALL_BUFFER;
        my @fcolumns;

        foreach my $feature ( @{ $lane_features || [] } ) {
            my $feature_acc      = $feature->{'feature_acc'};
            my $feature_start    = $feature->{'feature_start'};
            my $feature_stop     = $feature->{'feature_stop'};
            my $feature_type_acc = $feature->{'feature_type_acc'};
            my $feature_shape
                = $app_display_data->feature_type_data( $feature_type_acc,
                'shape' )
                || 'line';
            my $feature_glyph = $feature_shape;
            $feature_glyph =~ s/-/_/g;
            if ( $glyph->can($feature_glyph) ) {

                unless (
                    $app_display_data->{'map_layout'}{$map_key}{'features'}
                    {$feature_acc} )
                {
                    $app_display_data->{'map_layout'}{$map_key}{'features'}
                        {$feature_acc} = {};
                }
                my $column_index;
                my $feature_layout
                    = $app_display_data->{'map_layout'}{$map_key}{'features'}
                    {$feature_acc};

                my $x1 = $min_x
                    + ( ( $feature_start - $map_start ) * $pixels_per_unit );
                my $x2 = $min_x
                    + ( ( $feature_stop - $map_start ) * $pixels_per_unit );

                if ( not $glyph->allow_glyph_overlap($feature_glyph) ) {
                    my $adjusted_left  = $x1 - $min_x;
                    my $adjusted_right = $x2 - $min_x;
                    $column_index = simple_column_distribution(
                        low        => $adjusted_left,
                        high       => $adjusted_right,
                        columns    => \@fcolumns,
                        map_height => $max_x - $min_x + 1,
                        buffer     => SMALL_BUFFER,
                    );
                }
                else {
                    $column_index = 0;
                }

                my $label_features = 0;

                my $offset =
                    $label_features
                    ? ($column_index)
                    * ( $feature_height + $feature_buffer + 15 )
                    : ($column_index) * ( $feature_height + $feature_buffer );
                my $y1 = $lane_min_y + $offset;

                if ($label_features) {
                    push @{ $feature_layout->{'items'} },
                        (
                        [   1, undef, 'text',
                            [ $x1, $y1 ],
                            {   -text   => $feature->{'feature_name'},
                                -anchor => 'nw',
                                -fill   => 'black',
                            }
                        ]
                        );

                    $y1 += 15;
                }
                my $y2 = $y1 + $feature_height;

                my $color
                    = $app_display_data->feature_type_data( $feature_type_acc,
                    'color' )
                    || 'black';

                # Highlight features that are also sub maps
                if ( $feature->{'sub_map_id'} ) {
                    $color = 'red';
                }
                my $coords;
                ( $coords, $feature_layout->{'items'} )
                    = $glyph->$feature_glyph(
                    items            => $feature_layout->{'items'},
                    x_pos2           => $x2,
                    x_pos1           => $x1,
                    y_pos1           => $y1,
                    y_pos2           => $y2,
                    color            => $color,
                    is_flipped       => 0,
                    direction        => $feature->{'direction'},
                    name             => $feature->{'feature_name'},
                    app_display_data => $app_display_data,
                    feature          => $feature,
                    feature_type_acc => $feature_type_acc,
                    );

                #push @{ $feature_layout->{'items'} },
                #(
                #[   1, undef,
                #'rectangle', [ $x1, $y1, $x2, $y2 ],
                #{ -fill => 'red', }
                #]
                #);
                $feature_layout->{'changed'} = 1;
                if ( $y2 > $max_y ) {
                    $max_y = $y2;
                }
            }
        }
    }

    return $max_y;
}

# ----------------------------------------------------
sub destroy_map_for_relayout {

=pod

=head2 destroy_map_for_relayout

Destroys the drawing items for a map so it can be drawn again.

Also, destroys the features.

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $map_key          = $args{'map_key'};
    my $window_key       = $args{'window_key'};

    my $map_layout = $app_display_data->{'map_layout'}{$map_key};

    # Remove the features
    foreach my $feature_acc ( keys %{ $map_layout->{'features'} || {} } ) {
        $app_display_data->destroy_items(
            items      => $map_layout->{'features'}{$feature_acc}{'items'},
            window_key => $window_key,
        );
        $map_layout->{'features'}{$feature_acc}{'items'} = [];
    }

    # Remove the map
    $map_layout->{'bounds'} = [ 0, 0, 0, 0 ];
    $map_layout->{'coords'} = [ 0, 0, 0, 0 ];
    $app_display_data->destroy_items(
        items      => $map_layout->{'items'},
        window_key => $window_key,
    );
    $map_layout->{'items'} = [];

    return;
}

# ----------------------------------------------------
sub add_correspondences {

    #print STDERR "AL_NEEDS_MODDED 11\n";

=pod

=head2 add_correspondences

Lays out correspondences between two slots

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $window_key       = $args{'window_key'};
    my $panel_key        = $args{'panel_key'};
    my $slot_key1        = $args{'slot_key1'};
    my $slot_key2        = $args{'slot_key2'};

    ( $slot_key1, $slot_key2 ) = ( $slot_key2, $slot_key1 )
        if ( $slot_key1 > $slot_key2 );

    # Get Correspondence Data
    my $corrs = $app_display_data->app_data_module()->slot_correspondences(
        slot_key1  => $slot_key1,
        slot_key2  => $slot_key2,
        slot_info1 => $app_display_data->{'slot_info'}{$slot_key1},
        slot_info2 => $app_display_data->{'slot_info'}{$slot_key2},
    );

    if ( @{ $corrs || [] } ) {
        $app_display_data->{'corr_layout'}{'changed'} = 1;
    }

    foreach my $corr ( @{ $corrs || [] } ) {
        my $map_key1
            = $app_display_data->{'map_id_to_key_by_slot'}{$slot_key1}
            { $corr->{'map_id1'} };
        my $map_key2
            = $app_display_data->{'map_id_to_key_by_slot'}{$slot_key2}
            { $corr->{'map_id2'} };
        my $map1_x1
            = $app_display_data->{'map_layout'}{$map_key1}{'coords'}[0];
        my $map2_x1
            = $app_display_data->{'map_layout'}{$map_key2}{'coords'}[0];
        my ( $corr_y1, $corr_y2 );
        if ( $app_display_data->{'map_layout'}{$map_key1}{'coords'}[1]
            < $app_display_data->{'map_layout'}{$map_key2}{'coords'}[1] )
        {
            $corr_y1
                = $app_display_data->{'map_layout'}{$map_key1}{'coords'}[3];
            $corr_y2
                = $app_display_data->{'map_layout'}{$map_key2}{'coords'}[1];
        }
        else {
            $corr_y1
                = $app_display_data->{'map_layout'}{$map_key1}{'coords'}[1];
            $corr_y2
                = $app_display_data->{'map_layout'}{$map_key2}{'coords'}[3];
        }
        my $map1_pixels_per_unit
            = $app_display_data->{'map_pixels_per_unit'}{$map_key1}
            || $app_display_data->{'scaffold'}{$slot_key1}{'pixels_per_unit'};
        my $map2_pixels_per_unit
            = $app_display_data->{'map_pixels_per_unit'}{$map_key2}
            || $app_display_data->{'scaffold'}{$slot_key2}{'pixels_per_unit'};
        my $corr_avg_x1
            = ( $corr->{'feature_start1'} + $corr->{'feature_stop1'} ) / 2;
        my $corr_x1 = $map1_x1 + ( $map1_pixels_per_unit * $corr_avg_x1 );
        my $corr_avg_x2
            = ( $corr->{'feature_start2'} + $corr->{'feature_stop2'} ) / 2;
        my $corr_x2 = $map2_x1 + ( $map2_pixels_per_unit * $corr_avg_x2 );

        unless (
            $app_display_data->{'corr_layout'}{'maps'}{$map_key1}{$map_key2} )
        {
            $app_display_data->{'corr_layout'}{'maps'}{$map_key1}{$map_key2}
                = {
                changed   => 1,
                items     => [],
                slot_key1 => $slot_key1,
                slot_key2 => $slot_key2,
                map_key1  => $map_key1,
                map_key2  => $map_key2,
                };

            # point a reference to the corrs from each map.
            $app_display_data->{'corr_layout'}{'maps'}{$map_key2}{$map_key1}
                = $app_display_data->{'corr_layout'}{'maps'}{$map_key1}
                {$map_key2};
        }
        $app_display_data->{'corr_layout'}{'maps'}{$map_key1}{$map_key2}
            {'changed'} = 1;
        push @{ $app_display_data->{'corr_layout'}{'maps'}{$map_key1}
                {$map_key2}{'items'} },
            (
            [   1, undef, 'line',
                [ ( $corr_x1, $corr_y1 ), ( $corr_x2, $corr_y2 ), ],
                { -fill => 'red', -width => '1', }
            ]
            );
    }

    return;
}

# ----------------------------------------------------
sub _add_to_slot_info {

    #print STDERR "AL_NEEDS_MODDED 12\n";

=pod

=head2 _add_to_slot_info

Add info to slot_info needed for creation of correspondences.  This is a data
object used in CMap.

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $zone_key         = $args{'zone_key'};
    my $map_min_x        = $args{'map_min_x'};
    my $map_max_x        = $args{'map_max_x'};
    my $min_bound        = $args{'min_bound'};
    my $max_bound        = $args{'max_bound'};
    my $map_start        = $args{'map_start'};
    my $map_stop         = $args{'map_stop'};
    my $map_id           = $args{'map_id'};
    my $x_offset         = $args{'x_offset'};
    my $pixels_per_unit  = $args{'pixels_per_unit'};

    my $adjusted_map_min_x = $map_min_x + $x_offset;
    my $adjusted_map_max_x = $map_max_x + $x_offset;

    $app_display_data->{'slot_info'}{$zone_key}{$map_id}
        = [ undef, undef, $map_start, $map_stop, 1 ];
    if ( $adjusted_map_min_x < $min_bound ) {
        $app_display_data->{'slot_info'}{$zone_key}{$map_id}[0] = $map_start
            + ( ( $min_bound - $adjusted_map_min_x ) / $pixels_per_unit );
    }
    if ( $adjusted_map_max_x > $max_bound ) {
        $app_display_data->{'slot_info'}{$zone_key}{$map_id}[1] = $map_stop
            - ( ( $adjusted_map_max_x - $max_bound ) / $pixels_per_unit );
    }

    return;
}

# ----------------------------------------------------
sub _pixels_per_map_unit {

    #print STDERR "AL_NEEDS_MODDED 13\n";

=pod

=head2 _pixels_per_map_unit

returns the number of pixesl per map unit. 

=cut

    my %args             = @_;
    my $map_data_hash    = $args{'map_data_hash'};
    my $ordered_map_ids  = $args{'ordered_map_ids'} || [];
    my $zone_width       = $args{'zone_width'};
    my $zone_key         = $args{'zone_key'};
    my $stacked          = $args{'stacked'};
    my $app_display_data = $args{'app_display_data'};

    unless ( $app_display_data->{'scaffold'}{$zone_key}{'pixels_per_unit'} ) {
        my $pixels_per_unit = 1;
        if ($stacked) {

            # Layout maps on top of each other
            my $longest_length = 0;
            foreach my $map_id (@$ordered_map_ids) {
                my $map       = $map_data_hash->{$map_id};
                my $map_start = $map->{'map_start'};
                my $map_stop  = $map->{'map_stop'};
                my $length    = $map->{'map_stop'} - $map->{'map_start'};
                $longest_length = $length if ( $length > $longest_length );
            }
            $pixels_per_unit
                = ( $zone_width - ( 2 * MAP_X_BUFFER ) ) / $longest_length;
        }
        else {
            my %map_length;
            foreach my $map_id (@$ordered_map_ids) {
                my $map       = $map_data_hash->{$map_id};
                my $map_start = $map->{'map_start'};
                my $map_stop  = $map->{'map_stop'};
                $map_length{$map_id}
                    = $map->{'map_stop'} - $map->{'map_start'};
            }

            my $all_maps_fit = 0;
            my %map_is_min_length;
            while ( !$all_maps_fit ) {
                my $length_sum           = 0;
                my $scaled_map_count     = 0;
                my $min_length_map_count = 0;
                foreach my $map_id (@$ordered_map_ids) {
                    if ( $map_is_min_length{$map_id} ) {
                        $min_length_map_count++;
                        next;
                    }
                    else {
                        $scaled_map_count++;
                        $length_sum += $map_length{$map_id};
                    }
                }
                my $other_space
                    = ( 1 + scalar(@$ordered_map_ids) ) * MAP_X_BUFFER
                    + ( MIN_MAP_WIDTH * $min_length_map_count );
                $pixels_per_unit = $length_sum
                    ? ( $zone_width - $other_space ) / $length_sum
                    : 0;

                # Check this ppu to see if it makes any
                #   new maps drop below the minimum
                my $redo = 0;
                foreach my $map_id (@$ordered_map_ids) {
                    next if ( $map_is_min_length{$map_id} );
                    if ( $map_length{$map_id} * $pixels_per_unit
                        < MIN_MAP_WIDTH )
                    {
                        $redo = 1;
                        $map_is_min_length{$map_id} = 1;
                    }
                }
                unless ($redo) {
                    $all_maps_fit = 1;
                }
            }
        }
        $app_display_data->{'scaffold'}{$zone_key}{'pixels_per_unit'}
            = $pixels_per_unit;
    }

    return $app_display_data->{'scaffold'}{$zone_key}{'pixels_per_unit'};
}

# ----------------------------------------------------
sub overview_selected_area {

    #print STDERR "AL_NEEDS_MODDED 14\n";

=pod

=head2 overview_selected_area

Shows the selected region.

=cut

    my %args             = @_;
    my $slot_key         = $args{'slot_key'};
    my $panel_key        = $args{'panel_key'};
    my $app_display_data = $args{'app_display_data'};

    my $overview_layout = $app_display_data->{'overview_layout'}{$panel_key};
    my $overview_slot_layout = $overview_layout->{'slots'}{$slot_key}
        or return;
    my $main_slot_layout = $app_display_data->{'slot_layout'}{$slot_key};
    my $main_offset_x
        = $app_display_data->{'scaffold'}{$slot_key}{'x_offset'};

    my $bracket_y1 = $overview_slot_layout->{'bounds'}[1]
        - $overview_layout->{'map_buffer_y'};
    my $bracket_y2 = $overview_slot_layout->{'bounds'}[3]
        + $overview_layout->{'map_buffer_y'};
    my $scale_factor_from_main
        = $overview_slot_layout->{'scale_factor_from_main'};
    my $min_x = $main_slot_layout->{'bounds'}[0];
    my $max_x = $main_slot_layout->{'bounds'}[2];
    $min_x -= $overview_layout->{'main_pixel_offset'};
    $max_x -= $overview_layout->{'main_pixel_offset'};

    my $bracket_x1 = ( ( $min_x + $main_offset_x ) * $scale_factor_from_main )
        + $overview_layout->{'maps_min_x'};
    my $bracket_x2 = ( ( $max_x + $main_offset_x ) * $scale_factor_from_main )
        + $overview_layout->{'maps_min_x'};

    my $bracket_width = 5;

    my $use_brackets = 0;
    if ($use_brackets) {

        # Left bracket
        push @{ $overview_slot_layout->{'viewed_region'} },
            (
            [   1, undef, 'line',
                [   ( $bracket_x1 + $bracket_width, $bracket_y1 ),
                    ( $bracket_x1,                  $bracket_y1 ),
                    ( $bracket_x1,                  $bracket_y2 ),
                    ( $bracket_x1 + $bracket_width, $bracket_y2 ),
                ],
                { -fill => 'orange', -width => '3', }
            ]
            );

        # Right bracket
        push @{ $overview_slot_layout->{'viewed_region'} },
            (
            [   1, undef, 'line',
                [   ( $bracket_x2 - $bracket_width, $bracket_y1 ),
                    ( $bracket_x2,                  $bracket_y1 ),
                    ( $bracket_x2,                  $bracket_y2 ),
                    ( $bracket_x2 - $bracket_width, $bracket_y2 ),
                ],
                { -fill => 'orange', -width => '3', }
            ]
            );

        # top line
        push @{ $overview_slot_layout->{'viewed_region'} },
            (
            [   1, undef, 'line',
                [   ( $bracket_x1, $bracket_y1 ),
                    ( $bracket_x2, $bracket_y1 ),
                ],
                { -fill => 'orange', -width => '1', }
            ]
            );

        # bottom line
        push @{ $overview_slot_layout->{'viewed_region'} },
            (
            [   1, undef, 'line',
                [   ( $bracket_x1, $bracket_y2 ),
                    ( $bracket_x2, $bracket_y2 ),
                ],
                { -fill => 'orange', -width => '1', }
            ]
            );
    }
    else {

        # rectangle
        push @{ $overview_slot_layout->{'viewed_region'} }, (
            [   1, undef,
                'rectangle',
                [   ( $bracket_x1, $bracket_y1 ),
                    ( $bracket_x2, $bracket_y2 ),
                ],
                {

                    #-outline => 'orange',
                    -outline => '#ff6600',
                    -fill    => '#ffdd00',
                    -width   => '1',
                }
            ]
        );
    }
    $overview_layout->{'sub_changed'}  = 1;
    $overview_slot_layout->{'changed'} = 1;

}

# ----------------------------------------------------
sub move_zone {

    #print STDERR "AL_NEEDS_MODDED 15\n";

=pod

=head2 move_zone

Move a zone

=cut

    my %args             = @_;
    my $zone_key         = $args{'zone_key'};
    my $window_key       = $args{'window_key'};
    my $app_display_data = $args{'app_display_data'};
    my $app_interface    = $args{'app_interface'};
    my $x                = $args{'x'} || 0;
    my $y                = $args{'y'} || 0;

    my $zone_layout = $app_display_data->{'zone_layout'}{$zone_key};

    foreach my $drawing_item_name (qw[ separator background ]) {
        move_drawing_items(
            window_key    => $window_key,
            items         => $zone_layout->{$drawing_item_name},
            app_interface => $app_interface,
            y             => $y,
            x             => $x,
        );
    }
    foreach
        my $map_key ( @{ $app_display_data->{'map_order'}{$zone_key} || [] } )
    {
        move_map(
            app_display_data => $app_display_data,
            app_interface    => $app_interface,
            map_key          => $map_key,
            zone_key         => $map_key,
            window_key       => $window_key,
            x                => $x,
            y                => $y,
        );
    }

    # BF DOES THIS NEED TO HAPPEN?
    # zone_controls need to be renamed
    #    $app_interface->destroy_zone_controls(
    #        window_key => $window_key,
    #        zone_key  => $zone_key,
    #    );
    #    $app_interface->add_zone_controls(
    #        zone_key         => $zone_key,
    #        window_key       => $window_key,
    #        app_display_data => $app_display_data,
    #    );

    $zone_layout->{'changed'}     = 1;
    $zone_layout->{'sub_changed'} = 1;
}

# ----------------------------------------------------
sub move_map {

    #print STDERR "AL_NEEDS_MODDED 16\n";

=pod

=head2 move_map

Move a map

=cut

    my %args             = @_;
    my $map_key          = $args{'map_key'};
    my $zone_key         = $args{'map_key'};
    my $window_key       = $args{'window_key'};
    my $app_display_data = $args{'app_display_data'};
    my $app_interface    = $args{'app_interface'};
    my $x                = $args{'x'} || 0;
    my $y                = $args{'y'} || 0;

    my $map_layout = $app_display_data->{'map_layout'}{$map_key};

    move_drawing_items(
        window_key    => $window_key,
        items         => $map_layout->{'items'},
        app_interface => $app_interface,
        y             => $y,
        x             => $x,
    );

    # Move features
    foreach my $feature_acc ( keys %{ $map_layout->{'features'} || {} } ) {
        move_drawing_items(
            window_key    => $window_key,
            items         => $map_layout->{'features'}{$feature_acc}{'items'},
            app_interface => $app_interface,
            y             => $y,
            x             => $x,
        );
    }

    # Crawl down the tree
    foreach my $child_zone_key (
        @{ $app_display_data->{'scaffold'}{$zone_key}{'children'} || [] } )
    {
        next
            unless (
            $map_key == $app_display_data->{'scaffold'}{$child_zone_key}
            {'parent_map_key'} );
        move_zone(
            zone_key         => $child_zone_key,
            window_key       => $window_key,
            app_display_data => $app_display_data,
            app_interface    => $app_interface,
            x                => $x,
            y                => $y,
        );
    }
}

# ----------------------------------------------------
sub move_drawing_items {

    #print STDERR "AL_NEEDS_MODDED 17\n";

=pod

=head2 move_drawing_items

Move drawing_items 

=cut

    my %args          = @_;
    my $window_key    = $args{'window_key'};
    my $app_interface = $args{'app_interface'};
    my $items         = $args{'items'} or return;
    my $x             = $args{'x'} || 0;
    my $y             = $args{'y'} || 0;

    foreach my $item ( @{ $items || [] } ) {
        for ( my $i = 0; $i <= $#{ $item->[3] || [] }; $i = $i + 2 ) {
            $item->[3][$i]       += $x;
            $item->[3][ $i + 1 ] += $y;
        }
    }
    $app_interface->move_items(
        window_key => $window_key,
        items      => $items,
        y          => $y,
        x          => $x,
    );
}

# ----------------------------------------------------
sub _map_shape_sub_ref {

    #print STDERR "AL_NEEDS_MODDED 17\n";

=pod

=head2 _map_shape_sub_ref

return a reference to the map shape subroutine

=cut

    my %args       = @_;
    my $map_layout = $args{'map_layout'};
    my $map        = $args{'map'};

    unless ( $map_layout->{'shape_sub_ref'} ) {
        if ($map) {
            $map_layout->{'shape_sub_ref'} = $SHAPE{ $map->{'shape'} }
                || $SHAPE{ $map->{'default_shape'} }
                || $SHAPE{'default'};
        }
        else {
            print STDERR
                "WARNING: Map shape not found and not map provided\n";
            return $SHAPE{'default'};
        }
    }

    return $map_layout->{'shape_sub_ref'};
}

# ----------------------------------------------------
sub _tick_mark_interval {

    #print STDERR "AL_NEEDS_MODDED 18\n";

=pod

=head2 _tick_mark_interval

This method was copied out of Bio::GMOD::CMap::Drawer::Map but it has diverged
slightly.

Returns the map's tick mark interval.

=cut

    my $visible_map_units = shift;

    # If map length == 0, set scale to 1
    # Contributed by David Shibeci
    if ($visible_map_units) {
        my $map_scale = int( log( abs($visible_map_units) ) / log(10) );
        return ( 10**( $map_scale - 1 ), $map_scale );
    }
    else {

        # default tick_mark_interval for maps of length 0
        return ( 1, 1 );
    }

}

# ----------------------------------------------------
sub _add_tick_marks {

    #print STDERR "AL_NEEDS_MODDED 19\n";

=pod

=head2 _add_tick_marks

Adds tick marks to a map.

=cut

    my %args             = @_;
    my $map              = $args{'map'};
    my $map_layout       = $args{'map_layout'};
    my $zone_key         = $args{'zone_key'};
    my $label_x          = $args{'label_x'};
    my $label_y          = $args{'label_y'};
    my $map_coords       = $args{'map_coords'};
    my $app_display_data = $args{'app_display_data'};

    my $map_key = $app_display_data->{'map_id_to_key_by_zone'}{$zone_key}
        { $map->{'map_id'} };
    my $pixels_per_unit = $app_display_data->{'map_pixels_per_unit'}{$map_key}
        || $app_display_data->{'scaffold'}{$zone_key}{'pixels_per_unit'};

    my $visible_map_start
        = $app_display_data->{'slot_info'}{$zone_key}{ $map->{'map_id'} }[0];
    unless ( defined $visible_map_start ) {
        $visible_map_start
            = $app_display_data->{'slot_info'}{$zone_key}{ $map->{'map_id'} }
            [2];
    }

    my $visible_pixel_start = $map_coords->[0];

    # BF REMOVED THE COMPLICATED STUFF SINCE COORDS WILL HAVE THE FIRST PIXEL
    #+ (
    #(   $visible_map_start - $app_display_data->{'slot_info'}{$zone_key}
    #{ $map->{'map_id'} }[2]
    #) * $pixels_per_unit
    #);

    my $visible_map_stop
        = $app_display_data->{'slot_info'}{$zone_key}{ $map->{'map_id'} }[1];
    unless ( defined $visible_map_stop ) {
        $visible_map_stop
            = $app_display_data->{'slot_info'}{$zone_key}{ $map->{'map_id'} }
            [3];
    }
    my $visible_pixel_stop = $map_coords->[2];

    # BF REMOVED THE COMPLICATED STUFF SINCE COORDS WILL HAVE THE LAST PIXEL
    #- (
    #(   $app_display_data->{'slot_info'}{$zone_key}{ $map->{'map_id'} }[3]
    #- $visible_map_stop
    #) * $pixels_per_unit
    #);

    my $visible_map_units = $visible_map_stop - $visible_map_start;
    my ( $interval, $map_scale ) = _tick_mark_interval( $visible_map_units, );

    my $no_intervals = int( $visible_map_units / $interval );
    my $interval_start
        = int( $visible_map_start / ( 10**( $map_scale - 1 ) ) )
        * ( 10**( $map_scale - 1 ) );
    my $tick_overhang = 8;
    my @intervals     =
        map { int( $interval_start + ( $_ * $interval ) ) }
        1 .. $no_intervals;
    my $min_tick_distance
        = $app_display_data->config_data('min_tick_distance') || 40;
    my $last_tick_rel_pos = undef;

    my $visible_pixel_width = $visible_pixel_stop - $visible_pixel_start + 1;
    my $tick_start          = $map_coords->[1] - $tick_overhang;
    my $tick_stop           = $map_coords->[3];
    for my $tick_pos (@intervals) {
        my $rel_position
            = ( $tick_pos - $visible_map_start ) / $visible_map_units;

        # If there isn't enough space, skip this one.
        if (( ( $rel_position * $visible_pixel_width ) < $min_tick_distance )
            or (defined($last_tick_rel_pos)
                and ( ( $rel_position * $visible_pixel_width )
                    - ( $last_tick_rel_pos * $visible_pixel_width )
                    < $min_tick_distance )
            )
            )
        {
            next;
        }

        $last_tick_rel_pos = $rel_position;

        my $x_pos
            = $visible_pixel_start + ( $visible_pixel_width * $rel_position );

        push @{ $map_layout->{'items'} },
            (
            [   1, undef, 'line',
                [ $x_pos, $tick_start, $x_pos, $tick_stop, ],
                { -fill => 'black', }
            ]
            );

        #
        # Figure out how many signifigant figures the number needs by
        # going down to the $interval size.
        #
        my $sig_figs = $tick_pos
            ? int( '' . ( log( abs($tick_pos) ) / log(10) ) ) -
            int( '' . ( log( abs($interval) ) / log(10) ) ) + 1
            : 1;
        my $tick_pos_str = presentable_number( $tick_pos, $sig_figs );
        my $label_x = $x_pos;  #+ ( $font_width * length($tick_pos_str) ) / 2;

        push @{ $map_layout->{'items'} },
            (
            [   1, undef, 'text',
                [ $label_x, $label_y ],
                {   -text   => $tick_pos_str,
                    -anchor => 'nw',
                    -fill   => 'black',
                }
            ]
            );
    }
}

# ----------------------------------------------------
sub _draw_box {

    #print STDERR "AL_NEEDS_MODDED 20\n";

=pod

=head2 _draw_box

Draws the map as a "box" (a filled-in rectangle).  Return the bounds of the
box.

=cut

    my %args        = @_;
    my $map_layout  = $args{'map_layout'};
    my $min_x       = $args{'min_x'};
    my $min_y       = $args{'min_y'};
    my $max_x       = $args{'max_x'};
    my $viewable_x1 = $args{'viewable_x1'};
    $viewable_x1 = $min_x unless ( defined $viewable_x1 );
    my $viewable_x2 = $args{'viewable_x2'};
    $viewable_x2 = $max_x unless ( defined $viewable_x2 );
    my $color            = $args{'color'};
    my $thickness        = $args{'thickness'};
    my $truncated        = $args{'truncated'} || 0;
    my $app_display_data = $args{'app_display_data'};

    my $max_y  = $min_y + $thickness;
    my $mid_y  = int( 0.5 + ( $min_y + $max_y ) / 2 );
    my @bounds = ( $min_x, $min_y, $max_x, $max_y );
    my ( $left_side_unseen, $right_side_unseen ) = ( 0, 0 );
    if ( $viewable_x1 > $min_x ) {
        $min_x            = $viewable_x1;
        $left_side_unseen = 0;
    }
    if ( $viewable_x2 < $max_x ) {
        $max_x             = $viewable_x2;
        $right_side_unseen = 0;
    }
    my @coords                 = ( $min_x, $min_y, $max_x, $max_y );
    my $truncation_arrow_width = 20;
    my $is_flipped             = 0;

    my ( $main_line_x1, $main_line_y1, $main_line_x2, $main_line_y2, )
        = ( $min_x, $min_y, $max_x, $max_y, );

    # Left Truncation Arrow
    if ((      $truncated == 3
            or ( $truncated >= 2 and $is_flipped )
            or ( $truncated == 1 and not $is_flipped )
        )
        and not $left_side_unseen
        )
    {
        push @{ $map_layout->{'items'} }, (
            [   1, undef,
                'polygon',
                [   $min_x, $mid_y, $min_x + $truncation_arrow_width,
                    $max_y + 3, $min_x + $truncation_arrow_width,
                    $min_y - 3,
                ],
                { -fill => $color, -outline => 'black' }

                #{ -fill => 'green', -outline => 'black' }
            ]
        );
        $main_line_x1 += $truncation_arrow_width;
    }

    # Right Truncation Arrow
    if ((      $truncated == 3
            or ( $truncated >= 2 and not $is_flipped )
            or ( $truncated == 1 and $is_flipped )
        )
        and not $right_side_unseen
        )
    {
        push @{ $map_layout->{'items'} }, (
            [   1, undef,
                'polygon',
                [   $max_x, $mid_y, $max_x - $truncation_arrow_width,
                    $max_y + 3, $max_x - $truncation_arrow_width,
                    $min_y - 3,
                ],

                #{ -fill => $color, -outline => 'black' }
                { -fill => 'red', -outline => 'black' }
            ]
        );
        $main_line_x2 -= $truncation_arrow_width;
    }

    # Draw the map
    push @{ $map_layout->{'items'} },
        (
        [   1,
            undef,
            'rectangle',
            [ $main_line_x1, $main_line_y1, $main_line_x2, $main_line_y2 ],
            { -fill => $color, -outline => $color, }
        ]
        );

    return ( \@bounds, \@coords );
}

# ----------------------------------------------------
sub _draw_dumbbell {

    #print STDERR "AL_NEEDS_MODDED 21\n";

=pod

=head2 _draw_dumbbell

Draws the map as a "dumbbell" (a filled-in rectangle with balls at the end).
Return the bounds of the map.

=cut

    my %args        = @_;
    my $map_layout  = $args{'map_layout'};
    my $min_x       = $args{'min_x'};
    my $min_y       = $args{'min_y'};
    my $max_x       = $args{'max_x'};
    my $viewable_x1 = $args{'viewable_x1'};
    $viewable_x1 = $min_x unless ( defined $viewable_x1 );
    my $viewable_x2 = $args{'viewable_x2'};
    $viewable_x2 = $max_x unless ( defined $viewable_x2 );
    my $color            = $args{'color'};
    my $thickness        = $args{'thickness'};
    my $truncated        = $args{'truncated'} || 0;
    my $app_display_data = $args{'app_display_data'};

    my $circle_diameter = $thickness;
    my $max_y           = $min_y + $thickness;
    my $mid_y           = int( 0.5 + ( $min_y + $max_y ) / 2 );
    my @bounds          = ( $min_x, $min_y, $max_x, $max_y );
    my ( $left_side_unseen, $right_side_unseen ) = ( 0, 0 );
    if ( $viewable_x1 > $min_x ) {
        $min_x            = $viewable_x1;
        $left_side_unseen = 0;
    }
    if ( $viewable_x2 < $max_x ) {
        $max_x             = $viewable_x2;
        $right_side_unseen = 0;
    }
    my @coords     = ( $min_x, $min_y, $max_x, $max_y );
    my $is_flipped = 0;

    my ( $main_line_x1, $main_line_y1, $main_line_x2, $main_line_y2, )
        = ( $min_x, $min_y, $max_x, $max_y, );

    # Draw Left Circle if not tuncated
    if (not $left_side_unseen
        and not( $truncated == 3
            or ( $truncated >= 2 and $is_flipped )
            or ( $truncated == 1 and not $is_flipped ) )
        )
    {
        push @{ $map_layout->{'items'} },
            (
            [   1, undef, 'oval',
                [ $min_x, $min_y, $min_x + $circle_diameter, $max_y, ],
                { -fill => $color, -outline => $color }
            ]
            );
    }

    # Draw Right Circle
    if (not $right_side_unseen
        and not( $truncated == 3
            or ( $truncated >= 2 and not $is_flipped )
            or ( $truncated == 1 and $is_flipped ) )
        )
    {
        push @{ $map_layout->{'items'} },
            (
            [   1, undef, 'oval',
                [ $max_x - $circle_diameter, $min_y, $max_x, $max_y, ],
                { -fill => $color, -outline => $color }
            ]
            );
    }

    $main_line_y1 += int( $thickness / 3 );
    $main_line_y2 -= int( $thickness / 3 );

    # Draw the map
    push @{ $map_layout->{'items'} },
        (
        [   1, undef, 'rectangle',
            [ $main_line_x1, $main_line_y1, $main_line_x2, $main_line_y2 ],
            { -fill => $color, -outline => $color }
        ]
        );

    return ( \@bounds, \@coords );
}

# ----------------------------------------------------
sub _draw_i_beam {

    #print STDERR "AL_NEEDS_MODDED 22\n";

=pod

=head2 _draw_i_beam

Draws the map as an "i_beam" (a line with cross lines on the end).  Return the
bounds of the map.

=cut

    my %args             = @_;
    my $map_layout       = $args{'map_layout'};
    my $min_x            = $args{'min_x'};
    my $min_y            = $args{'min_y'};
    my $max_x            = $args{'max_x'};
    my $color            = $args{'color'};
    my $thickness        = $args{'thickness'};
    my $truncated        = $args{'truncated'} || 0;
    my $app_display_data = $args{'app_display_data'};
    my $is_flipped       = 0;

    my $max_y       = $min_y + $thickness;
    my $mid_y       = int( 0.5 + ( $min_y + $max_y ) / 2 );
    my $viewable_x1 = $args{'viewable_x1'};
    $viewable_x1 = $min_x unless ( defined $viewable_x1 );
    my $viewable_x2 = $args{'viewable_x2'};
    $viewable_x2 = $max_x unless ( defined $viewable_x2 );
    my @bounds = ( $min_x, $min_y, $max_x, $max_y );
    my ( $left_side_unseen, $right_side_unseen ) = ( 0, 0 );

    if ( $viewable_x1 > $min_x ) {
        $min_x            = $viewable_x1;
        $left_side_unseen = 0;
    }
    if ( $viewable_x2 < $max_x ) {
        $max_x             = $viewable_x2;
        $right_side_unseen = 0;
    }
    my @coords = ( $min_x, $min_y, $max_x, $max_y );

    my ( $main_line_x1, $main_line_y1, $main_line_x2, $main_line_y2, )
        = ( $min_x, $mid_y, $max_x, $mid_y, );

    # Draw Left Bar
    if (not $left_side_unseen
        and not( $truncated == 3
            or ( $truncated >= 2 and $is_flipped )
            or ( $truncated == 1 and not $is_flipped ) )
        )
    {
        push @{ $map_layout->{'items'} },
            (
            [   1, undef, 'line',
                [ $min_x, $min_y, $min_x, $max_y, ],
                { -fill => $color, }
            ]
            );
    }

    # Draw Right Circle
    if (not $right_side_unseen
        and not( $truncated == 3
            or ( $truncated >= 2 and not $is_flipped )
            or ( $truncated == 1 and $is_flipped ) )
        )
    {
        push @{ $map_layout->{'items'} },
            (
            [   1, undef, 'line',
                [ $max_x, $min_y, $max_x, $max_y, ],
                { -fill => $color, }
            ]
            );
    }

    # Draw the map
    push @{ $map_layout->{'items'} },
        (
        [   1, undef, 'line',
            [ $main_line_x1, $main_line_y1, $main_line_x2, $main_line_y2 ],
            { -fill => $color, }
        ]
        );

    return ( \@bounds, \@coords );
}

1;

# ----------------------------------------------------
# I have never yet met a man who was quite awake.
# How could I have looked him in the face?
# Henry David Thoreau
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

