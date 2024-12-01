﻿#Include Message.ahk

#Persistent
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
DllCall("ntdll\ZwSetTimerResolution", "Int", 5000, "Int", 1, "Int*", MyCurrentTimerResolution) ; setting the Windows Timer Resolution to 0.5ms, THIS IS A GLOBAL CHANGE
; 加快脚本运行速度的设置

global stay := 1500

FT_Show("win cast is on!", stay)
Return

RCtrl::RWin
:*:,./::
:*:/.,::
    FT_Show("win cast is off!", stay)
    Sleep, %stay%
ExitApp