#!/bin/sh

set -o errexit -o nounset

mkdir -p db
sqlite3 db/lis.db < sql/cmap.create.sqlite
cmap_admin.pl -d LIS --no-log --action import_object_data data/species.xml
cmap_admin.pl -d LIS --no-log --action import_object_data data/xref.xml

# Files generated from cmap_admin.pl --action export_as_text ...
for map_set in data/*.dat
do
  stem=$(basename ${map_set} .dat)
  species_acc=${stem%%-*}
  map_set_acc=${stem#*-}

  # keep list of map set accessions for when generating correspondences
  map_set_accs="${map_set_accs:-}${map_set_accs:+ }$map_set_acc"

  cmap_admin.pl --datasource LIS \
                --no-log \
                --action create_map_set \
                --species_acc ${species_acc} \
                --map_set_acc ${map_set_acc} \
                --map_set_name ${map_set_acc} \
                --map_type_acc genetic \
                ${map_set};

  cmap_admin.pl --datasource LIS \
                --no-log \
                --action import_tab_data \
                --species_acc ${species_acc} \
                --map_set_acc ${map_set_acc} \
                ${map_set}
done

# Create name-based correspondences between all map sets
cmap_admin.pl --action make_name_correspondences \
              --evidence_type_acc ANB \
              --from_map_set_accs "${map_set_accs}" \
              --datasource LIS \
              --no-log
# "ANALYZE" seems to be important for performance when rendering correspondences
# -- it may allows SQLite to intelligently choose which indexes to use in with
# the cmap_coorespondence_lookup table; otherwise it hangs when
# "cmap_correspondence_lookup.map_id1 = ..." is added to a query that CMap does
# to display correspondences.
sqlite3 db/lis.db 'ANALYZE'
