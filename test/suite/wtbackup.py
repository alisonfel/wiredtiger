#!/usr/bin/env python
#
# Public Domain 2014-2021 MongoDB, Inc.
# Public Domain 2008-2014 WiredTiger, Inc.
#
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
import os
import wttest
from suite_subprocess import suite_subprocess
from helper import compare_files

# Shared base class used by backup tests.
class backup_base(wttest.WiredTigerTestCase, suite_subprocess):
    #
    # Add data to the given uri.
    # options:
    #   cursor_options: a config string for cursors
    #   num_ops: number of operations added to uri
    #   mult: counter to have variance in data
    #   counter: a counter to used to produce unique backup ids
    #   session_checkpoint: boolean in which enables session checkpoints after adding data
    #   initial_backup: To determine whether to increase/decrease counter, which determines
    #           the backup id, and is generally used only for using add_data() first time.
    #
    def add_data(self, uri, key, val, options):
        c = self.session.open_cursor(uri, None, options.get('cursor_options'))
        nops = options.get('num_ops', 100)
        mult = options.get('mult', 0)
        for i in range(0, nops):
            num = i + (mult * nops)
            k = key + str(num)
            v = val + str(num)
            c[k] = v
        c.close()
        # Increase the counter so that later backups have unique ids.
        counter = options.get('counter', 0)
        if options.get('session_checkpoint'):
            self.session.checkpoint()
        if options.get('initial_backup') == False:
            counter += 1
        # Increase the multiplier so that later calls insert unique items.
        return {'mult': mult + 1, 'counter': counter}

    #
    # Set up all the directories needed for the test. We have a full backup directory for each
    # iteration and an incremental backup for each iteration. That way we can compare the full and
    # incremental each time through.
    #
    def setup_directories(self, max_iteration, home_incr, home_full, logpath):
        for i in range(0, max_iteration):
            # The log directory is a subdirectory of the home directory,
            # creating that will make the home directory also.

            home_incr_dir = home_incr + '.' + str(i)
            if os.path.exists(home_incr_dir):
                os.remove(home_incr_dir)
            os.makedirs(home_incr_dir + '/' + logpath)

            if i == 0:
                continue
            home_full_dir = home_full + '.' + str(i)
            if os.path.exists(home_full_dir):
                os.remove(home_full_dir)
            os.makedirs(home_full_dir + '/' + logpath)
    #
    # Compare against two directory paths using the wt dump command. The suffix allows the option
    # of create output files to distinct.
    #
    def compare_backups(self, uri, base_dir_home, other_dir_home, suffix = None):
        sfx = ""
        if suffix != None:
            sfx = "." + suffix
        base_out = "./backup_base" + sfx
        base_dir = base_dir_home + sfx

        if os.path.exists(base_out):
            os.remove(base_out)

        # Run wt dump on base backup directory
        self.runWt(['-R', '-h', base_dir, 'dump', uri], outfilename=base_out)
        other_out = "./backup_other" + sfx
        if os.path.exists(other_out):
            os.remove(other_out)
        # Run wt dump on incremental backup
        other_dir = other_dir_home + sfx
        self.runWt(['-R', '-h', other_dir, 'dump', uri], outfilename=other_out)
        self.assertEqual(True, compare_files(self, base_out, other_out))
