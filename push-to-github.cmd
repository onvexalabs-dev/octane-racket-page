@echo off
setlocal DisableDelayedExpansion
cd /d "%~dp0"
if errorlevel 1 goto failed
for %%I in ("%~dp0..") do set "OR_PARENT=%%~fI"
echo Octane-Racket - Commit and push
 echo.
echo 1. Game repository
echo 2. Website repository
echo 3. Both repositories
echo 4. Cancel
choice /c 1234 /n /m "Choose [1-4]: "
if errorlevel 4 exit /b 0
if errorlevel 3 goto both
if errorlevel 2 goto website
call :publish "%OR_PARENT%\GODOT-Octane-Racket"
if errorlevel 1 goto failed
goto done
:website
call :publish "%OR_PARENT%\GODOT-Octane-Racket-Page"
if errorlevel 1 goto failed
goto done
:both
call :publish "%OR_PARENT%\GODOT-Octane-Racket"
if errorlevel 1 goto failed
call :publish "%OR_PARENT%\GODOT-Octane-Racket-Page"
if errorlevel 1 goto failed
:done
echo.
echo Finished.
pause
exit /b 0
:failed
echo.
echo Stopped because an operation failed. Read the message above.
echo No reset, force push, or automatic retry was performed.
pause
exit /b 1

:publish
setlocal DisableDelayedExpansion
pushd "%~1"
if errorlevel 1 exit /b 1
echo.
echo Repository: %~1
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 goto repo_failed
git remote get-url origin
if errorlevel 1 goto repo_failed
git symbolic-ref --quiet --short HEAD
if errorlevel 1 goto repo_failed
git status --short
if errorlevel 1 goto repo_failed
echo.
echo This stages ALL changes in this repository, commits, and pushes the current branch.
choice /c YN /n /m "Continue with this repository? [Y/N]: "
if errorlevel 2 goto repo_skipped
set "OR_COMMIT_MESSAGE="
set /p "OR_COMMIT_MESSAGE=Commit message (blank cancels this repository): "
if not defined OR_COMMIT_MESSAGE goto repo_skipped
set "OR_MESSAGE_FILE=%TEMP%\octane-racket-commit-%RANDOM%-%RANDOM%.txt"
powershell.exe -NoProfile -Command "$msg=$env:OR_COMMIT_MESSAGE; if ([string]::IsNullOrWhiteSpace($msg)) { exit 2 }; [System.IO.File]::WriteAllText($env:OR_MESSAGE_FILE, $msg, (New-Object System.Text.UTF8Encoding($false)))"
if errorlevel 1 goto repo_failed
git add --all
if errorlevel 1 goto repo_failed
git diff --cached --quiet
if errorlevel 2 goto repo_failed
if not errorlevel 1 goto push_existing
git commit --file "%OR_MESSAGE_FILE%"
if errorlevel 1 goto repo_failed
:push_existing
if exist "%OR_MESSAGE_FILE%" del /q "%OR_MESSAGE_FILE%"
git rev-parse --verify HEAD >nul 2>&1
if errorlevel 1 goto nothing_to_push
git push --set-upstream origin HEAD
if errorlevel 1 goto repo_failed
popd
endlocal
exit /b 0
:nothing_to_push
echo No commits exist yet. Nothing to push.
:repo_skipped
popd
endlocal
exit /b 0
:repo_failed
if defined OR_MESSAGE_FILE if exist "%OR_MESSAGE_FILE%" del /q "%OR_MESSAGE_FILE%"
popd
endlocal
exit /b 1