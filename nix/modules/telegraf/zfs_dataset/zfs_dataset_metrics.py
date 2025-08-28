#!/usr/bin/python3
from influxdb_client import Point
import argparse
import logging
import sys
import time
from datetime import datetime
import libzfs

# Add missing property converters
libzfs.ZFS_PROPERTY_CONVERTERS.update({
    "snapshots_changed": libzfs.ZfsConverter(datetime, readonly=True, nullable=True, read_null=''),
    "createtxg": libzfs.ZfsConverter(int, readonly=True),
    "objsetid": libzfs.ZfsConverter(int, readonly=True),
    "createtxg": libzfs.ZfsConverter(int, readonly=True),
    "inconsistent": libzfs.ZfsConverter(bool, no="0", yes="1", readonly=True),
    "redacted": libzfs.ZfsConverter(bool, no="0", yes="1", readonly=True),
})

TAG_PROPS = {
    "type",
    "encryptionroot",
    "encryption",
    "compression",
    "dedup",
    "guid",
    "ivsetguid",
    "keyguid",
    "objsetid",
    "origin",
    "redacted",
    "mountpoint",
    "primarycache",
    "secondarycache",
}
VALUE_PROPS = {
    # compute: "compressratio"
    # compute: "refcompressratio"
    "inconsistent", # incomplete receive
    # Indicates if an encryption key is currently loaded into ZFS. The possible values are none, available, and unavailable.
    "keystatus",
    # Specifies the time at which a snapshot for a dataset was last created or deleted.
    "snapshots_changed",
    # The amount of space available to the dataset and all its children, assuming that there is no other activity in the pool.
    "available",
    # The amount of space that is "logically" accessible by this dataset. See the referenced property. The logical space ignores the effect of the compression and copies properties, giving a quantity closer to the amount of data that applications see. However, it does include space consumed by metadata.
    "logicalreferenced",
    # The amount of space that is "logically" consumed by this dataset and all its descendants. See the used property. The logical space ignores the effect of the compression and copies properties, giving a quantity closer to the amount of data that applications see. However, it does include space consumed by metadata.
    "logicalused",
    "mounted",
    # The amount of data that is accessible by this dataset, which may or may not be shared with other datasets in the pool.
    "referenced",
    # The amount of space consumed by this dataset and all its descendants. This is the value that is checked against this dataset's quota and reservation. The space used does not include this dataset's reservation, but does take into account the reservations of any descendent datasets. The amount of space that a dataset consumes from its parent, as well as the amount of space that is freed if this dataset is recursively destroyed, is the greater of its space used and its reservation.
    "used",
    # The amount of space used by children of this dataset, which would be freed if all the dataset's children were destroyed.
    "usedbychildren",
    # The amount of space used by this dataset itself, which would be freed if the dataset were destroyed (after first removing any refreservation and destroying any necessary snapshots or descendants).
    "usedbydataset",
    # The amount of space used by a refreservation set on this dataset, which would be freed if the refreservation was removed.
    "usedbyrefreservation",
    # The amount of space consumed by snapshots of this dataset. In particular, it is the amount of space that would be freed if all of this dataset's snapshots were destroyed. Note that this is not simply the sum of the snapshots' used properties because space can be shared by multiple snapshots.
    "usedbysnapshots",
    # The amount of space referenced by this dataset, that was written since the previous snapshot (i.e. that is not referenced by the previous snapshot).
    "written",
    "quota",
    "refquota",
    # Specifies a suggested block size for files in the file system
    "recordsize",
    # The minimum amount of space guaranteed to a dataset, not including its descendants.
    "refreservation",
    # The minimum amount of space guaranteed to a dataset and its descendants.
    "reservation",
    # The on-disk version of this file system, which is independent of the pool version.
    "version",
    # volumes
    "volblocksize",
    "volsize",
}

EMPTY = ("", None)

def main():
    parser = argparse.ArgumentParser(description='Extract ZFS dataset metrics.')
    parser.add_argument('--verbose', action='store_true')

    args = parser.parse_args()

    logging.basicConfig(level=logging.NOTSET if args.verbose else logging.INFO)

    zfs = libzfs.ZFS()

    for line in sys.stdin:
        t = time.time_ns()
        for ds in zfs.datasets:
            logging.debug("Found dataset %s", ds)
            p = (Point("zfs_resource")
                 .tag("name", ds.name)
                 .tag("pool", ds.pool.name)
                 .time(t))
            props = ds.properties
            for key in TAG_PROPS:
                if key in props:
                    value = props[key].parsed
                    if value not in EMPTY:
                        p = p.tag(key, str(value))
            for key in VALUE_PROPS:
                if key in props:
                    value = props[key].parsed
                    if isinstance(value, datetime):
                        value = value.timestamp()
                    if value not in EMPTY:
                        p = p.field(key, value)
            print(p.to_line_protocol())
        sys.stdout.flush()

if __name__ == "__main__":
    main()
