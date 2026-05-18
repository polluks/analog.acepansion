#include <clib/alib_protos.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/utility.h>
#include <dos/dos.h>
#include <utility/utility.h>

#define USE_INLINE_API
#include <acepansion/lib_header.h>
#include <libraries/acepansion_plugin.h>

#include "acepansion.h"
#include "interface.h"
#define CATCOMP_NUMBERS
#include "generated/locale_strings.h"

#ifdef __HAIKU__
#include <Resources.h>
#endif

struct Library *DOSBase;
struct Library *UtilityBase;

struct PluginData
{
    struct ACEpansionPlugin common;

    struct SignalSemaphore *sema;

    BOOL  lightDetected;
    BOOL  buttonPressed;
    UBYTE joystickPort;
    UBYTE pulseTimer;

    BOOL  active;
};

static void init(struct PluginData *myPlugin);

BOOL InitResources(VOID)
{
    DOSBase = OpenLibrary("dos.library", 0L);
    UtilityBase = OpenLibrary("utility.library", 0L);

    return DOSBase != NULL
        && UtilityBase != NULL
        && GUI_InitResources();
}

VOID FreeResources(VOID)
{
    GUI_FreeResources();

    CloseLibrary(DOSBase);
    CloseLibrary(UtilityBase);
}

ACEPANSION_API
struct ACEpansionPlugin *CreatePlugin(UNUSED CONST_STRPTR *toolTypes, UNUSED struct SignalSemaphore *sema)
{
    struct PluginData *myPlugin = AllocVec(sizeof(struct PluginData), MEMF_PUBLIC | MEMF_CLEAR);

    if (myPlugin)
    {
        myPlugin->common.ap_APIVersion     = API_VERSION;
        myPlugin->common.ap_Flags          = ACE_FLAGSF_ACTIVE_RESET
                                           | ACE_FLAGSF_ACTIVE_EMULATE
                                           | ACE_FLAGSF_ACTIVE_READIO
                                           | ACE_FLAGSF_ACTIVE_WRITEIO
                                           | ACE_FLAGSF_ACTIVE_READMEM
                                           | ACE_FLAGSF_ACTIVE_WRITEMEM;
        myPlugin->common.ap_Title          = GetString(MSG_TITLE);
        myPlugin->common.ap_HelpFileName   = LIBNAME ".guide";
        myPlugin->common.ap_ToggleMenuName = GetString(MSG_MENU_TOGGLE);
        myPlugin->common.ap_PrefsMenuName  = GetString(MSG_MENU_PREFS);
        myPlugin->common.ap_PrefsWindow    = GUI_Create((struct ACEpansionPlugin *)myPlugin);

        myPlugin->sema = sema;
        myPlugin->joystickPort = ANALOG_JOYSTICK_PORT_1;
        init(myPlugin);
    }

    return (struct ACEpansionPlugin *)myPlugin;
}

ACEPANSION_API
VOID DeletePlugin(struct ACEpansionPlugin *plugin)
{
    struct PluginData *myPlugin = (struct PluginData *)plugin;

    GUI_Delete(myPlugin->common.ap_PrefsWindow);
    FreeVec(myPlugin);
}

ACEPANSION_API
BOOL ActivatePlugin(struct ACEpansionPlugin *plugin, BOOL activate)
{
    struct PluginData *myPlugin = (struct PluginData *)plugin;

    myPlugin->active = activate;
    init(myPlugin);

    return activate;
}

ACEPANSION_API
STRPTR *GetPrefsPlugin(UNUSED struct ACEpansionPlugin *plugin, UNUSED APTR pool)
{
    return NULL;
}

ACEPANSION_API
VOID Reset(struct ACEpansionPlugin *plugin)
{
    struct PluginData *myPlugin = (struct PluginData *)plugin;
    init(myPlugin);
}

ACEPANSION_API
VOID Emulate(UNUSED struct ACEpansionPlugin *plugin, UNUSED ULONG *signals)
{
    struct PluginData *myPlugin = (struct PluginData *)plugin;

    if (myPlugin->pulseTimer > 0)
    {
        myPlugin->pulseTimer--;
        myPlugin->lightDetected = TRUE;
    }
    else
    {
        myPlugin->lightDetected = FALSE;
    }
}

ACEPANSION_API
VOID WriteIO(UNUSED struct ACEpansionPlugin *plugin, UNUSED USHORT port, UNUSED UBYTE value)
{
}

ACEPANSION_API
VOID ReadIO(UNUSED struct ACEpansionPlugin *plugin, UNUSED USHORT port, UNUSED UBYTE *value)
{
}

ACEPANSION_API
BOOL WriteMem(UNUSED struct ACEpansionPlugin *plugin, UNUSED USHORT address, UNUSED UBYTE value)
{
    return FALSE;
}

ACEPANSION_API
VOID ReadMem(UNUSED struct ACEpansionPlugin *plugin, UNUSED USHORT address, UNUSED UBYTE *value, UNUSED BOOL opcodeFetch)
{
}

ACEPANSION_API
VOID GetAudio(UNUSED struct ACEpansionPlugin *plugin, UNUSED SHORT *leftSample, UNUSED SHORT *rightSample)
{
}

ACEPANSION_API
VOID Printer(UNUSED struct ACEpansionPlugin *plugin, UNUSED UBYTE data, UNUSED BOOL strobe, UNUSED BOOL *busy)
{
}

ACEPANSION_API
VOID Joystick(struct ACEpansionPlugin *plugin, BOOL com1, BOOL com2, UBYTE *ioData)
{
    struct PluginData *myPlugin = (struct PluginData *)plugin;

    if (!myPlugin->active)
        return;

    BOOL ourPort = (myPlugin->joystickPort == ANALOG_JOYSTICK_PORT_0) ? com1 : com2;

    if (ourPort)
    {
        if (myPlugin->lightDetected)
        {
            *ioData &= ~ACE_IODATAF_JOYSTICK_DOWN;
        }

        if (myPlugin->buttonPressed)
        {
            *ioData &= ~ACE_IODATAF_JOYSTICK_FIRE1;
        }
    }
}

ACEPANSION_API
VOID AnalogInput(UNUSED struct ACEpansionPlugin *plugin, UNUSED UBYTE channel, UNUSED UBYTE *value)
{
}

ACEPANSION_API
VOID AcknowledgeInterrupt(UNUSED struct ACEpansionPlugin *plugin, UNUSED UBYTE *ivr)
{
}

ACEPANSION_API
VOID ReturnInterrupt(UNUSED struct ACEpansionPlugin *plugin)
{
}

ACEPANSION_API
VOID Cursor(UNUSED struct ACEpansionPlugin *plugin)
{
}

ACEPANSION_API
VOID HostGamepadList(UNUSED struct ACEpansionPlugin *plugin, UNUSED STRPTR *list)
{
}

ACEPANSION_API
VOID HostGamepadEvent(UNUSED struct ACEpansionPlugin *plugin, UNUSED UBYTE index, UNUSED USHORT buttons, UNUSED BYTE ns, UNUSED BYTE ew, UNUSED BYTE lx, UNUSED BYTE ly, UNUSED BYTE rx, UNUSED BYTE ry)
{
}

ACEPANSION_API
VOID HostMouseEvent(UNUSED struct ACEpansionPlugin *plugin, UNUSED UBYTE buttons, UNUSED SHORT deltaX, UNUSED SHORT deltaY)
{
}

ACEPANSION_API
VOID HostLightDeviceDiodePulse(struct ACEpansionPlugin *plugin)
{
    struct PluginData *myPlugin = (struct PluginData *)plugin;
    myPlugin->pulseTimer = 10;
}

ACEPANSION_API
VOID HostLightDeviceButton(struct ACEpansionPlugin *plugin, BOOL pressed)
{
    struct PluginData *myPlugin = (struct PluginData *)plugin;
    myPlugin->buttonPressed = pressed;
}

static void init(struct PluginData *myPlugin)
{
    myPlugin->pulseTimer = 0;
    myPlugin->lightDetected = FALSE;
    myPlugin->buttonPressed = FALSE;
}

VOID Plugin_SetJoystickPort(struct ACEpansionPlugin *plugin, UBYTE port)
{
    struct PluginData *myPlugin = (struct PluginData *)plugin;

    ObtainSemaphore(myPlugin->sema);
    if (port == ANALOG_JOYSTICK_PORT_0 || port == ANALOG_JOYSTICK_PORT_1)
    {
        myPlugin->joystickPort = port;
    }
    ReleaseSemaphore(myPlugin->sema);
}
