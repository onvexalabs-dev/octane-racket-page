param(
    [ValidateSet('Game','Website','Both')][string]$Repository,
    [string]$CommitMessage,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$NoPause
)
$ErrorActionPreference = 'Stop'
$exitCode = 0

function Invoke-Git {
    param([string[]]$GitArguments)
    & git @GitArguments
    if ($LASTEXITCODE -ne 0) { throw "Git failed (exit $LASTEXITCODE): git $($GitArguments -join ' ')" }
}

try {
    Get-Command git -ErrorAction Stop | Out-Null
    Write-Host "`nOctane-Racket - Commit and push`n" -ForegroundColor Cyan
    if (!$Repository) {
        Write-Host '1. Game repository'
        Write-Host '2. Website repository'
        Write-Host '3. Both repositories'
        Write-Host '4. Cancel'
        switch (Read-Host 'Choose 1, 2, 3 or 4') {
            '1' { $Repository = 'Game' }
            '2' { $Repository = 'Website' }
            '3' { $Repository = 'Both' }
            '4' { Write-Host 'Cancelled. Nothing was uploaded.'; return }
            default { throw 'Invalid selection. Run the helper again and choose 1, 2, 3 or 4.' }
        }
    }
    $names = @()
    if ($Repository -in @('Game','Both')) { $names += 'GODOT-Octane-Racket' }
    if ($Repository -in @('Website','Both')) { $names += 'GODOT-Octane-Racket-Page' }
    $repos = foreach ($name in $names) {
        $path = Join-Path $RepositoryRoot $name
        if (!(Test-Path -LiteralPath (Join-Path $path '.git'))) { throw "Repository not found: $path" }
        $remote = Invoke-Git -GitArguments @('-C',$path,'remote','get-url','origin')
        $branch = Invoke-Git -GitArguments @('-C',$path,'symbolic-ref','--quiet','--short','HEAD')
        Write-Host "`nRepository: $path`nGitHub destination: $remote`nBranch: $branch" -ForegroundColor Cyan
        Invoke-Git -GitArguments @('-C',$path,'status','--short') | Out-Host
        if ($name -eq 'GODOT-Octane-Racket-Page' -and !(Test-Path -LiteralPath (Join-Path $path 'index.html'))) {
            Write-Host 'This folder has no index.html. Pushing it will not create a website.' -ForegroundColor Yellow
        }
        [pscustomobject]@{ Path=$path; Branch=[string]$branch; Name=$name }
    }
    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        Write-Host "`nAll non-ignored changes in the selected repositories will be committed and pushed."
        $CommitMessage = Read-Host 'Commit message (leave blank to cancel)'
    }
    if ([string]::IsNullOrWhiteSpace($CommitMessage)) { Write-Host 'Cancelled. Nothing was uploaded.'; return }
    $messageFile = Join-Path ([System.IO.Path]::GetTempPath()) ('octane-racket-' + [guid]::NewGuid().ToString('N') + '.txt')
    try {
        [System.IO.File]::WriteAllText($messageFile,$CommitMessage,(New-Object System.Text.UTF8Encoding($false)))
        foreach ($repo in $repos) {
            Write-Host "`nPublishing $($repo.Name)..." -ForegroundColor Cyan
            $candidates = Invoke-Git -GitArguments @('-C',$repo.Path,'-c','core.quotepath=false','ls-files','--cached','--others','--exclude-standard')
            foreach ($relative in $candidates) {
                $candidate = Join-Path $repo.Path $relative
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    if ((Get-Item -LiteralPath $candidate).Length -gt 100MB) {
                        throw "File exceeds GitHub's 100 MiB limit: $relative. Exclude generated files in .gitignore or configure Git LFS before retrying."
                    }
                }
            }
            Invoke-Git -GitArguments @('-C',$repo.Path,'add','--all')
            & git -C $repo.Path diff --cached --quiet
            $diffExit = $LASTEXITCODE
            if ($diffExit -eq 1) {
                Invoke-Git -GitArguments @('-C',$repo.Path,'commit','--file',$messageFile)
            } elseif ($diffExit -ne 0) { throw 'Could not inspect staged changes.' }
            $localCommit = Invoke-Git -GitArguments @('-C',$repo.Path,'rev-parse','--verify','HEAD')
            Invoke-Git -GitArguments @('-C',$repo.Path,'push','--set-upstream','origin',("HEAD:refs/heads/"+$repo.Branch))
            $remoteLine = Invoke-Git -GitArguments @('-C',$repo.Path,'ls-remote','--exit-code','origin',("refs/heads/"+$repo.Branch))
            $remoteCommit = ([string]$remoteLine -split '\s+')[0]
            if ($remoteCommit -ne $localCommit) { throw "GitHub verification failed for $($repo.Name)." }
            Write-Host "VERIFIED ON REMOTE: $($repo.Name) / $($repo.Branch) / $localCommit" -ForegroundColor Green
        }
        Write-Host "`nSuccess: every selected repository was pushed and verified." -ForegroundColor Green
    } finally {
        if (Test-Path -LiteralPath $messageFile) { Remove-Item -LiteralPath $messageFile }
    }
} catch {
    $exitCode = 1
    Write-Host "`nFAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'No success is reported for the failed repository. Your local files and commits are retained.'
    Write-Host 'For login errors, sign into GitHub when prompted. For rejected pushes, resolve the reported branch conflict first.'
    Write-Host 'No force push or reset was performed.'
}
if (!$NoPause) { Read-Host 'Press Enter to close' | Out-Null }
exit $exitCode
