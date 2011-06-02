# Creates a Makefile that is capable of building all executable targets.
#
# To build on Linux:
#  ./gyp_skia && make all
#
# Building on other platforms not tested yet.
#
{
  'targets': [
    {
      'target_name': 'all',
      'type': 'none',
      'dependencies': [
        'gm.gyp:gm',
        'SampleApp.gyp:SampleApp',
        'tests.gyp:tests',
        'tools.gyp:tools',
      ],
    },
  ],
}

# Local Variables:
# tab-width:2
# indent-tabs-mode:nil
# End:
# vim: set expandtab tabstop=2 shiftwidth=2:
