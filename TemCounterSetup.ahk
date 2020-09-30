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
        RegWrite, Reg_SZ, %UninstallRegKey%, Publisher, Andrew „Tybalt“ Gardner
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
gender_icon = assets\gender.png
luma_icon = assets\luma.png
transition = assets\black.png

if (!FileExist("assets\")) {
    FileCreateDir, assets
    FileInstall, assets\uninstall.ico, %A_WorkingDir%\assets\uninstall.ico,1
    FileInstall, assets\gender.png, %A_WorkingDir%\%gender_icon%,1
    FileInstall, assets\luma.png, %A_WorkingDir%\%luma_icon%,1
    FileInstall, assets\black.png, %A_WorkingDir%\%transition%,1
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
right_encounter := new Rectangle(Floor(0.8203 * A_ScreenWidth), Floor(0.0795 * A_ScreenHeight), Floor(0.9667 * A_ScreenWidth), Floor(0.1454 * A_ScreenHeight))
left_encounter := new Rectangle(Floor(0.612 * A_ScreenWidth), Floor(0.0285 * A_ScreenHeight), Floor(0.7526 * A_ScreenWidth), Floor(0.0954 * A_ScreenHeight))

right_luma := false
left_luma := false
encounter := false
loop
{
    Process, Exist, Temtem.exe
    if (!ErrorLevel || !WinActive("Temtem"))
        continue

    if (!encounter && (ImageInRectangle(gender_icon, right_encounter))) { ; do we have an encounter on the right?
        encounter := true
        
        if (ImageInRectangle(gender_icon, left_encounter)) { ; do we have an encounter on the left?
            WriteOutput("encounter_session", encounter_prefix_session, encounter_suffix_session, 2)
            WriteOutput("encounter_total", encounter_prefix_total, encounter_suffix_total, 2)
        } else {
            WriteOutput("encounter_session", encounter_prefix_session, encounter_suffix_session, 1)
            WriteOutput("encounter_total", encounter_prefix_total, encounter_suffix_total, 1)
        }

    } else if (encounter) { ; while inside an encounter.
    
        if (!right_luma && ImageInRectangle(luma_icon, right_encounter)) { ; is right encounter a luma?
            right_luma := true
            WriteOutput("luma_encounter", luma_prefix, luma_suffix, 1)
        }
        
        if (!left_luma && ImageInRectangle(luma_icon, left_encounter)) { ; is left encounter a luma?
            left_luma := true
            WriteOutput("luma_encounter", luma_prefix, luma_suffix, 1)
        }

        if (ImageInRectangle(transition, left_encounter) && ImageInRectangle(transition, right_encounter)) { ; exiting transition.
            encounter := false
            right_luma := false
            left_luma := false
        }
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
ImageInRectangle(ByRef image, ByRef bounds)
{
    ImageSearch, Px, Py, bounds.X, bounds.Y, bounds.W, bounds.H, *4 %image%
    if (!ErrorLevel)
        return true
    return false
}