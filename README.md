# peak_bagger

A new Flutter project.

## PeakBagger sync

Run the PeakBagger CSV sync from the repo root:

```bash
./sync_peakbagger_csv.sh
```

Optional unmatched-peak creation:

```bash
./sync_peakbagger_csv.sh --create-unmatched-peaks
```

You can also target a different CSV file by passing its path as the first argument.
It preserves `peak-bagger-peak-data.csv`, refreshes `peak-bagger-peak-data-lat-lon.csv`, and writes the review output to `peak-bagger-peak-data-processed.csv`.
The cached CSV is the reusable lookup file and only carries the coordinate fields needed for later runs. The processed CSV adds `note`, `osmId`, and `safeToCreate`. In the current review mode, the sync reads ObjectBox for matching but does not modify ObjectBox.

If the native ObjectBox library is missing, install it first with the ObjectBox `install.sh` helper so `lib/libobjectbox.dylib` exists.
