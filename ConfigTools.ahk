﻿; IsParsable(v)
; IsUrl(str)
; InitPools(obj, parent := "")
; BuildRunnables()
; BuildHotStrings()
; BuildCodes()
; BuildHotstring(funcName, key, value)
; ConfigsReload(cPath, cDefault, ByRef password, ByRef contents, ByRef manifest)
; ConfigsInit(cPath, cDefault, ByRef password, ByRef contents, ByRef manifest)
; _ConfigsBuild(cPath, cDefault, ByRef password, ByRef contents, ByRef manifest, withPassword)
; Guidance()
; ReadConfigsToScript(ByRef pw_br, ByRef contents_br, ByRef manifest_br, ByRef lastSet_br)
; IsOutOfDate(lastSet, maxSet)
; RunAhk(dir, extra := "")
; RequirePassword(msg)
; ReadCryptedJsonString(path, password, default)
; ReadCyptedJSON(path, password, default)
; IsJson(str)
; WriteCryptedJsonString(path, str, password)
; WriteCryptedJSON(path, obj, password)
; ReadCryptedFile(path, password, default)
; WriteCryptFile(path, bytes, password)
; AppendCryptFile(path, bytes, password)
; GetConfigPath(name)
; ReadConfigFiles(manifest, password, ByRef outObj, default)
; CleanUnregistereds(manifest)

#Include %A_ScriptDir%\FileTools.ahk

#Include %A_ScriptDir%\lib\message\Message.ahk
#Include %A_ScriptDir%\lib\everything\Everything.ahk
#Include %A_ScriptDir%\lib\json\JSON.ahk

global configFolder := A_ScriptDir . "\config\"
    , configNameStr := "configs"
    , hotstringStyle_H := "::"
    , hotstringStyle_T := ""

global POOL_RUNNABLE := {}
    , POOL_CODE := {}
    , POOL_STATIC := {}
    , POOL_HOTSTRING := {}

    , configsDefaultJson := "[""configs"",""You can write anything as a new config file!""]"
    , REQUIRE_PASSWORD_MAX := 7 * 24 * 60 * 60 * 1000 ; 7 days

IsParsable(v)
{
    type := GetType(v)
    Return type == "array" || type == "object"
}

IsUrl(str)
{
    return RegExMatch(str, "i)^https?://") > 0
}

InitPools(obj, parent := "")
{
    If (!IsParsable(obj)) ; 不可解析
        Return

    str := obj["value"]
    strType := GetType(str)
    type := obj["type"]

    If (strType == "string" || strType == "number") ; 当设置了 value 属性时
    {
        If (type == "hotString")
            POOL_HOTSTRING[parent] := str
        Else If (type == "runnable")
            POOL_RUNNABLE[parent] := str
        Else If (type == "code")
            POOL_CODE[parent] := str
        Else If (type == "static")
            POOL_STATIC[parent] := str
        Else ; 全部当作 static 处理
        {
            MB(parent . " 设置了未定义的 type: " . type)
            POOL_STATIC[parent] := str
        }

        Return
    }
    Else If (strType == "undifined" && type)
    {
        MB("未设置 value 的项: " . parent)
        Return
    }

    for key, value in obj
        If (IsParsable(value)) ; 递归解析
        {
            InitPools(value, key)
        }
        Else ; 值是基本类型
        {
            If (GetType(key) == "string")
                POOL_STATIC[key] := value
        }
}

BuildRunnables()
{
    For Key, value in POOL_RUNNABLE
        BuildHotstring("RunWithSplashText", key, value)
}

BuildHotStrings()
{
    for key, value in POOL_HOTSTRING
        BuildHotstring("SendString", key, value)
}

BuildCodes()
{
    For Key, value in POOL_CODE
        BuildHotstring("RunWaitString", key, value)
}

BuildHotstring(funcName, key, value)
{
    hotstring := hotstringStyle_H . key . hotstringStyle_T
    Hotstring(hotstring, Func(funcName).Bind(value))
}

ConfigsReload(cPath, cDefault, ByRef password, ByRef contents, ByRef manifest)
{
    _ConfigsBuild(cPath, cDefault, password, contents, manifest, True)
}

ConfigsInit(cPath, cDefault, ByRef password, ByRef contents, ByRef manifest)
{
    _ConfigsBuild(cPath, cDefault, password, contents, manifest, False)
}

_ConfigsBuild(cPath, cDefault, ByRef password, ByRef contents, ByRef manifest, withPassword)
{
    isFirst := GetFileSize(cPath) <= 0

    If (isFirst)
        Guidance()

    If (isFirst && !IsJson(cDefault))
    {
        MsgBox, 默认配置表不是合法的json语句，脚本将退出！
        ExitApp
    }

    While 1
    {
        If (A_Index == 1)
        {
            If (isFirst)
                msg := "设置一个密码"
            Else
                msg := "请输入密码"
        }
        Else
        {
            If (isFirst)
            {
                MsgBox, 未知错误🥲
                ExitApp
            }
            Else
            {
                msg := "密码不正确，请重试"
            }
        }

        If (password == "" || !withPassword || A_Index != 1) ; 未传入密码或者进入了往后的循环(密码错误)
            password := RequirePassword(msg) ; 要求输入密码

        If (password == -1)
            ExitApp

        configs := ReadCryptedJsonString(cPath, password, cDefault)
        If (!configs)
            Continue

        manifest := JSON.Load(configs)
        If (ReadConfigFiles(manifest, password, contents, "{}"))
        {
            CleanUnregistereds(manifest)
            Break
        }
    }
}

; hotString
; static
; runnable
; code
Guidance()
{
    MB("输入 ""ed\"" 可以打开编辑器，可以用 json 编辑工具编辑完成后再粘贴")
    MB("使用高级功能的话需要设置两个变量:`n""type"": $str`n""value"": $str")
    MB("type:`n hotString => 可展开的热字符串`n static => 内部的静态变量`n runnable =>可运行路径, 完整的文件路径和url均可 `n code => ahk代码`n`n必须为其中之一，否则视作static")
    MB("示例: `n{`n""vs"":{""type"":""runnable"",""value"": ""D:\vscode.exe""}`n}")
}

ReadConfigsToScript(ByRef pw_br, ByRef contents_br, ByRef manifest_br, ByRef lastSet_br)
{
    If (pw_br && !IsOutOfDate(lastSet_br, REQUIRE_PASSWORD_MAX)) ; 带密码启动
    {
        ConfigsReload(GetConfigPath(configNameStr), configsDefaultJson, pw_br, contents_br, manifest_br)
    }
    Else
    {
        ConfigsInit(GetConfigPath(configNameStr), configsDefaultJson, pw_br, contents_br, manifest_br)
        lastSet_br := A_TickCount
    }
    Return
}

; lastSet 是否过期
IsOutOfDate(lastSet, maxSet)
{
    If (GetType(lastSet) != "number")
        Return True

    rest := A_TickCount - lastSet

    If (maxSet < 0)
        Return False
    Return rest >= maxSet
}

RunAhk(dir, extra := "")
{
    If (!FileExist(dir))
        Return
    Run, %A_AhkPath% %dir% %extra%
}

; 要求输入密码
RequirePassword(msg)
{
    InputBox, str, , %msg%:, Hide
    if ErrorLevel ; 用户按下取消或关闭窗口
        Return -1
    Return str
}

; 读取加密文件为 json 字串
ReadCryptedJsonString(path, password, default)
{
    jsonObj := ReadCyptedJSON(path, password, default)
    If (jsonObj == 0)
        Return ""

    str := JSON.Dump(jsonObj)
    If (str == """""")
        str := "{}"
    Return str
}

; 读取并返回 json 对象
ReadCyptedJSON(path, password, default)
{
    Try
    {
        bytes := ReadCryptedFile(path, password, default)
        str := BytesToString(bytes, "UTF-8")
        obj := JSON.Load(str)
        Return obj
    }
    Catch
    {
        Return 0
    }
}

IsJson(str)
{
    Try
    {
        j := JSON.Load(str)
        s := JSON.Dump(j)
        Return True
    }
    Catch
    {
        Return False
    }
}

WriteCryptedJsonString(path, str, password)
{
    Try
    {
        j := JSON.Load(str)
        s := JSON.Dump(j)
        WriteCryptedJSON(path, j, password)
        Return True
    }
    Catch
    {
        Return False
    }
}

; 写入 json 对象
WriteCryptedJSON(path, obj, password)
{
    Try
    {
        If (!IsObject(obj))
            Return -1

        str := JSON.Dump(obj)
        bytes := StringToBytes(str, "UTF-8")
        Return WriteCryptFile(path, bytes, password)
    }
    Catch
    {
        Return -1
    }
}

; 读取加密文件为字节数组
ReadCryptedFile(path, password, default)
{
    bytes := ReadBytes(path, 256)
    decrypt := CryptBytes(bytes, password)
    If (!bytes.Length())
    {
        defults := StringToBytes(default, "UTF-8")
        WriteCryptFile(path, defults, password)
        Return ReadCryptedFile(path, password, default)
    }
    Else
    {
        Return decrypt
    }
}

; 写入加密的字节数组到文件
WriteCryptFile(path, bytes, password)
{
    encrypt := CryptBytes(bytes, password)
    count := WriteBytes(path, encrypt, 256)
    Return count
}

; 写入加密的字节数组到文件
AppendCryptFile(path, bytes, password)
{
    encrypt := CryptBytes(bytes, password)
    count := AppendBytes(path, encrypt, 256)
    Return count
}

; 生成配置文件路径
GetConfigPath(name)
{
    Return configFolder . name . ".cy"
}

; 根据字符串数组读取配置文件并在 outObj 返回读取到的对象
; 返回值表示密码是否正确
ReadConfigFiles(manifest, password, ByRef outObj, default)
{
    contents := {}
    ok := True
    for _, configName in manifest
    {
        path := GetConfigPath(configName)
        jsonStr := ReadCryptedJsonString(path, password, default)
        If (!jsonStr)
        {
            ok := False
            Continue
        }

        contents[configName] := jsonStr
    }

    outObj := contents
    Return ok
}

CleanUnregistereds(manifest)
{
    Loop, Files, %configFolder%*.*
    {
        ; 检查是否是文件而不是目录
        if InStr(FileExist(configFolder . A_LoopFileName), "D")
            continue

        fileName := StrSplit(A_LoopFileName, ".")[1]
        isInManifest := False

        for _, configName in manifest {
            if (configName == fileName)
            {
                isInManifest := True
                break
            }
        }

        if (!isInManifest) ; 删除未注册的文件
            FileDelete, %configFolder%%A_LoopFileName%
    }
}