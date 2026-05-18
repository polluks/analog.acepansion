#ifndef ACEPANSION_H
#define ACEPANSION_H

#ifndef EXEC_TYPES_H
#include <exec/types.h>
#endif
#ifndef ACEPANSION_PLUGIN_H
#include <acepansion/plugin.h>
#endif

#define LIBNAME "analog.acepansion"
#define VERSION 1
#define REVISION 0
#define DATE "18.05.2026"
#define COPYRIGHT "2026"

#define API_VERSION 7

#define ANALOG_JOYSTICK_PORT_0 0
#define ANALOG_JOYSTICK_PORT_1 1

VOID Plugin_SetJoystickPort(struct ACEpansionPlugin *plugin, UBYTE port);

#endif
