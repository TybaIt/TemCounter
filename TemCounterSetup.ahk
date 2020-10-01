;MIT License

;Copyright (c) 2020 Andreas Gärtner

;Permission is hereby granted, free of charge, to any person obtaining a copy
;of this software and associated documentation files (the "Software"), to deal
;in the Software without restriction, including without limitation the rights
;to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;copies of the Software, and to permit persons to whom the Software is
;furnished to do so, subject to the following conditions:

;The above copyright notice and this permission notice shall be included in all
;copies or substantial portions of the Software.

;THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;SOFTWARE.
;##############################################################################
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Enable warnings to assist with detecting common errors.
#SingleInstance force
SetWorkingDir %A_ScriptDir% ; Ensures a consistent starting directory.
CoordMode, Pixel ; Interprets the coordinates below as relative to the screen rather than the active window.
FileEncoding, UTF-8
InstallName = TemCounter

; If the script is not elevated, relaunch as administrator and kill current instance:

full_command_line := DllCall("GetCommandLine", "str")

if not (A_IsAdmin or RegExMatch(full_command_line, " /restart(?!\S)"))
{
    try ; leads to having the script re-launching itself as administrator
    {
        if A_IsCompiled
            Run *RunAs "%A_ScriptFullPath%" /restart
        else
            Run *RunAs "%A_AhkPath%" /restart "%A_ScriptFullPath%"
    }
    ExitApp
}


; #### Find Temtem Install ####
RegRead, TemtemInstallDir, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 745920, InstallLocation
if (!FileExist(TemtemInstallDir . "\Temtem.exe")) {
    ; Manual search for users who forcibly moved install directory ie. not cleanly reinstalled (CLSID -> My Computer).
    FileSelectFolder, SelectedPath,::{20d04fe0-3aea-1069-a2d8-08002b30309d},0, %InstallName% was unable to find Temtem at the location indicated by its registry entry. Did you move it without reinstalling? Manually locate and select your Temtem install directory and %InstallName% will fix its registry entry for you.
    if (ErrorLevel)
        exit
    if (FileExist(TemtemInstallDir . "\Temtem.exe")) {
        ; Fix up the registry for the user if Temtem install directory was selected in the dialogue.
        RegWrite, REG_SZ, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 745920, InstallLocation, SelectedPath
        TemtemInstallDir = SelectedPath
    } else {
        MsgBox, %InstallName% was unable to locate Temtem.exe in the selected folder. Some functionality of %InstallName% requires the Temtem executable to be locatable and therefore will not work.
    }
}
if (A_IsCompiled) {

    UninstallRegKey = HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%InstallName%
    RegRead, InstallDir, %UninstallRegKey%, InstallLocation
    
    ; #### Installation ####
    if (InstallDir != A_WorkingDir) {

        ; Select new install directory if there is no previous installation.
        if (!FileExist(InstallDir . "\" . InstallName . ".exe")) {
            FileSelectFolder, SelectedPath,::{20d04fe0-3aea-1069-a2d8-08002b30309d},0, Select the folder inwich the root directory of %InstallName% should be placed.
            if (!ErrorLevel) {
                InstallDir = %SelectedPath%\%InstallName%
            } else {
                exit
            }   
        } else if (FileExist(InstallDir . "\Uninstall_" . InstallName . ".bat")) {
        
            MsgBox, The %InstallName% setup has found an existing %InstallName% installation and will try to update it.
            
            ; Close running instances.
            Process, Exist, %InstallName%.exe
            if (ErrorLevel) {
                Process, Close, %InstallName%.exe
            }
            
            RunWait, *RunAs %InstallDir%\Uninstall_%InstallName%.bat, %OldInstallDir%
        }
        
        if (!FileExist(InstallDir . "\"))
            FileCreateDir, %InstallDir%
                    
        ; Create/Update Uninstall Registry
        RegWrite, Reg_SZ, %UninstallRegKey%
        RegWrite, Reg_SZ, %UninstallRegKey%, DisplayName, %InstallName%
        RegWrite, Reg_SZ, %UninstallRegKey%, DisplayIcon, %InstallDir%\assets\uninstall.ico
        RegWrite, Reg_SZ, %UninstallRegKey%, HelpLink, https://www.playtemtem.com/forums/
        RegWrite, Reg_SZ, %UninstallRegKey%, InstallLocation, %InstallDir%
        RegWrite, Reg_DWORD, %UninstallRegKey%, NoModify, 1
        RegWrite, Reg_DWORD, %UninstallRegKey%, NoRepair, 1
        RegWrite, Reg_SZ, %UninstallRegKey%, Publisher, Andreas „Tybalt“ Gärtner
        RegWrite, Reg_SZ, %UninstallRegKey%, UninstallString, %InstallDir%\Uninstall_%InstallName%.bat
        RegWrite, Reg_SZ, %UninstallRegKey%, URLInfoAbout, https://crema.gg/games/temtem/
        RegWrite, Reg_SZ, %UninstallRegKey%, Contact, https://www.playtemtem.com/forums/members/tybalt.3133/
        FileCreateShortcut, %InstallDir%\%InstallName%.exe, %A_Desktop%\%InstallName%.lnk, %InstallDir%      
    
        ; Build temporary install batch which self destructs when finished.
        FileAppend,
        (
            @echo off
            ping localhost -n 1 -w 500>nul
            move "%A_ScriptDir%\%A_ScriptName%" "%InstallDir%\%InstallName%.exe"
            start "" "%InstallDir%\%InstallName%.exe"
            `(goto`) 2>nul & del "`%~f0"
        ), %InstallDir%\temp_install_%InstallName%.bat
        FileSetAttrib +T, %InstallDir%\temp_install_%InstallName%.bat

        ; Build Uninstall batch.
        FileAppend,
        (
            @echo off
            SETLOCAL EnableExtensions
            taskkill /im %InstallName%.exe /f
            del "%A_Desktop%\%InstallName%.lnk" /s /f /q
            reg delete %UninstallRegKey% /f
            rmdir %InstallDir% /s /q
            `(goto`) 2>nul & del "`%~f0"
            exit
        ), %InstallDir%\Uninstall_%InstallName%.bat
        FileSetAttrib +HT, %InstallDir%\Uninstall_%InstallName%.bat
        
        ; Run install batch and close this instance. The batch will run a new instance from the install directory.
        Run, %InstallDir%\temp_install_%InstallName%.bat, %InstallDir%
        exit
    }
}

; #### Create Settings ####
if (!FileExist("config.ini")) {
    IniWrite, false, config.ini, GENERAL, launch_temtem
    
    IniWrite, "Total Encounters: ", config.ini, ENCOUNTER, total_prefix
    IniWrite, "", config.ini, ENCOUNTER, total_suffix

    IniWrite, "Session Encounters: ", config.ini, ENCOUNTER, session_prefix
    IniWrite, "", config.ini, ENCOUNTER, session_suffix

    IniWrite, "Lumas: ", config.ini, LUMA, prefix
    IniWrite, "", config.ini, LUMA, suffix
    IniWrite, false, config.ini, LUMA, single_session
}

; #### Load Settings ####
IniRead, launch_temtem, config.ini, GENERAL, launch_temtem

IniRead, encounter_prefix_total, config.ini, ENCOUNTER, total_prefix
IniRead, encounter_suffix_total, config.ini, ENCOUNTER, total_suffix

IniRead, encounter_prefix_session, config.ini, ENCOUNTER, session_prefix
IniRead, encounter_suffix_session, config.ini, ENCOUNTER, session_suffix

IniRead, luma_prefix, config.ini, LUMA, prefix
IniRead, luma_suffix, config.ini, LUMA, suffix
IniRead, luma_reset, config.ini, LUMA, single_session

; #### Assets ####
luma_icon = assets\luma.png

if (!FileExist("assets\")) {
    FileCreateDir, assets
    FileInstall, assets\uninstall.ico, %A_WorkingDir%\assets\uninstall.ico,1
    FileInstall, assets\luma.png, %A_WorkingDir%\%luma_icon%,1
    FileInstall, assets\confirm.wav, %A_WorkingDir%\assets\confirm.wav,1
    FileInstall, assets\install.wav, %A_WorkingDir%\assets\install.wav,1
    SoundPlay, assets\install.wav
    MsgBox, %InstallName% has been succefully installed and a shortcut has been created on your desktop.`n`nTo uninstall`, go to Settings > Apps > Apps & features, select %InstallName% from the list and click uninstall.
} else {
    SoundPlay, assets\confirm.wav
}

; #### Create Output Files ####
if (!FileExist("out\")) {
    FileCreateDir, out
    FileAppend,%encounter_prefix_total%0%encounter_suffix_total%, out\encounter_total.txt
    FileAppend,%encounter_prefix_session%0%encounter_suffix_session%, out\encounter_session.txt
    FileAppend,%luma_prefix%0%luma_suffix%, out\luma_encounter.txt
} else {
    FileDelete, out\encounter_session.txt
    if (%luma_reset%)
        FileDelete, out\luma_encounter.txt
}

; #### Script #####
if (%launch_temtem%) {
    Process, Exist, Temtem.exe
    if (!ErrorLevel && FileExist(TemtemInstallDir . "\Temtem.exe"))
        Run, %TemtemInstallDir%\Temtem.exe, TemtemInstallDir
}


class Rectangle {
    __New(X, Y, W, H) {
        this.X := X, this.Y := Y, this.W := W, this.H := H
    }
}


class Point {
    __New(X,Y) {
        this.X := X, this.Y := Y
    }
}


right_luma := false
left_luma := false
encounter := false
loop
{
    Process, Exist, Temtem.exe
    if (WinActive("Temtem")) continue
    
    if (!encounter && InBattle()) { ; only check for in-battle if we are out-of-battle.
    
        if (LeftEncounter()) {
            encounter := true
            WriteOutput("encounter_session", encounter_prefix_session, encounter_suffix_session, 2)
            WriteOutput("encounter_total", encounter_prefix_total, encounter_suffix_total, 2)
        } else {
            encounter := true
            WriteOutput("encounter_session", encounter_prefix_session, encounter_suffix_session, 1)
            WriteOutput("encounter_total", encounter_prefix_total, encounter_suffix_total, 1)
        }
        
        WinGetPos, X, Y, Width, Height, A
        
        leftFrame := new Rectangle(0.6 * X, 0.02 * Y, 0.13 * Width, 0.04 * Height)
        rightFrame := new Rectangle(0.81 * X, 0.07 * Y, 0.13 * Width, 0.04 * Height) 
        
        if (!right_luma && ImageInRectangle(luma_icon, rightFrame)) { ; is right encounter a luma?
            right_luma := true
            WriteOutput("luma_encounter", luma_prefix, luma_suffix, 1)
        }
  
        if (!left_luma && ImageInRectangle(luma_icon, leftFrame)) { ; is left encounter a luma?
            left_luma := true
            WriteOutput("luma_encounter", luma_prefix, luma_suffix, 1)
        }
        
    } else if (encounter && OutOfBattle()) { ; only check for out-of-battle if we are in-battle.
    
        encounter := false
        left_luma := false
        right_luma := false
        
    }
}


WriteOutput(ByRef fileName, ByRef prefix, ByRef suffix, ByRef incr)
{
    if (!FileExist("out\"))
        FileCreateDir, out
    try {
        file := FileOpen("out\" . fileName . ".txt", "rw") ; read/write - create new  if no existo
        if (IsObject(file)) {
            content := file.Read()
            counter := RegExReplace(content, "\D")
            if (!counter)
                counter = 0
            newText := prefix . counter + incr . suffix
            file.Seek(0), file.Write(newText), file.length := StrLen(newText)
            file.Close()
        }
    } catch e {
        MsgBox, An exception occured at line %A_LineNumber%!`n%A_ScriptName% will now exit.`nError: %e%
        exit
    }
}


ToRGB(color) {
    return { "r": (color >> 16) & 0xFF, "g": (color >> 8) & 0xFF, "b": color & 0xFF }
}


Compare(c1, c2, vary=500) {
    r1 := c1.r
    g1 := c1.g
    b1 := c1.b

    r2 := c2.r
    g2 := c2.g
    b2 := c2.b
    distance := ((r1 - r2) ** 2) + ((g1 - g2) ** 2) + ((b1 - b2) ** 2)
    return distance <= vary
}


ImageInRectangle(ByRef image, ByRef bounds)
{
    ImageSearch, Px, Py, bounds.X, bounds.Y, bounds.W, bounds.H, *4 %image%
    if (!ErrorLevel)
        return true
    return false
}


InBattle()
{
    WinGetPos, X, Y, Width, Height, A
    spot1 := new Point(X + 0.42 * Width, Y + 0.837 * Height) ; 0xFFA732
    spot2 := new Point(X + 0.42 * Width, Y + 0.915 * Height) ; 0x1BD1D4
    spot3 := new Point(X + 0.45 * Width, Y + 0.837 * Height) ; 0xFFA732
    spot4 := new Point(X + 0.45 * Width, Y + 0.915 * Height) ; 0x1BD1D4
    
    PixelGetColor, pixelColor1, spot1.X, spot1.Y, RGB
    pixelColor1 := ToRGB(pixelColor1)
    
    if (!Compare(pixelColor1, ToRGB(0xFFA732))) return false
    
    PixelGetColor, pixelColor2, spot2.X, spot2.Y, RGB
    pixelColor2 := ToRGB(pixelColor2)
    
    if (!Compare(pixelColor2, ToRGB(0x1BD1D4))) return false
    
    PixelGetColor, pixelColor3, spot3.X, spot3.Y, RGB
    pixelColor3 := ToRGB(pixelColor3)
    
    if (!Compare(pixelColor3, ToRGB(0xFFA732))) return false
    
    PixelGetColor, pixelColor4, spot4.X, spot4.Y, RGB
    pixelColor4 := ToRGB(pixelColor4)
    
    if (!Compare(pixelColor4, ToRGB(0x1BD1D4))) return false
    
    return true
}


OutOfBattle() 
{
    WinGetPos, X, Y, Width, Height, A
    spot1 := new Point(X + 0.918 * Width, Y + 0.245 * Height) ; 0x3CE8EA
    spot2 := new Point(X + 0.977 * Width, Y + 0.143 * Height) ; 0x3CE8EA
    spot3 := new Point(X + 0.8974 * Width, Y + 0.0491 * Height) ; 0x3CE8EA
    spot4 := new Point(X + 0.8745 * Width, Y + 0.2083 * Height) ; 0x3CE8EA
    
    PixelGetColor, pixelColor1, spot1.X, spot1.Y, RGB
    pixelColor1 := ToRGB(pixelColor1)
    
    if (!Compare(pixelColor1, ToRGB(0x3CE8EA))) return false
    
    PixelGetColor, pixelColor2, spot2.X, spot2.Y, RGB
    pixelColor2 := ToRGB(pixelColor2)
    
    if (!Compare(pixelColor2, ToRGB(0x3CE8EA))) return false
    
    PixelGetColor, pixelColor3, spot3.X, spot3.Y, RGB
    pixelColor3 := ToRGB(pixelColor3)
    
    if (!Compare(pixelColor3, ToRGB(0x3CE8EA))) return false
    
    PixelGetColor, pixelColor4, spot4.X, spot4.Y, RGB
    pixelColor4 := ToRGB(pixelColor4)
    
    if (!Compare(pixelColor4, ToRGB(0x3CE8EA))) return false
    
    return true
}
LeftEncounter() 
{
    WinGetPos, X, Y, Width, Height, A
    spot1 := new Point(X + 0.60859375 * Width, Y + 0.0875 * Height) ; 0x1E1E1E
    spot2 := new Point(X + 0.6203125 * Width, Y + 0.0791666666666667 * Height) ; 0x1CD1D3
    spot3 := new Point(X + 0.6234375 * Width, Y + 0.0638888888888889 * Height) ; 0x86C249
    spot4 := new Point(X + 0.7265625 * Width, Y + 0.0527777777777778 * Height) ; 0x1E1E1E
    
    PixelGetColor, pixelColor1, spot1.X, spot1.Y, RGB
    pixelColor1 := ToRGB(pixelColor1)
    
    if (!Compare(pixelColor1, ToRGB(0x1E1E1E))) return false
    
    PixelGetColor, pixelColor2, spot2.X, spot2.Y, RGB
    pixelColor2 := ToRGB(pixelColor2)
    
    if (!Compare(pixelColor2, ToRGB(0x1CD1D3))) return false
    
    PixelGetColor, pixelColor3, spot3.X, spot3.Y, RGB
    pixelColor3 := ToRGB(pixelColor3)
    
    if (!Compare(pixelColor3, ToRGB(0x86C249))) return false
    
    PixelGetColor, pixelColor4, spot4.X, spot4.Y, RGB
    pixelColor4 := ToRGB(pixelColor4)
    
    if (!Compare(pixelColor4, ToRGB(0x1E1E1E))) return false
    
    return true
}