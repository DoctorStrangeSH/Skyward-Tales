; Skyward Tales — Windows installer (NSIS 3). Built by .github/workflows/release.yml:
;   makensis -NOCD -DVERSION=0.3.0.123 -DSRC=build/windows -DOUT=build/SkywardTales-Setup.exe installer/skyward_tales.nsi
; Installs for the current user (no admin rights) into %LOCALAPPDATA%\Programs,
; adds Start menu and desktop shortcuts and an entry in "Apps & features".
; Saves live in %APPDATA%\Godot\app_userdata\Skyward Tales and survive
; uninstalling.

Unicode true
SetCompressor /SOLID lzma

!ifndef VERSION
  !define VERSION "dev"
!endif
!ifndef SRC
  !define SRC "build/windows"
!endif
!ifndef OUT
  !define OUT "build/SkywardTales-Setup.exe"
!endif

!define APP "Skyward Tales"
!define EXE "SkywardTales.exe"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\SkywardTales"

Name "${APP}"
OutFile "${OUT}"
InstallDir "$LOCALAPPDATA\Programs\Skyward Tales"
InstallDirRegKey HKCU "Software\SkywardTales" "InstallDir"
RequestExecutionLevel user
BrandingText "${APP} ${VERSION}"

!include "MUI2.nsh"
!define MUI_ICON "installer/icon.ico"
!define MUI_UNICON "installer/icon.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Запустить Skyward Tales"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Russian"

VIProductVersion "0.0.0.0"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "ProductName" "${APP}"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "FileDescription" "Установщик ${APP}"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "ProductVersion" "${VERSION}"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "LegalCopyright" "Skyward Tales"

Section "Skyward Tales" SecGame
  SectionIn RO
  SetOutPath "$INSTDIR"
  File /r "${SRC}/*.*"
  File "/oname=icon.ico" "installer/icon.ico"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${APP}"
  CreateShortcut "$SMPROGRAMS\${APP}\${APP}.lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\icon.ico"
  CreateShortcut "$SMPROGRAMS\${APP}\Удалить ${APP}.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\${APP}.lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\icon.ico"

  WriteRegStr HKCU "Software\SkywardTales" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${APP}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "Skyward Tales"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\icon.ico"
  WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  ; Only our own files: the folder may hold something the player put there.
  Delete "$INSTDIR\${EXE}"
  Delete "$INSTDIR\SkywardTales.pck"
  Delete "$INSTDIR\README.txt"
  Delete "$INSTDIR\icon.ico"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\${APP}\${APP}.lnk"
  Delete "$SMPROGRAMS\${APP}\Удалить ${APP}.lnk"
  RMDir "$SMPROGRAMS\${APP}"
  Delete "$DESKTOP\${APP}.lnk"
  DeleteRegKey HKCU "${UNINST_KEY}"
  DeleteRegKey HKCU "Software\SkywardTales"
SectionEnd
