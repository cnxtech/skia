#!/bin/bash

# Tests for our tools.
#
# TODO: currently, this only passes on Linux (which is the platform that
# the housekeeper bot runs on, e.g.
# http://70.32.156.51:10117/builders/Skia_PerCommit_House_Keeping/builds/1415/steps/RunToolSelfTests/logs/stdio )
# See https://code.google.com/p/skia/issues/detail?id=677
# ('make tools/tests/run.sh work cross-platform')
# Ideally, these tests should pass on all development platforms...
# otherwise, how can developers be expected to test them before committing a
# change?

# cd into .../trunk so all the paths will work
cd $(dirname $0)/../..

# TODO: make it look in Release and/or Debug
SKDIFF_BINARY=out/Debug/skdiff

# Suffixes of all the raw bench data files we want to process.
BENCHDATA_FILE_SUFFIXES=\
"data_skp_device_bitmap_multi_2_mode_tile_256_256_timeIndividualTiles "\
"data_skp_device_bitmap_multi_3_mode_tile_256_256_timeIndividualTiles "\
"data_skp_device_bitmap_multi_4_mode_tile_256_256_timeIndividualTiles "\
"data_skp_device_bitmap_mode_record_bbh_rtree"

# Compare contents of all files within directories $1 and $2,
# EXCEPT for any dotfiles.
# If there are any differences, a description is written to stdout and
# we exit with a nonzero return value.
# Otherwise, we write nothing to stdout and return.
function compare_directories {
  if [ $# != 2 ]; then
    echo "compare_directories requires exactly 2 parameters, got $#"
    exit 1
  fi
  diff --exclude=.* $1 $2
  if [ $? != 0 ]; then
    echo "failed in: compare_directories $1 $2"
    exit 1
  fi
}

# Run skdiff with arguments in $1 (plus implicit final argument causing skdiff
# to write its output, if any, to directory $2/output-actual).
# Then compare its results against those in $2/output-expected.
function skdiff_test {
  if [ $# != 2 ]; then
    echo "skdiff_test requires exactly 2 parameters, got $#"
    exit 1
  fi
  SKDIFF_ARGS="$1"
  ACTUAL_OUTPUT_DIR="$2/output-actual"
  EXPECTED_OUTPUT_DIR="$2/output-expected"

  rm -rf $ACTUAL_OUTPUT_DIR
  mkdir -p $ACTUAL_OUTPUT_DIR
  COMMAND="$SKDIFF_BINARY $SKDIFF_ARGS $ACTUAL_OUTPUT_DIR"
  echo "$COMMAND" >$ACTUAL_OUTPUT_DIR/command_line
  $COMMAND &>$ACTUAL_OUTPUT_DIR/stdout
  echo $? >$ACTUAL_OUTPUT_DIR/return_value

  compare_directories $EXPECTED_OUTPUT_DIR $ACTUAL_OUTPUT_DIR
}

SKDIFF_TESTDIR=tools/tests/skdiff

# Run skdiff over a variety of file pair types: identical bits, identical pixels, missing from
# baseDir, etc.
skdiff_test "$SKDIFF_TESTDIR/baseDir $SKDIFF_TESTDIR/comparisonDir" "$SKDIFF_TESTDIR/test1"

# Run skdiff over the same set of files, but with arguments as used by our buildbots:
# - return the number of mismatching file pairs (but ignore any files missing from either
#   baseDir or comparisonDir)
# - list filenames with each result type to stdout
# - don't generate HTML output files
skdiff_test "--failonresult DifferentPixels --failonresult DifferentSizes --failonresult Unknown --failonstatus CouldNotDecode,CouldNotRead any --failonstatus any CouldNotDecode,CouldNotRead --listfilenames --nodiffs $SKDIFF_TESTDIR/baseDir $SKDIFF_TESTDIR/comparisonDir" "$SKDIFF_TESTDIR/test2"

# Run skdiff over just the files that have identical bits.
skdiff_test "--nodiffs --match identical-bits $SKDIFF_TESTDIR/baseDir $SKDIFF_TESTDIR/comparisonDir" "$SKDIFF_TESTDIR/identical-bits"

# Run skdiff over just the files that have identical bits or identical pixels.
skdiff_test "--nodiffs --match identical-bits --match identical-pixels $SKDIFF_TESTDIR/baseDir $SKDIFF_TESTDIR/comparisonDir" "$SKDIFF_TESTDIR/identical-bits-or-pixels"


# Download a subset of the raw bench data for platform $1 at revision $2.
# If any of those files already exist locally, we assume that they are
# correct and up to date, and we don't download them again.
function benchgraph_download_rawdata {
  if [ $# != 2 ]; then
    echo "benchgraph_download_rawdata requires exactly 2 parameters, got $#"
    exit 1
  fi
  PLATFORM="$1"
  REV="$2"

  PLATFORM_DIR="tools/tests/benchgraphs/$PLATFORM"
  RAW_BENCH_DATA_DIR="$PLATFORM_DIR/raw-bench-data"
  mkdir -p $RAW_BENCH_DATA_DIR

  for FILE_SUFFIX in $BENCHDATA_FILE_SUFFIXES; do
    FILE=bench_r${REV}_${FILE_SUFFIX}
    DESTFILE=$RAW_BENCH_DATA_DIR/$FILE
    if [ ! -f $DESTFILE ];
    then
      URL=http://chromium-skia-gm.commondatastorage.googleapis.com/playback/perfdata/${PLATFORM}/data/${FILE}
      echo Downloading $URL ...
      curl $URL --output $DESTFILE
    fi
  done
}

# Run bench_graph_svg.py across the data from platform $1,
# writing its output to output-actual and comparing those results against
# output-expected.
function benchgraph_test {
  if [ $# != 1 ]; then
    echo "benchgraph_test requires exactly 1 parameter, got $#"
    exit 1
  fi
  PLATFORM="$1"

  PLATFORM_DIR="tools/tests/benchgraphs/$PLATFORM"
  RAW_BENCH_DATA_DIR="$PLATFORM_DIR/raw-bench-data"
  ACTUAL_OUTPUT_DIR="$PLATFORM_DIR/output-actual"
  EXPECTED_OUTPUT_DIR="$PLATFORM_DIR/output-expected"

  # Run bench_graph_svg.py .
  rm -rf $ACTUAL_OUTPUT_DIR
  mkdir -p $ACTUAL_OUTPUT_DIR
  COMMAND="python bench/bench_graph_svg.py -d $RAW_BENCH_DATA_DIR -r -150 -f -150 -x 1024 -y 768 -l Title -m 25th -o $ACTUAL_OUTPUT_DIR/graph.xhtml"
  echo "$COMMAND" >$ACTUAL_OUTPUT_DIR/command_line
  START_TIMESTAMP=$(date +%s)
  $COMMAND &>$ACTUAL_OUTPUT_DIR/stdout
  echo $? >$ACTUAL_OUTPUT_DIR/return_value
  END_TIMESTAMP=$(date +%s)

  SECONDS_RUN=$(expr $END_TIMESTAMP - $START_TIMESTAMP)
  echo "bench_graph_svg.py for $PLATFORM took $SECONDS_RUN seconds to complete"

  compare_directories $EXPECTED_OUTPUT_DIR $ACTUAL_OUTPUT_DIR
}

# Parse a collection of bench data leading up to
# http://70.32.156.53:10117/builders/Skia_Shuttle_Ubuntu12_ATI5770_Float_Bench_32/builds/878/steps/GenerateWebpagePictureBenchGraphs/logs/stdio
# (this was during the period when the bench data included a ton of per-tile,
# per-iteration data)
PLATFORM=Skia_Shuttle_Ubuntu12_ATI5770_Float_Bench_32
benchgraph_download_rawdata $PLATFORM 7671
benchgraph_download_rawdata $PLATFORM 7679
benchgraph_download_rawdata $PLATFORM 7686
benchgraph_test $PLATFORM

echo "All tests passed."
