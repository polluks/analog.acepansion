Analog ACEpansion - GX4000/Plus Analog Joystick plugin for ACE CPC Emulator
===========================================================================

This is an ACEpansion (expansion plugin) for the ACE CPC emulator
that provides analog joystick support for GX4000/Plus via the
built-in ADC hardware, based on the Tennis Cup 2 cartridge:

  https://www.cpcwiki.eu/index.php/Tennis_Cup_2_(cartridge)

Tennis Cup 2 is the only known GX4000/Plus game to support an
analog joystick, converting analog signals to digital directions
via software. This plugin exposes the ADC hardware in emulation.

Building
--------
Requires the ACE Plugin SDK (included with the ACE emulator archive):

  http://ace.cpcscene.net/_media/ace-morphos.lha "ACE/Bonus/Plugins SDK/"

Build on MorphOS:

  make

Z80 Driver
----------
The driver/ directory contains a Z80 assembly driver for reading
the analog joystick. It assembles with RASM:

  https://www.cpcwiki.eu/index.php/Tennis_Cup_2_(cartridge)

  cd driver && make

References
----------
  https://www.cpcwiki.eu/index.php/Tennis_Cup_2_(cartridge)

Source code mirror: https://framagit.org/offset (search for "acepansion")
