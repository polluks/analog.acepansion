LP-1 ACEpansion - Amstrad LP-1 Light Pen plugin for ACE CPC Emulator
=====================================================================

This is an ACEpansion (expansion plugin) for the ACE CPC emulator
that emulates the Amstrad LP-1 Light Pen.

The LP-1 connects to the CPC via the joystick port, using the DOWN
direction signal as a light sensor input. This plugin bridges ACE's
built-in light device tracking to the LP-1's joystick port protocol.

Building
--------
Requires the ACE Plugin SDK (included with the ACE emulator archive):

  http://ace.cpcscene.net/_media/ace-morphos.lha "ACE/Bonus/Plugins SDK/"

Build on MorphOS:

  make

Z80 Driver
----------
The driver/ directory contains a Z80 assembly driver for reading the
LP-1 light pen in your own CPC programs. It assembles with RASM:

  https://github.com/EdouardBERGE/rasm

  cd driver && make

References
----------
  https://www.cpcwiki.eu/index.php/Amstrad_LP-1_light_pen
  https://www.cpcwiki.eu/index.php/Light_pen_driver

Source code mirror: https://framagit.org/offset (search for "acepansion")
