#ifndef ACEPANSION_GUI_H
#define ACEPANSION_GUI_H

#ifndef EXEC_TYPES_H
#include <exec/types.h>
#endif
#ifndef INTUITION_CLASSUSR_H
#include <intuition/classusr.h>
#endif
#ifndef ACEPANSION_PLUGIN_H
#include <acepansion/plugin.h>
#endif

BOOL GUI_InitResources(VOID);
VOID GUI_FreeResources(VOID);

Object *GUI_Create(struct ACEpansionPlugin *plugin);
VOID GUI_Delete(Object *gui);

VOID GUI_UpdateStatus(Object *gui, BOOL lightDetected, BOOL buttonPressed);

#endif
