#!/usr/bin/env python2
"""
Barebones example of FBInk usage through Python's cFFI module
"""

# To get a Py3k-like print function
from __future__ import print_function

import sys
# Load the wrapper module, it's linked against FBInk, so the dynamic loader will take care of pulling in the actual FBInk library
from _fbink import ffi, lib as FBInk

# Let's check which FBInk version we're using...
# NOTE: ffi.string() returns a bytes on Python 3, not a str, hence the extra decode
print("Loaded FBInk {}".format(ffi.string(FBInk.fbink_version()).decode("ascii")))

# And now we're good to go! Let's print "Hello World" in the center of the screen...
# Setup the config...
fbink_cfg = ffi.new("FBInkConfig *")
fbink_cfg.is_centered = False
fbink_cfg.is_halfway = True
fbink_cfg.is_cleared = True
fbink_cfg.is_verbose = True

fbink_ot_cfg = ffi.new("FBInkOTConfig *")
fbink_ot_cfg.size_pt = 24

"""
# Open the FB...
fbfd = FBInk.fbink_open()
if fbfd == -1:
	raise SystemExit("Failed to open the framebuffer, aborting . . .")

# Initialize FBInk...
if FBInk.fbink_init(fbfd, fbink_cfg) < 0:
	raise SystemExit("Failed to initialize FBInk, aborting . . .")

# Do stuff!
if FBInk.fbink_print(fbfd, b"Hello World", fbink_cfg) < 0:
	print("Failed to print that string!", file=sys.stderr)

# And now we can wind things down...
if FBInk.fbink_close(fbfd) < 0:
	raise SystemExit("Failed to close the framebuffer, aborting . . .")
"""

# Or, the same but in a slightly more Pythonic approach ;).
fbfd = FBInk.fbink_open()
try:
	FBInk.fbink_init(fbfd, fbink_cfg)
	FBInk.fbink_add_ot_font("BigBlue_Terminal.ttf", FBInk.FNT_REGULAR)
	string = u"Success \uf632 or \ufadf or \ufae0 or \ufc8f or \uf633 or \uf4a1"	// \uf633
	string += u"\n"
	string += u"Error \uf071 or \uf525 or \uf529 or \uf421 or \ufb8f"		// \uf071
	string += u"\n"
	string += u"Wait \uf252 or \ufa1e or \uf49b"					// \uf252
	string += u"\n"
	string += u"Python \ue73c or \ue235 or \uf81f or \ue606"			// \ue73c
	string += u"\n"
	string += u"USBNet \ue795 or \uf68c or \ufcb5 or \uf489"			// \uf68c
	string += u"\n"
	string += u"Bridge \uf270 or \uf52c or \ue286 or \uf5a6 or \ue214"		// \ue286 (AMZ: \uf270)
	string += u"\n"
	string += u":( \uf119 or \uf6f7"						// \uf119
	string += u"\n"
	string += u"Linux \uf17c or \uf31a or \uf83c"					// \uf17c
	string += u"\n"
	string += u":) \uf118 or \uf6f4"						// \uf118
	string += u"\n"
	string += u"Tools \ue20f or \ufbf6 or \uf992 or \ufab6 or \uf425"		// \uf425
	string += u"\n"
	string += u"MRPI \ufcdd or \ufcde or \uf8d5 or \uf962 or \ufac3 or \uf487 or \uf427"	// \uf8d5 (KUAL: \uf962)
	string = string.encode("utf-8")
	# NOTE: On Python 3, cFFI maps char to bytes, not str
	FBInk.fbink_print_ot(fbfd, string, fbink_ot_cfg, fbink_cfg, ffi.NULL)
finally:
	FBInk.fbink_free_ot_fonts()
	FBInk.fbink_close(fbfd)
