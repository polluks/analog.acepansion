#include <clib/alib_protos.h>
#include <proto/exec.h>
#include <proto/utility.h>
#include <proto/intuition.h>
#include <proto/muimaster.h>
#include <libraries/asl.h>
#include <acepansion/lib_header.h>

#include "acepansion.h"
#include "interface.h"
#define CATCOMP_NUMBERS
#include "generated/locale_strings.h"

struct Library *IntuitionBase;
struct Library *UtilityBase;
struct Library *MUIMasterBase;

struct MUI_CustomClass *MCC_AnalogClass = NULL;

#define AnalogObject NewObject(MCC_AnalogClass->mcc_Class, NULL)

#define MUIA_Analog_Plugin       (TAG_USER | 0x0000)
#define MUIA_Analog_JoystickPort (TAG_USER | 0x0001)

#define MUIM_Analog_Notify       (TAG_USER | 0x0100)
#define MUIV_Analog_Notify_ToGUI     0
#define MUIV_Analog_Notify_ToPlugin  1

#define MUIV_Analog_Notify_UpdateStatus 10
#define MUIV_Analog_Notify_PortChange  11

struct MUIP_Analog_Notify
{
    IPTR id;
    IPTR direction;
    IPTR type;
    IPTR data;
};

struct AnalogData
{
    struct ACEpansionPlugin *plugin;
    Object *TXT_LightStatus;
    Object *TXT_ButtonStatus;
    Object *BTN_Port0;
    Object *BTN_Port1;
};

static IPTR mNotify(struct IClass *cl, Object *obj, struct MUIP_Analog_Notify *msg)
{
    struct AnalogData *data = INST_DATA(cl, obj);

    switch (msg->direction)
    {
        case MUIV_Analog_Notify_ToGUI:
            switch (msg->type)
            {
                case MUIV_Analog_Notify_UpdateStatus:
                {
                    BOOL lightDetected = (BOOL)(msg->data & 0x01);
                    BOOL buttonPressed = (BOOL)((msg->data >> 1) & 0x01);

                    set(data->TXT_LightStatus, MUIA_Text_Contents,
                        lightDetected ? GetString(MSG_LIGHT_DETECTED)
                                      : GetString(MSG_LIGHT_NONE));
                    set(data->TXT_ButtonStatus, MUIA_Text_Contents,
                        buttonPressed ? GetString(MSG_BUTTON_PRESSED)
                                      : GetString(MSG_BUTTON_RELEASED));
                    break;
                }
            }
            break;

        case MUIV_Analog_Notify_ToPlugin:
            switch (msg->type)
            {
                case MUIV_Analog_Notify_PortChange:
                    Plugin_SetJoystickPort(data->plugin, (UBYTE)msg->data);
                    break;
            }
            break;
    }

    return 0;
}

static IPTR mNew(struct IClass *cl, Object *obj, Msg msg)
{
    struct TagItem *tags, *tag;
    struct AnalogData *data;

    struct ACEpansionPlugin *plugin = NULL;

    for (tags = ((struct opSet *)msg)->ops_AttrList; (tag = NextTagItem(&tags)); )
    {
        switch (tag->ti_Tag)
        {
            case MUIA_Analog_Plugin:
                plugin = (struct ACEpansionPlugin *)tag->ti_Data;
                break;
        }
    }

    if (!plugin) return 0;

    obj = (Object *)DoSuperNew(cl, obj,
        GroupFrameT(GetString(MSG_STATUS)),
        Child, VGroup,
            Child, HGroup,
                Child, TextObject,
                    MUIA_Font, MUIV_Font_Button,
                    MUIA_Text_Contents, GetString(MSG_LABEL_LIGHT),
                    End,
                Child, data->TXT_LightStatus = TextObject,
                    MUIA_Font, MUIV_Font_Button,
                    MUIA_Text_Contents, GetString(MSG_LIGHT_NONE),
                    End,
                End,
            Child, HGroup,
                Child, TextObject,
                    MUIA_Font, MUIV_Font_Button,
                    MUIA_Text_Contents, GetString(MSG_LABEL_BUTTON),
                    End,
                Child, data->TXT_ButtonStatus = TextObject,
                    MUIA_Font, MUIV_Font_Button,
                    MUIA_Text_Contents, GetString(MSG_BUTTON_RELEASED),
                    End,
                End,
            End,
        GroupFrameT(GetString(MSG_PORT_SELECT)),
        Child, VGroup,
            Child, data->BTN_Port0 = TextObject,
                MUIA_Font,       MUIV_Font_Button,
                MUIA_InputMode,  MUIV_InputMode_RelVerify,
                MUIA_CycleChain, TRUE,
                MUIA_Text_Contents, GetString(MSG_PORT_0),
                MUIA_Selected, FALSE,
                End,
            Child, data->BTN_Port1 = TextObject,
                MUIA_Font,       MUIV_Font_Button,
                MUIA_InputMode,  MUIV_InputMode_RelVerify,
                MUIA_CycleChain, TRUE,
                MUIA_Text_Contents, GetString(MSG_PORT_1),
                MUIA_Selected, TRUE,
                End,
            End,
        TAG_MORE, ((struct opSet *)msg)->ops_AttrList);

    if (!obj) return 0;

    data = INST_DATA(cl, obj);
    data->plugin = plugin;

    DoMethod(data->BTN_Port0, MUIM_Notify, MUIA_Selected, MUIV_EveryTime,
             obj, 3, MUIM_Analog_Notify,
             MUIV_Analog_Notify_ToPlugin, MUIV_Analog_Notify_PortChange,
             ANALOG_JOYSTICK_PORT_0);

    DoMethod(data->BTN_Port1, MUIM_Notify, MUIA_Selected, MUIV_EveryTime,
             obj, 3, MUIM_Analog_Notify,
             MUIV_Analog_Notify_ToPlugin, MUIV_Analog_Notify_PortChange,
             ANALOG_JOYSTICK_PORT_1);

    return (IPTR)obj;
}

DISPATCHER(AnalogClass)
{
    switch (msg->MethodID)
    {
        case OM_NEW:            return mNew(cl, obj, (APTR)msg);
        case MUIM_Analog_Notify:   return mNotify(cl, obj, (APTR)msg);
    }
}
DISPATCHER_END

BOOL GUI_InitResources(VOID)
{
    UtilityBase = OpenLibrary("utility.library", 0L);
    IntuitionBase = OpenLibrary("intuition.library", 0L);
    MUIMasterBase = OpenLibrary("muimaster.library", 0L);

    if (UtilityBase && IntuitionBase && MUIMasterBase)
    {
        MCC_AnalogClass = MUI_CreateCustomClass(
            NULL,
            MUIC_Group,
            NULL,
            sizeof(struct AnalogData),
            DISPATCHER_REF(AnalogClass));
    }

    return MCC_AnalogClass != NULL;
}

VOID GUI_FreeResources(VOID)
{
    if (MCC_AnalogClass)
        MUI_DeleteCustomClass(MCC_AnalogClass);

    CloseLibrary(MUIMasterBase);
    CloseLibrary(IntuitionBase);
    CloseLibrary(UtilityBase);
}

Object *GUI_Create(struct ACEpansionPlugin *plugin)
{
    return AnalogObject,
        MUIA_Analog_Plugin, plugin,
        End;
}

VOID GUI_Delete(Object *gui)
{
    MUI_DisposeObject(gui);
}

VOID GUI_UpdateStatus(Object *gui, BOOL lightDetected, BOOL buttonPressed)
{
    if (gui)
    {
        IPTR data = ((IPTR)lightDetected) | (((IPTR)buttonPressed) << 1);
        DoMethod(gui, MUIM_Analog_Notify,
                 MUIV_Analog_Notify_ToGUI,
                 MUIV_Analog_Notify_UpdateStatus,
                 data);
    }
}
