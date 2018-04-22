; Wonder Boy: The Dragon's Trap Mod Launcher
; Version 1.0
;
; Copyright 2018 Mateus B. Cassiano
; Licensed under GPLv2+
; Refer to the license.txt file included.

; OVERVIEW / USAGE
; Compile this script with AutoIt v3 and place a copy of the binary inside exe32 and exe64 folders
; found in the install location of Wonder Boy: The Dragon's Trap. The original game binaries must
; be renamed to "wb.bkp.exe" (can be changed through a global variable defined below) and the
; compiled binary of this script must be renamed to "wb.exe".
;
; This mod launcher works only with the Steam or GOG editions of the game. It works by swapping the
; original "bin_pc" folder on the fly before launching the game if a different data directory is
; specified through the command line parameter --data-dir=<folder_name> (e.g. bin_pc_monica). The
; specified data directory must exist next to the original "bin_pc" folder, must not contain spaces
; on its name and must not be named "bin_pc.bkp". Once the game is closed, the original folder
; names and the original "bin_pc" folder are restored to their previous state.
;
; This launcher keeps track of the original folder name through a persistent file stored inside
; the selected data folder, so, in the case of an unexpected crash or system issue, it'll take care
; of this inconsistent state automagically the next time next time it's executed. If no --data-dir
; parameter is passed, it'll just run the game with their original data directly. Any other command
; line parameter specified	other than --data-dir=<folder_name> will be forwarded to the original
; game executable.

#NoTrayIcon
#include <MsgBoxConstants.au3>

#Region
#AutoIt3Wrapper_Icon=wb.ico
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_Res_Description=Wonder Boy: The Dragon's Trap Mod Launcher
#AutoIt3Wrapper_Res_Comment=Switch Wonder Boy: The Dragon's Trap resources folder on-the-fly through command line parameter --data-dir=<res_folder>
#AutoIt3Wrapper_Res_LegalCopyright=© 2018 Mateus B. Cassiano. All Rights Reserved.
#AutoIt3Wrapper_res_requestedExecutionLevel=asInvoker
#AutoIt3Wrapper_Res_ProductVersion=1.0.0.0
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_HiDpi=y
#EndRegion

;------------------
; Global Variables
;------------------
Global Const $g_sExeName = "wb.bkp.exe"
Global Const $g_sFullName = "Wonder Boy: The Dragon's Trap Mod Launcher"

; DO NOT remove "bin_pc.bkp" from the array, as it will break the back-up/restore functions.
Global Const $g_asReservedDirNames[4] = ["bin_pc.bkp", "exe32", "exe64", "_CommonRedist"]

Main()


;======
; Main
;------
; Start the launcher
Func Main()
	; $asLaunchData[0] store the passed data directory's name (or empty if not provided)
	; $asLaunchData[1] store the original command line without --data-dir parameter
	Local $asLaunchData = ParseCmdLine($CmdLineRaw)


	; Detect game edition and launch
	Switch DetectGameEdition()
		Case -1 ; Original executable wrongly named or not found
			ShowMessage(1)
			Exit 1

		Case 0 ; Game is Steam Edition
			; Check and restore folder names if necessary (but preserve "selected_dir.id")
			RestoreDataDir(True)
			LaunchSteamEdition($asLaunchData)

		Case 1 ; Game is GOG Edition
			; Check and restore folder names if necessary (but preserve "selected_dir.id")
			RestoreDataDir(True)
			LaunchGOGEdition($asLaunchData)

		Case Else ; Game edition not recognized
			ShowMessage(2)
			Exit 1

	EndSwitch

	Exit 0

EndFunc	  ;==>Main


;==============
; ParseCmdLine
;--------------
; Read --data-dir parameter from $sCmdLine (if present) and returns the value of
; it and the original command line without --data-dir parameter in an array
Func ParseCmdLine(Const ByRef $sCmdLine)
	Local $asResult[2]

	; Try to find --data-dir=<folder_name> in the Command Line. If found, use RegExp to filter
	; this parameter from the command line, otherwise just return the original command line
	$RegexResult = StringRegExp($sCmdLine, "\-\-data\-dir\=(\S+)", 1)
	If @error == 0 Then

		; Data directory was specified, store it in the first position of the array
		; and the filtered command line in the second position of the array
		$asResult[0] = $RegexResult[0]
		$asResult[1] = StringRegExpReplace($sCmdLine, "(.*)\-\-data\-dir\=\S+\s?(.*)", "$1$2")

	Else

		; Data directory wasn't specified, store an empty string in the first position of the array
		; and the original and untouched command line in the second position of the array
		$asResult[0] = ""
		$asResult[1] = $sCmdLine

	EndIf

	Return $asResult

EndFunc	  ;==>ParseCmdLine


;===================
; DetectGameEdition
;-------------------
; Checks the files inside the folder the launcher is placed and determine game edition
Func DetectGameEdition()
	Local $iResult

	; Check if GOG Galaxy DLLs are present. If yes, it's the GOG Edition
	If FileExists(".\Galaxy.dll") Or FileExists(".\Galaxy64.dll") Then
		$iResult = 1

	; Check if Steam API DLLs are present. If yes, it's the Steam Edition. This check MUST be done
	; only AFTER cheking the GOG Galaxy DLLs because the GOG Edition also ships with the Steam DLLs
	ElseIf FileExists(".\steam_api.dll") Or FileExists(".\steam_api64.dll") Then
		$iResult = 0

	EndIf

	; Original game executable not found or wrongly named. This check MUST be done AFTER the others
	; so it takes precedence, after all, without the original executable the game simply can't run
	If Not FileExists(".\" & $g_sExeName) Then
		$iResult = -1

	EndIf

	Return $iResult

EndFunc	  ;==>DetectGameEdition


;================
; IsDataDirValid
;----------------
; Check if the directory specified in $sDataDir exists and doesn't correspond to a reserved folder
; Also checks if the backup folder couldn't be automatically restored and exits if that's the case
Func IsDataDirValid(Const ByRef $sDataDir)
	Local $bResult

	; RestoreDataDir() should be called at least once before calling IsDataDirValid() and should
	; automatically rename the backup folder to its previous name. If despite this the backup
	; folder is still there, something really wrong happened, throw error and exit
	If DirGetSize("..\bin_pc.bkp") <> -1 Then
		ShowMessage(3)

		; Call RestoreDataDir() once more to ensure "selected_dir.id" is deleted before exiting
		RestoreDataDir(False)
		Exit 1

	EndIf

	; Check if the specified directory exists. If it doesn't, warn the user and call
	; RestoreDataDir(False) to ensure "selected_dir.id" is deleted before continuing
	If $sDataDir <> "" And DirGetSize("..\" & $sDataDir) <> -1 Then
		$bResult = True

	ElseIf $sDataDir <> "" Then
		ShowMessage(4, $sDataDir)
		RestoreDataDir()
		$bResult = False

	Else
		$bResult = False

	EndIf

	; Check if the specified directory doesn't match a reserved directory. If it does, warn the
	; user and call RestoreDataDir(False) to ensure "selected_dir.id" is deleted before continuing
	For $i = 0 To UBound($g_asReservedDirNames) - 1
		If $g_asReservedDirNames[$i] == $sDataDir Then
			ShowMessage(5, $sDataDir)
			RestoreDataDir()
			$bResult = False

		EndIf
	Next

	Return $bResult

EndFunc	  ;==>IsDataDirValid


;================
; PrepareDataDir
;----------------
; Renames the original "bin_pc" folder to "bin_pc.bkp" then assign this name to the selected data
; directory. Also saves the original folder name of the selected data directory in a hidden file
; so everything can be properly restored to the previous state by calling RestoreDataDir() later
Func PrepareDataDir(Const ByRef $sDataDir)

	; If the selected data directory is "bin_pc", there's nothing to do, just return
	If $sDataDir == "bin_pc" Then
		Return

	EndIf

	; If "bin_pc" already exists, rename it to "bin_pc.bkp"
	If DirGetSize("..\bin_pc") <> -1 Then
		DirMove("..\bin_pc", "..\bin_pc.bkp")

	EndIf

	; Rename the selected data directory to "bin_pc" and save its original name in a hidden file
	DirMove("..\" & $sDataDir, "..\bin_pc")
	FileWrite("..\bin_pc\data_dir.id", $sDataDir & @CRLF)
	FileSetAttrib("..\bin_pc\data_dir.id", "+SH")

	Return

EndFunc	  ;==>PrepareDataDir



;================
; RestoreDataDir
;----------------
; Restores the original name of the last selected data directory then renames "bin_pc.bkp" back
; to "bin_pc". The optional parameter controls whether "selected_dir.id" should also be deleted
Func RestoreDataDir(Const $bKeepSelectedDirID = False)

	; Check if the original name of the last selected data directory is available
	If FileExists("..\bin_pc\data_dir.id") Then

		; Read original folder name from the hidden file then delete it
		Local $sDataDir = FileReadLine("..\bin_pc\data_dir.id")
		FileSetAttrib("..\bin_pc\data_dir.id", "-SH")
		FileDelete("..\bin_pc\data_dir.id")

		; Rename "bin_pc" to its original folder name
		DirMove("..\bin_pc", "..\" & $sDataDir)

		; If "bin_pc.bkp" exists, rename it back to "bin_pc"
		If DirGetSize("..\bin_pc.bkp") <> -1 Then
			DirMove("..\bin_pc.bkp", "..\bin_pc")

		EndIf

	EndIf

	; Delete "selected_dir.id" if $bKeepSelectedDirID wasn't set to True when calling this function
	If Not $bKeepSelectedDirID Then
		FileSetAttrib("..\selected_dir.id", "-SH")
		FileDelete("..\selected_dir.id")

	EndIf

	Return

EndFunc	  ;==>RestoreDataDir



;====================
; LaunchSteamEdition
;--------------------
; Validate and prepare the specified data directory then launch the original Steam game executable
Func LaunchSteamEdition(ByRef $asLaunchData)

	; Create a hidden "selected_dir.id" file or open existing file and seek to initial position,
	; then (over)write the selected data directory name on it and close the file
	Local $hFileHandle = FileOpen("..\selected_dir.id", 2)
	FileWrite($hFileHandle, $asLaunchData[0] & @CRLF)
	FileClose($hFileHandle)
	FileSetAttrib("..\selected_dir.id", "+SH")

	; Check through registry if the Steam Client is reporting the game is running. If it's not,
	; Steam will likely relaunch this executable again (e.g. Steam was not running, the game was
	; started by another process or shortcut, etc), so just pass ahead the filtered command line
	If RegRead("HKCU\Software\Valve\Steam\Apps\543260", "Running") == 1 Then

		; Retrieve the selected data directory from the hidden file. This instance isn't guaranteed
		; to be the first (e.g. Steam Client likely relaunched this executable) so the --data-dir
		; parameter won't be available anymore because it was filtered by the first instace
		$asLaunchData[0] = FileReadLine("..\selected_dir.id")

		; Check if the specified data directory is valid and prepare it for the game
		If IsDataDirValid($asLaunchData[0]) Then
			PrepareDataDir($asLaunchData[0])

		EndIf

		; Finally, launch the original game executable with the filtered command line and wait
		; until it exits. Then, restore the original folder names and delete "selected_dir.id"
		RunWait($g_sExeName & " " & $asLaunchData[1])
		RestoreDataDir(False)

	Else

		; If we got there, Steam will relaunch this executable again.
		; Don't do anything, just forwards the filtered command line.
		RunWait($g_sExeName & " " & $asLaunchData[1])

	EndIf

	Return

EndFunc	  ;==>LaunchSteamEdition



;==================
; LaunchGOGEdition
;------------------
; Validate and prepare the specified data directory then launch the original GOG game executable
Func LaunchGOGEdition(Const ByRef $asLaunchData)

	; Check if the specified data directory is valid and prepare it for the game
	If IsDataDirValid($asLaunchData[0]) Then
		PrepareDataDir($asLaunchData[0])

	EndIf

	; Launch the original game executable with the filtered command line and wait until it exits.
	; Then, restore the original folder names and delete "selected_dir.id" if it exists
	RunWait($g_sExeName & " " & $asLaunchData[1])
	RestoreDataDir(False)

	Return

EndFunc	  ;==>LaunchGOGEdition



;=============
; ShowMessage
;-------------
; Display Message Boxes with predetermined error/warning messages and in some cases extra info
Func ShowMessage(Const $iMsgCode, Const $sMsgExtra = "")

	; Determine from $iMsgCode
	Switch $iMsgCode

		Case 1 ; Original executable wrongly named or not found
			MsgBox($MB_ICONERROR, $g_sFullName, "Couldn't find the original game executable [" _
					 & $g_sExeName & "]." & @CRLF & "Please make sure this launcher is placed on" _
					 & " the correct game folder, then try again.")

		Case 2 ; Unknown game edition
			MsgBox($MB_ICONERROR, $g_sFullName, "Couldn't determine the game edition." & @CRLF _
					 & "This launcher supports only the GOG and Steam editions.")

		Case 3 ; Inconsistent game folders (failed to recover automatically)
			MsgBox($MB_ICONERROR, $g_sFullName, "Couldn't restore the backup folder " _
					 & "automatically." & @CRLF & "Please check the contents of the install " _
					 & "folder, then try again.")

		Case 4 ; Selected data directory doesn't exist / couldn't be accessed
			MsgBox($MB_ICONWARNING, $g_sFullName, "The specified data directory [" & $sMsgExtra _
					 & "] doesn't exist." & @CRLF & "Launching the game with the default data " _
					 & "directory.")

		Case 5 ; Selected data directory name is reserved
			MsgBox($MB_ICONWARNING, $g_sFullName, "The specified data directory [" & $sMsgExtra _
					 & "] is reserved and can't be used." & @CRLF & "Launching the game with the" _
					 & " default data directory.")

	EndSwitch

	Return

EndFunc	  ;==>ShowMessage
