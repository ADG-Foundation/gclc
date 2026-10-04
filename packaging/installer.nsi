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
    # Direct registry commands to the native 64-bit registry
    SetRegView 64

    SetOutPath "$INSTDIR"

    # Core files
    File "executable\gclc-gui.exe"
    File "executable\gclc.exe"
    File "app.ico"

    # Documentation and license files
    File /nonfatal "README.md"
    File /nonfatal "LICENSE.md"
    File /nonfatal "gclc_man.pdf"

    # Recursive directory inclusions
    File /nonfatal /r "samples"
    File /nonfatal /r "working_example"
    File /nonfatal /r "LaTeX_packages"
    File /nonfatal /r "XML_support"

    # Uninstaller generation
    WriteUninstaller "$INSTDIR\uninstall.exe"

    # Store installation folder for updates / installer detection
    WriteRegStr HKLM "Software\GCLC" "Install_Dir" "$INSTDIR"

    # Shortcuts
    CreateDirectory "$SMPROGRAMS\GCLC"
    CreateShortcut "$SMPROGRAMS\GCLC\GCLC.lnk" "$INSTDIR\gclc-gui.exe" "" "$INSTDIR\app.ico"
    CreateShortcut "$SMPROGRAMS\GCLC\Manual.lnk" "$INSTDIR\gclc_man.pdf"

    # Add to Windows Add/Remove Programs
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\GCLC" "DisplayName" "GCLC"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\GCLC" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\GCLC" "DisplayIcon" "$INSTDIR\gclc-gui.exe"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\GCLC" "Publisher" "ADG Foundation"
SectionEnd

# Uninstaller section
Section "Uninstall"
    SetRegView 64

    # Remove files
    Delete "$INSTDIR\gclc-gui.exe"
    Delete "$INSTDIR\gclc.exe"
    Delete "$INSTDIR\app.ico"
    Delete "$INSTDIR\README.md"
    Delete "$INSTDIR\LICENSE.md"
    Delete "$INSTDIR\gclc_man.pdf"

    # Remove directories recursively
    RMDir /r "$INSTDIR\samples"
    RMDir /r "$INSTDIR\working_example"
    RMDir /r "$INSTDIR\LaTeX_packages"
    RMDir /r "$INSTDIR\XML_support"

    # Shortcuts
    Delete "$SMPROGRAMS\GCLC\GCLC.lnk"
    Delete "$SMPROGRAMS\GCLC\Manual.lnk"
    RMDir "$SMPROGRAMS\GCLC"

    # Remove uninstaller and install dir
    Delete "$INSTDIR\uninstall.exe"
    RMDir "$INSTDIR"

    # Clean up registry
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\GCLC"
    DeleteRegKey HKLM "Software\GCLC"
SectionEnd