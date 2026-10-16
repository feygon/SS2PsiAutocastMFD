@echo off
rem setupPsiMfd.bat: sets up the psi_autocast_mfd keys in the Remaster's user.bnd, using keys that are free.
rem   - an open key:   bind <key> "summon_obj PsiMfd"
rem   - macro keys:    bind <key> "run user:/psi_macros\Macro_<key>.cmd"   (every free key in the list below)
rem   - keypad +:      reserved for psi_autocast's cancel key (bind keypad_plus "run psi\actions\Cancel_Macro.cmd")
rem A key counts as free when user.bnd has no plain binding for it; existing bindings are never changed.
rem The mouse wheel is left alone. Backs up user.bnd before changing it. Run it with the game closed. Running it again adds only what's missing.
setlocal EnableDelayedExpansion

rem Plain single keys only, in order: letters, digits, F-keys, then keypad and navigation keys. Never Enter, Esc, Tab, Space, Backspace, the console key, modifiers,
rem Print Screen, Scroll Lock or Pause. Punctuation is left out: , ; = split a batch list, and / can't be a file name.
rem keypad_star, keypad_minus and keypad_del are proven in game; the rest are names from the game's key table.
set "OPEN_CANDIDATES=keypad_star keypad_slash"
set "MACRO_CANDIDATES=a b c d e f g h i j k l m n o p q r s t u v w x y z 1 2 3 4 5 6 7 8 9 0 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 keypad_minus keypad_del keypad_ins keypad_center keypad_slash ins del home end pgup pgdn"

rem Windows tools are called so a Unix "find" on the PATH (Git for Windows puts one there) can't take over:
rem findstr has no Unix namesake, and find.exe is called by its full path.
tasklist /fi "imagename eq SystemShock2Remastered.exe" 2>nul | findstr /i /c:"SystemShock2Remastered.exe" >nul
if not errorlevel 1 (
    echo The game is running. Quit it first: it rewrites user.bnd when it exits, which would undo these bindings.
    goto :end
)

rem Find user.bnd. Saved Games is a Windows known folder that can be moved (its Properties, OneDrive, policy),
rem so %USERPROFILE%\Saved Games isn't always right. In order: a folder given on the command line, Windows' own
rem location for shell:SavedGames, the Shell Folders registry value, %USERPROFILE%\Saved Games, then ask.
set "GAME_SUBDIR=Nightdive Studios\System Shock 2 Remastered"
set "BND_DIR="
if not "%~1"=="" if exist "%~1\user.bnd" set "BND_DIR=%~1"
if not defined BND_DIR (
    for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "(New-Object -ComObject Shell.Application).Namespace('shell:SavedGames').Self.Path" 2^>nul`) do (
        if exist "%%P\%GAME_SUBDIR%\user.bnd" set "BND_DIR=%%P\%GAME_SUBDIR%"
    )
)
if not defined BND_DIR (
    for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "{4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4}" 2^>nul ^| findstr /c:"REG_"') do (
        if exist "%%B\%GAME_SUBDIR%\user.bnd" set "BND_DIR=%%B\%GAME_SUBDIR%"
    )
)
if not defined BND_DIR if exist "%USERPROFILE%\Saved Games\%GAME_SUBDIR%\user.bnd" set "BND_DIR=%USERPROFILE%\Saved Games\%GAME_SUBDIR%"
if not defined BND_DIR (
    echo Couldn't find user.bnd. It's in your Saved Games folder, under %GAME_SUBDIR%.
    echo If you've never started the game, start it once and quit, then run this again.
    set /p "BND_DIR=Or paste the folder that contains user.bnd here, then press Enter: "
)
if not defined BND_DIR goto :end
set "BND_DIR=%BND_DIR:"=%"
if not exist "%BND_DIR%\user.bnd" (
    echo There's no user.bnd in:
    echo   %BND_DIR%
    goto :end
)
set "BND=%BND_DIR%\user.bnd"
echo Using %BND%

set "TMP_BND=%BND%.mfd_tmp"
rem Redirected input makes findstr end the last line with a newline even when the file doesn't.
findstr "^" < "%BND%" > "%TMP_BND%"
set ADDED=0
set "TAKEN= "

rem The open key: skip if one is already bound (the wheel lines also mention PsiMfd, so they're filtered out).
findstr /i /c:"summon_obj psimfd" "%BND%" | findstr /i /v /c:"psimfdwheel" >nul
if not errorlevel 1 (
    echo Open key: already set up.
) else (
    set "OPEN_KEY="
    for %%K in (%OPEN_CANDIDATES% %MACRO_CANDIDATES%) do (
        if not defined OPEN_KEY (
            call :is_free %%K
            if "!FREE!"=="1" set "OPEN_KEY=%%K"
        )
    )
    if defined OPEN_KEY (
        >> "%TMP_BND%" echo bind !OPEN_KEY! "summon_obj PsiMfd"
        set "TAKEN=!TAKEN!!OPEN_KEY! "
        set /a ADDED+=1
        echo Open key: !OPEN_KEY!
    ) else (
        echo Open key: no free key found. Add one yourself: bind ^<key^> "summon_obj PsiMfd"
    )
)

rem Keypad + is psi_autocast's cancel key: bind it if it's free, never use it for anything else.
findstr /i /b /c:"bind keypad_plus " "%BND%" >nul
if errorlevel 1 (
    >> "%TMP_BND%" echo bind keypad_plus "run psi\actions\Cancel_Macro.cmd"
    set /a ADDED+=1
    echo Cancel key: keypad_plus
) else (
    findstr /i /b /c:"bind keypad_plus " "%BND%" | findstr /i /c:"cancel_macro" >nul
    if errorlevel 1 (
        echo Cancel key: keypad_plus already has another binding, left alone. psi_autocast's cancel is
        echo   run psi\actions\Cancel_Macro.cmd  if you want it on a key.
    ) else (
        echo Cancel key: keypad_plus already set up.
    )
)

rem Macro keys: every free candidate. Keys already bound (to a macro or anything else) are skipped.
set MACROS=0
for %%K in (%MACRO_CANDIDATES%) do (
    call :is_free %%K
    if "!FREE!"=="1" (
        >> "%TMP_BND%" echo bind %%K "run user:/psi_macros\Macro_%%K.cmd"
        set "TAKEN=!TAKEN!%%K "
        set /a MACROS+=1
        set /a ADDED+=1
        echo Macro key: %%K
    )
)
for /f %%N in ('%SystemRoot%\System32\find.exe /c /i "user:/psi_macros" ^< "%BND%"') do set HAVE=%%N
if !MACROS!==0 (
    echo Macro keys: no new free keys; !HAVE! already set up.
) else (
    echo Macro keys: !MACROS! added, !HAVE! already set up.
)

if !ADDED!==0 (
    del "%TMP_BND%"
    echo.
    echo Nothing to add. user.bnd is unchanged.
    goto :end
)

rem Back up to the first free user.bnd.before_mfd_N, so earlier backups are never overwritten.
set N=1
:find_backup
if exist "%BND%.before_mfd_%N%" (
    set /a N+=1
    goto :find_backup
)
copy /y "%BND%" "%BND%.before_mfd_%N%" >nul || (
    del "%TMP_BND%"
    echo Couldn't back up user.bnd. Nothing was changed.
    goto :end
)
move /y "%TMP_BND%" "%BND%" >nul || (
    echo Couldn't write user.bnd. It's unchanged; the backup is user.bnd.before_mfd_%N%.
    goto :end
)

echo.
echo Done. Backup: user.bnd.before_mfd_%N%
echo Enable psi_autocast and psi_autocast_mfd for your save, then press the open key with the mouse cursor up.
echo If a key does nothing, start and quit the game, then check user.bnd: if its line is gone, the game didn't accept that key.
goto :end

rem :is_free <key>  sets FREE=1 when user.bnd has no plain binding for <key> and this run hasn't used it.
:is_free
set FREE=1
findstr /i /b /c:"bind %~1 " "%BND%" >nul
if not errorlevel 1 set FREE=0
if not "!TAKEN: %~1 =!"=="!TAKEN!" set FREE=0
goto :eof

:end
echo.
pause
