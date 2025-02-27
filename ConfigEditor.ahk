﻿#Include %A_ScriptDir%\ConfigTools.ahk
global mainAhkPath := A_ScriptDir . "\Main.ahk"

#NoTrayIcon ; 不显示小图标
#SingleInstance force ; 单例模式

; 加快脚本运行速度的设置
#NoEnv
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#KeyHistory 0
ListLines Off
Process, Priority, , A
SetBatchLines, -1
SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetWinDelay, -1
SetControlDelay, -1
SendMode Input
; 加快脚本运行速度的设置

global startFile := 1 ; 设置不当可能会使脚本直接退出, 1 为循环首索引
    , fileContents := {}
    , manifest := []

    , password := A_Args[1]
    , lastReloadTime := A_Args[2]

    , isWorking := False

ReadConfigsToScript(password, fileContents, manifest, lastReloadTime)

For index, value in manifest
{
    InitPools(JSON.Load(fileContents[value]))
}

global current := manifest[startFile]
    , manifestLength := 0
    , edittext := ""
    , choices := ""

If (current == "")
{
    MsgBox, 未检测到任何配置文件，脚本将退出！
    ExitApp
}

If (fileContents.Count() == 0) {
    MsgBox, 没有可访问的配置文件！
    ExitApp
}

manifest := []
For key, _ in fileContents
{
    manifest[A_Index] := key
}

current := manifest[startFile]
manifestLength := manifest.Length()

Loop % manifestLength
{
    choices .= manifest[A_Index]
    If (A_Index != manifestLength)
        choices .= "|"
    If (A_Index == startFile)
    {
        choices .= "|" ; '||' 为预选标签
    }
}

global width := 700
    , listWidth := 2 * buttonWidth := width / 6
    , realWidth := width + 4 * margin := 10

Gui, Font, s14
Gui, Add, DropDownList, hWndhList vCurrent gSwitch w%listWidth%, %choices%
Gui, Add, Button, hWndhButton1 x+%margin% gSaveCurrent w%buttonWidth% h30, 保存此表
Gui, Add, Button, hWndhButton2 x+%margin% gChangePW w%buttonWidth% h30, 改密码保存
Gui, Add, Button, hWndhButton3 x+%margin% gDeleteCurrent w%buttonWidth% h30, 删除此表
Gui, Add, Button, hWndhButton4 x+%margin% gNewItem w%buttonWidth% h30, 新建项
Gui, Add, Edit, hWndhEdit xs y+%margin% vedittext w%realWidth% h400
Gui, Show,, Config Editor
GuiControl, Text, edittext, % fileContents[current]
Return

Switch:
    ; ( 保存当前文件至 fileContents
    GuiControlGet, edittext
    fileContents[current] := edittext
    Gui, Submit, NoHide
    ; )
    GuiControl, Text, edittext, % fileContents[current]
Return

SaveCurrent:
    Gui, Submit, NoHide
    fileContents[current] := edittext

    path := GetConfigPath(current)

    isWorking := True
    If (!WriteCryptedJsonString(path, edittext, password))
    {
        MsgBox, 不合法的json语句
        isWorking := False
        Return
    }

    isWorking := False
    MsgBox, 已保存: %path%
    RunAhk(mainAhkPath, password . " " . lastReloadTime)
Return

ChangePW:
    MsgBox, 未实现。。。
Return

DeleteCurrent:
    MsgBox, 未实现。。。
Return

NewItem:
    Gui, Submit, NoHide
    currentText := RTrim(edittext)

    if (SubStr(currentText, 0) != "}")
    {
        MB("此功能要求必须是对象!")
        Return
    }

    trimText := RTrim(SubStr(currentText, 1, StrLen(currentText) - 1)) ; 第一至倒二的字符串再 trim
    If(SubStr(trimText, 0) != ",")
        trimText.=","

    trimText .= "`n""newItem"": {`n ""type"": """",`n ""value"": """"`n }`n}"

    GuiControl, Text, edittext, %trimText%

    cursorPos := InStr(trimText, "newItem")
    SendMessage, 0xB1, cursorPos, cursorPos+7,, ahk_id %hEdit% ; 此处 cursor 的偏移似乎受换行符影响
    ControlFocus,, ahk_id %hEdit%
Return

GuiClose:
GuiEscape:
    If(isWorking)
    {
        MsgBox, 请等文件保存后再试
        Return
    }

    ; ( 保存当前文件至 fileContents
    GuiControlGet, edittext
    fileContents[current] := edittext
    Gui, Submit, NoHide
    ; )

    ReadConfigFiles(manifest, password, reread, "{}")

    unsaved := ""
    For k, v in fileContents
    {
        If(reread.HasKey(k))
        {
            If (JSON.Dump(JSON.Load(v)) != reread[k])
            {
                unsaved .= " " . k
            }
        }
    }
    If(unsaved)
    {
        MsgBox, 1, , 未保存的文件:%unsaved%
        IfMsgBox Cancel
            Return
    }
ExitApp
Return