!include "MUI2.nsh"

# General attributes
Name "GCLC"
OutFile "GCLC-Setup.exe"
InstallDir "$PROGRAMFILES64\GCLC"
InstallDirRegKey HKLM "Software\GCLC" "Install_Dir"
RequestExecutionLevel admin

# UI Setup
!define MUI_ABORTWARNING
!define MUI_ICON "app.ico"
!define MUI_UNICON "app.ico"

# Pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

# Installation section
Section "GCLC Application" SecMain
  SetOutPath "$INSTDIR"

  # Bundle only the executables
  File "executable\gclc-gui.exe"
  File "executable\gclc.exe"

  # Write uninstaller
  WriteUninstaller "$INSTDIR\uninstall.exe"

  # Start Menu Shortcuts
  CreateDirectory "$SMPROGRAMS\GCLC"
  CreateShortcut "$SMPROGRAMS\GCLC\GCLC.lnk" "$INSTDIR\gclc-gui.exe"
  CreateShortcut "$SMPROGRAMS\GCLC\Uninstall GCLC.lnk" "$INSTDIR\uninstall.exe"

  # Add to Windows Add/Remove Programs
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\GCLC" "DisplayName" "GCLC"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\GCLC" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\GCLC" "DisplayIcon" "$INSTDIR\gclc-gui.exe"
SectionEnd

# Uninstaller section
Section "Uninstall"
  Delete "$INSTDIR\gclc-gui.exe"
  Delete "$INSTDIR\gclc.exe"
  Delete "$INSTDIR\uninstall.exe"

  Delete "$SMPROGRAMS\GCLC\GCLC.lnk"
  Delete "$SMPROGRAMS\GCLC\Uninstall GCLC.lnk"
  RMDir "$SMPROGRAMS\GCLC"

  RMDir "$INSTDIR"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\GCLC"
SectionEnd