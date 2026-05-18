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

struct MUI_CustomClass *MCC_LP1Class = NULL;

#define LP1Object NewObject(MCC_LP1Class->mcc_Class, NULL)

#define MUIA_LP1_Plugin       (TAG_USER | 0x0000)
#define MUIA_LP1_JoystickPort (TAG_USER | 0x0001)

#define MUIM_LP1_Notify       (TAG_USER | 0x0100)
#define MUIV_LP1_Notify_ToGUI     0
#define MUIV_LP1_Notify_ToPlugin  1

#define MUIV_LP1_Notify_UpdateStatus 10
#define MUIV_LP1_Notify_PortChange  11

struct MUIP_LP1_Notify
{
    IPTR id;
    IPTR direction;
    IPTR type;
    IPTR data;
};

struct LP1Data
{
    struct ACEpansionPlugin *plugin;
    Object *TXT_LightStatus;
    Object *TXT_ButtonStatus;
    Object *BTN_Port0;
    Object *BTN_Port1;
};

static IPTR mNotify(struct IClass *cl, Object *obj, struct MUIP_LP1_Notify *msg)
{
    struct LP1Data *data = INST_DATA(cl, obj);

    switch (msg->direction)
    {
        case MUIV_LP1_Notify_ToGUI:
            switch (msg->type)
            {
                case MUIV_LP1_Notify_UpdateStatus:
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

        case MUIV_LP1_Notify_ToPlugin:
            switch (msg->type)
            {
                case MUIV_LP1_Notify_PortChange:
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
    struct LP1Data *data;

    struct ACEpansionPlugin *plugin = NULL;

    for (tags = ((struct opSet *)msg)->ops_AttrList; (tag = NextTagItem(&tags)); )
    {
        switch (tag->ti_Tag)
        {
            case MUIA_LP1_Plugin:
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
             obj, 3, MUIM_LP1_Notify,
             MUIV_LP1_Notify_ToPlugin, MUIV_LP1_Notify_PortChange,
             LP1_JOYSTICK_PORT_0);

    DoMethod(data->BTN_Port1, MUIM_Notify, MUIA_Selected, MUIV_EveryTime,
             obj, 3, MUIM_LP1_Notify,
             MUIV_LP1_Notify_ToPlugin, MUIV_LP1_Notify_PortChange,
             LP1_JOYSTICK_PORT_1);

    return (IPTR)obj;
}

DISPATCHER(LP1Class)
{
    switch (msg->MethodID)
    {
        case OM_NEW:            return mNew(cl, obj, (APTR)msg);
        case MUIM_LP1_Notify:   return mNotify(cl, obj, (APTR)msg);
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
        MCC_LP1Class = MUI_CreateCustomClass(
            NULL,
            MUIC_Group,
            NULL,
            sizeof(struct LP1Data),
            DISPATCHER_REF(LP1Class));
    }

    return MCC_LP1Class != NULL;
}

VOID GUI_FreeResources(VOID)
{
    if (MCC_LP1Class)
        MUI_DeleteCustomClass(MCC_LP1Class);

    CloseLibrary(MUIMasterBase);
    CloseLibrary(IntuitionBase);
    CloseLibrary(UtilityBase);
}

Object *GUI_Create(struct ACEpansionPlugin *plugin)
{
    return LP1Object,
        MUIA_LP1_Plugin, plugin,
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
        DoMethod(gui, MUIM_LP1_Notify,
                 MUIV_LP1_Notify_ToGUI,
                 MUIV_LP1_Notify_UpdateStatus,
                 data);
    }
}
