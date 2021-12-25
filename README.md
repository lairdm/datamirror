# datamirror

## Background

This script has evolved in bursts over the paste 20 years as my home data storage setup changed. This step is a complete rewrite to add some additional flexibility. I'm sure there's ways this could be greatly improved, but it works for my purposes.

The primary goal has always been to rsync a set of directories to a portable hard drive I could swap. Because most of the portable hard drives were smaller than the original sources I needed a way to selectively mirror subsets of data.

## Usage

    scripts/backup.sh [/path/to/configs] [false]

Both parameters are optional, the first is the path to the directory containing the `conf` and `paths` directories. The second is `true/false` on if the backup directory should be unmounted when finished (defaults to false).

## Configuration

`conf/settings` contains the source and destination rsync paths.

`paths` is a directory of path suffixes in the source path to rsync. They're zero size files that just say which paths in source to rsync to destination.

`paths/suffix.exclude` rsync patterns to exclude

`paths/suffix.path` to override the source prefix for a particular directory
