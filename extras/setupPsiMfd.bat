@echo off
rem setupPsiMfd.bat: sets up the keys for psi_autocast and psi_autocast_mfd in the Remaster's user.bnd, using keys that are free.
rem   - starter keys:  G and J run Macro_g.cmd / Macro_j.cmd holding psi_autocast's two starter casts (as starterPsiPowers.bat does)
rem   - an open key:   bind <key> "summon_obj PsiMfd"
rem   - macro keys:    bind <key> "run user:/psi_macros\Macro_<key>.cmd"   (every free key in the list below)
rem   - keypad +:      reserved for psi_autocast's cancel key (bind keypad_plus "run psi\actions\Cancel_Macro.txt")
rem A key counts as free when user.bnd has no plain binding for it. Free keys are used without asking.
rem A bound key is offered (y/n, one at a time) only when the game's defaults don't bind it and its command is also on
rem another keyboard or mouse binding, so answering y never loses a command. No other binding is ever changed.
rem The mouse wheel is never a macro key; it asks (y/n) before binding it to scroll the MFD. Backs up user.bnd before changing it. Run it with the game closed. Running it again adds only what's missing.
setlocal EnableDelayedExpansion

rem Plain single keys only, in order: letters, digits, F-keys, then keypad and navigation keys, then keypad numbers and arrows. Never Enter, Esc, Tab, Space, Backspace, the console key, modifiers,
rem Print Screen, Scroll Lock or Pause, and not ` - =. The punctuation keys , . / ; ' [ ] \ are listed by word (comma, ...):
rem , ; = split a batch list, and / \ can't be in a file name; :key_of turns a word back into the key, and the
rem macro file keeps the word (Macro_comma.cmd), as the MFD expects.
rem keypad_star, keypad_minus and keypad_del are proven in game; the rest are names from the game's key table.
set "OPEN_CANDIDATES=keypad_star keypad_slash"
set "MACRO_CANDIDATES=a b c d e f g h i j k l m n o p q r s t u v w x y z 1 2 3 4 5 6 7 8 9 0 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 keypad_minus keypad_del keypad_ins keypad_center keypad_slash ins del home end pgup pgdn keypad_home keypad_up keypad_pgup keypad_left keypad_right keypad_end keypad_down keypad_pgdn up down left right comma period slash semicolon apostrophe lbracket rbracket backslash"
rem Every plain keyboard and mouse key the game binds by default (base.kpf, defaults\shock.bnd, game 1.3.4984). These are never offered for replacing.
set "DEFAULT_KEYS=' - 0 1 2 3 4 5 6 7 8 9 = \ ` a alt b backspace c ctrl d del down e esc f f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 h keypad_center keypad_down keypad_end keypad_home keypad_left keypad_pgdn keypad_pgup keypad_right keypad_up l left m mouse1 mouse2 mouse3 mouse_axisx mouse_axisy mouse_wheel_down mouse_wheel_up n o p pgdn pgup q r right s shift space tab u up w z"

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
set "NEW_BND=%BND%.mfd_new"
set "OFFERS=%BND%.mfd_offers"
type nul > "%NEW_BND%"
set ADDED=0
set "TAKEN= "
set "REPLACE_ARGS="

rem The open key: skip if one is already bound (the wheel lines also mention PsiMfd, so they're filtered out).
findstr /i /c:"summon_obj psimfd" "%BND%" | findstr /i /v /c:"psimfdwheel" >nul
if not errorlevel 1 (
    echo Open key: already set up.
) else (
    set "OPEN_KEY="
    for %%K in (%OPEN_CANDIDATES% %MACRO_CANDIDATES%) do (
        if not defined OPEN_KEY (
            call :key_of %%K
            call :is_free "!KEY!"
            if "!FREE!"=="1" set "OPEN_KEY=!KEY!"
        )
    )
    if defined OPEN_KEY (
        >> "%NEW_BND%" echo bind !OPEN_KEY! "summon_obj PsiMfd"
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
    >> "%NEW_BND%" echo bind keypad_plus "run psi\actions\Cancel_Macro.txt"
    set /a ADDED+=1
    echo Cancel key: keypad_plus
) else (
    findstr /i /b /c:"bind keypad_plus " "%BND%" | findstr /i /c:"cancel_macro" >nul
    if errorlevel 1 (
        echo Cancel key: keypad_plus already has another binding, left alone. psi_autocast's cancel is
        echo   run psi\actions\Cancel_Macro.txt  if you want it on a key.
    ) else (
        echo Cancel key: keypad_plus already set up.
    )
)

rem Starter psi keys, exactly as psi_autocast's starterPsiPowers.bat sets them: G and J, if free, run Macro_g.cmd and
rem Macro_j.cmd in psi_macros, each holding one line that runs the starter psi script, so the MFD can replace them
rem with macros. An existing Macro_g.cmd / Macro_j.cmd is kept.
rem If starterPsiPowers.bat already bound G or J (its exact lines), the key is upgraded to the macro version without
rem asking: the same cast, now editable in the MFD. Any other binding on G or J is left alone.
call :starter_key g "run psi\T1_Projected_Cryokinesis.txt" "T1_Projected_Cryokinesis."
if "!STARTED!"=="1" echo Starter key: g  casts Projected Cryokinesis, overloading it automatically.
call :starter_key j "run psi\chains\Starter_Localized_Pyrokinesis.txt" "chains\\Starter_Localized_Pyrokinesis."
if "!STARTED!"=="1" echo Starter key: j  casts Localized Pyrokinesis, then switches back to your previous weapon.

rem Macro keys: every free candidate. Keys already bound (to a macro or anything else) are skipped.
set MACROS=0
for %%K in (%MACRO_CANDIDATES%) do (
    call :key_of %%K
    call :is_free "!KEY!"
    if "!FREE!"=="1" (
        >> "%NEW_BND%" echo bind !KEY! "run user:/psi_macros\Macro_%%K.cmd"
        set "TAKEN=!TAKEN!!KEY! "
        set /a MACROS+=1
        set /a ADDED+=1
        echo Macro key: !KEY!
    )
)

rem Bound keys that can be given up without losing a command: not bound by the game's defaults, not one of these mods'
rem keys, and the same command is on another keyboard or mouse binding (gamepad bindings don't count; neither do other
rem offered keys, so saying y to all of them still leaves every command on a key). Output: key|word|command|other keys.
powershell -NoProfile -Command "$map=@{comma=',';period='.';slash='/';semicolon=';';apostrophe=[string][char]39;lbracket='[';rbracket=']';backslash='\'}; $word=@{}; $cand=@($env:MACRO_CANDIDATES -split ' ' | ForEach-Object { $k=$(if($map.ContainsKey($_)){$map[$_]}else{$_}); $word[$k]=$_; $k }); $def=$env:DEFAULT_KEYS -split ' '; $b=@{}; foreach($l in Get-Content -LiteralPath $env:BND){ $p=$l.Trim() -split '\s+',3; if($p.Count -eq 3 -and $p[0] -eq 'bind'){ $b[$p[1]]=$p[2].Trim() } }; $offer=@($cand | Where-Object { $b.ContainsKey($_) -and $def -notcontains $_ -and $b[$_] -notmatch 'psi_macros|summon_obj psimfd|cancel_macro' }); foreach($k in $offer){ $o=@($b.Keys | Where-Object { $_ -ne $k -and $_ -notlike 'joy*' -and $offer -notcontains $_ -and $b[$_] -eq $b[$k] } | Sort-Object); if($o.Count){ $k+'|'+$word[$k]+'|'+$b[$k]+'|'+($o -join ' ') } }" > "%OFFERS%" 2>nul
rem eol=|: the default eol is ; and would skip the line for the ; key.
for /f "usebackq eol=| tokens=1,2,3,* delims=|" %%A in ("%OFFERS%") do (
    set "ANSWER="
    set /p "ANSWER=Use %%A as a macro key? It runs %%C, which is also on %%D. (y/n) "
    if /i "!ANSWER!"=="y" (
        >> "%NEW_BND%" echo bind %%A "run user:/psi_macros\Macro_%%B.cmd"
        call :pattern_of "%%A"
        set "REPLACE_ARGS=!REPLACE_ARGS! /c:"bind !PAT! ""
        set /a MACROS+=1
        set /a ADDED+=1
        echo Macro key: %%A ^(replaces %%C^)
    )
)
del "%OFFERS%" 2>nul

rem The mouse wheel is never a macro key. It can scroll the MFD: PsiMfdWheel scrolls the table when the mouse is over
rem the open MFD and sends cycle_weapon itself everywhere else. Offered (y/n) only while both wheel lines are missing
rem or still the game's defaults; a wheel line with any other command is left alone.
call :wheel_state mouse_wheel_up 1
set "WHEEL_UP=!WS!"
call :wheel_state mouse_wheel_down -1
set "WHEEL_DOWN=!WS!"
if "!WHEEL_UP!!WHEEL_DOWN!"=="mfdmfd" (
    echo Mouse wheel: already scrolls the MFD.
) else if "!WHEEL_UP!"=="other" (
    echo Mouse wheel: has your own bindings, left alone.
) else if "!WHEEL_DOWN!"=="other" (
    echo Mouse wheel: has your own bindings, left alone.
) else (
    echo.
    echo The mouse wheel can scroll the MFD when the mouse is over it, and still switch weapons everywhere else.
    echo In a save without psi_autocast_mfd enabled, the wheel then won't switch weapons. To undo, put back:
    echo   bind mouse_wheel_up "cycle_weapon 1"
    echo   bind mouse_wheel_down "cycle_weapon -1"
    set "ANSWER="
    set /p "ANSWER=Bind the mouse wheel to scroll the MFD? (y/n) "
    if /i "!ANSWER!"=="y" (
        >> "%NEW_BND%" echo bind mouse_wheel_up "summon_obj PsiMfdWheelUp"
        >> "%NEW_BND%" echo bind mouse_wheel_down "summon_obj PsiMfdWheelDown"
        set "REPLACE_ARGS=!REPLACE_ARGS! /c:"bind mouse_wheel_up " /c:"bind mouse_wheel_down ""
        set /a ADDED+=1
        echo Mouse wheel: scrolls the MFD.
    )
)

for /f %%N in ('%SystemRoot%\System32\find.exe /c /i "user:/psi_macros" ^< "%BND%"') do set HAVE=%%N
if !MACROS!==0 (
    echo Macro keys: no new free keys; !HAVE! already set up.
) else (
    echo Macro keys: !MACROS! added, !HAVE! already set up.
)

if !ADDED!==0 (
    del "%NEW_BND%"
    echo.
    echo Nothing to add. user.bnd is unchanged.
    goto :end
)

rem The new user.bnd: the old lines without the bindings of keys being replaced, then the new lines.
rem Redirected input makes findstr end the last line with a newline even when the file doesn't.
rem (/i also avoids findstr's bug with several case-sensitive search strings of different lengths.)
if defined REPLACE_ARGS (
    findstr /i /v /b %REPLACE_ARGS% < "%BND%" > "%TMP_BND%"
) else (
    findstr "^" < "%BND%" > "%TMP_BND%"
)
type "%NEW_BND%" >> "%TMP_BND%"
del "%NEW_BND%"

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

rem :starter_key <key> "<file line>" "<starter file, as a findstr pattern>"  sets STARTED=1 when the key gets its starter
rem macro: because it was free, or because it had starterPsiPowers.bat's own binding (run psi\<starter file>).
:starter_key
set STARTED=0
call :is_free "%~1"
if "!FREE!"=="1" (
    call :starter_macro %~1 "%~2"
    set STARTED=1
    goto :eof
)
rem Two findstr calls, as in :wheel_state; \\ in a findstr /c: string matches one backslash.
findstr /i /b /c:"bind %~1 " "%BND%" | findstr /i /c:"run psi\\%~3" >nul || goto :eof
call :starter_macro %~1 "%~2"
set "REPLACE_ARGS=!REPLACE_ARGS! /c:"bind %~1 ""
set STARTED=1
goto :eof

rem :starter_macro <key> "<file line>"  binds key to its macro file and writes the file (that one line) unless it exists.
:starter_macro
>> "%NEW_BND%" echo bind %~1 "run user:/psi_macros\Macro_%~1.cmd"
set "TAKEN=!TAKEN!%~1 "
set /a ADDED+=1
if not exist "%BND_DIR%\psi_macros" mkdir "%BND_DIR%\psi_macros"
if exist "%BND_DIR%\psi_macros\Macro_%~1.cmd" goto :eof
> "%BND_DIR%\psi_macros\Macro_%~1.cmd" echo %~2
goto :eof

rem :key_of <candidate>  sets KEY to the key name in user.bnd: punctuation candidates are words.
:key_of
set "KEY=%~1"
if "%~1"=="comma" set "KEY=,"
if "%~1"=="period" set "KEY=."
if "%~1"=="slash" set "KEY=/"
if "%~1"=="semicolon" set "KEY=;"
if "%~1"=="apostrophe" set "KEY='"
if "%~1"=="lbracket" set "KEY=["
if "%~1"=="rbracket" set "KEY=]"
if "%~1"=="backslash" set "KEY=\"
goto :eof

rem :pattern_of "<key>"  sets PAT to the key as a findstr /c: string: findstr reads \ as an escape, so \ is \\.
:pattern_of
set "PAT=%~1"
if "%~1"=="\" set "PAT=\\"
goto :eof

rem :is_free "<key>"  sets FREE=1 when user.bnd has no plain binding for <key> and this run hasn't used it.
:is_free
set FREE=1
call :pattern_of "%~1"
findstr /i /b /c:"bind !PAT! " "%BND%" >nul
if not errorlevel 1 set FREE=0
if not "!TAKEN: %~1 =!"=="!TAKEN!" set FREE=0
goto :eof

rem :wheel_state <key> <direction>  sets WS to none, default (cycle_weapon <direction>), mfd (PsiMfdWheel) or other.
:wheel_state
set WS=none
findstr /i /b /c:"bind %~1 " "%BND%" >nul || goto :eof
set WS=other
rem Two findstr calls: a quote inside a findstr /c: string can't be escaped reliably from a batch file.
findstr /i /b /c:"bind %~1 " "%BND%" | findstr /i /c:"cycle_weapon %~2" >nul && set WS=default
findstr /i /b /c:"bind %~1 " "%BND%" | findstr /i /c:"summon_obj psimfdwheel" >nul && set WS=mfd
goto :eof

:end
echo.
pause
