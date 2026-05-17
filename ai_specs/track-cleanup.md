# Superfluous track file cleanup
Cleans up unecessary files.

There are files named "Selected Track_xxx.gpx" and "Correlated Track_yyy.gpx" in the Tasmania directory, which were intended to re-open, re-scan, repair, and delete tracks reliably later. However, the source file is moved unchanged apart from filename normalisation so that should be sufficient for the above operations.

-  Remove managedRelativePath from GpxTrack if nothing reads it.
-  confirm whether managedPlacementPending is needed in the import lifecycle.
-  Update the import/placement code to rely only on the actual on-disk filename/path.
-  Remove the field from persistence/schema and adjust any generated ObjectBox code.
-  Update tests that assert import metadata or model round-trips.
-  remove the code for  "Selected Track_xxx.gpx" and "Correlated Track_yyy.gpx" if it is superfluous or explainwhy it is needed.
