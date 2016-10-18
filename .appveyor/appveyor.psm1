function Start-AppveyorInstallTask
{
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module Pester -Force
    git clone -q https://github.com/PowerShell/DscResource.Tests "$env:APPVEYOR_BUILD_FOLDER\Modules\SharePointDsc\DscResource.Tests"
    git clone -q https://github.com/PowerShell/DscResources "$env:APPVEYOR_BUILD_FOLDER\DscResources"
    Import-Module "$env:APPVEYOR_BUILD_FOLDER\Modules\SharePointDsc\DscResource.Tests\TestHelper.psm1" -force
}

function Start-AppveyorTestScriptTask
{
    $testResultsFile = ".\TestsResults.xml"
    Import-Module "$env:APPVEYOR_BUILD_FOLDER\Tests\Unit\SharePointDsc.TestHarness.psm1"
    $res = Invoke-SPDscUnitTestSuite -TestResultsFile $testResultsFile -DscTestsPath "$env:APPVEYOR_BUILD_FOLDER\Modules\SharePointDsc\DscResource.Tests"
    (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $testResultsFile))
    if ($res.FailedCount -gt 0) { 
        throw "$($res.FailedCount) tests failed."
    }
}

function Start-AppveyorAfterTestTask
{
    Move-Item "$env:APPVEYOR_BUILD_FOLDER\Modules\SharePointDsc\DscResource.Tests" "$env:APPVEYOR_BUILD_FOLDER\"
    Import-Module "$env:APPVEYOR_BUILD_FOLDER\DscResource.Tests\TestHelper.psm1" -force
    New-Item "$env:APPVEYOR_BUILD_FOLDER\modules\SharePointDsc\en-US" -ItemType Directory
    Import-Module "$env:APPVEYOR_BUILD_FOLDER\DscResources\DscResource.DocumentationHelper"
    Write-DscResourcePowerShellHelp -OutputPath "$env:APPVEYOR_BUILD_FOLDER\modules\SharePointDsc\en-US" -ModulePath "$env:APPVEYOR_BUILD_FOLDER\modules\SharePointDsc" -Verbose

    Add-Type -assemblyname System.IO.Compression.FileSystem

    New-Item "$env:APPVEYOR_BUILD_FOLDER\wikicontent" -ItemType Directory
    Write-DscResourceWikiSite -OutputPath "$env:APPVEYOR_BUILD_FOLDER\wikicontent" -ModulePath "$env:APPVEYOR_BUILD_FOLDER\modules\SharePointDsc" -Verbose
    $zipFileName = "SharePointDsc_$($env:APPVEYOR_BUILD_VERSION)_wikicontent.zip"
    [System.IO.Compression.ZipFile]::CreateFromDirectory("$env:APPVEYOR_BUILD_FOLDER\wikicontent", "$env:APPVEYOR_BUILD_FOLDER\$zipFileName")
    Get-ChildItem "$env:APPVEYOR_BUILD_FOLDER\$zipFileName" | % { Push-AppveyorArtifact $_.FullName -FileName $_.Name }

    Get-ChildItem "$env:APPVEYOR_BUILD_FOLDER\Modules\**\readme.md" -Recurse | Remove-Item -Confirm:$false

    $manifest = Join-Path "$env:APPVEYOR_BUILD_FOLDER\modules\SharePointDsc" "SharePointDsc.psd1"
    (Get-Content $manifest -Raw).Replace("1.3.0.0", $env:APPVEYOR_BUILD_VERSION) | Out-File $manifest
    $zipFileName = "SharePointDsc_$($env:APPVEYOR_BUILD_VERSION).zip"
    [System.IO.Compression.ZipFile]::CreateFromDirectory("$env:APPVEYOR_BUILD_FOLDER\modules\SharePointDsc", "$env:APPVEYOR_BUILD_FOLDER\$zipFileName")
    New-DscChecksum -Path $env:APPVEYOR_BUILD_FOLDER -Outpath $env:APPVEYOR_BUILD_FOLDER
    Get-ChildItem "$env:APPVEYOR_BUILD_FOLDER\$zipFileName" | % { Push-AppveyorArtifact $_.FullName -FileName $_.Name }
    Get-ChildItem "$env:APPVEYOR_BUILD_FOLDER\$zipFileName.checksum" | % { Push-AppveyorArtifact $_.FullName -FileName $_.Name }
    
    cd "$env:APPVEYOR_BUILD_FOLDER\modules\SharePointDsc"
    New-Nuspec -packageName "SharePointDsc" -version $env:APPVEYOR_BUILD_VERSION -author "Microsoft" -owners "Microsoft" -licenseUrl "https://github.com/PowerShell/DscResources/blob/master/LICENSE" -projectUrl "https://github.com/$($env:APPVEYOR_REPO_NAME)" -packageDescription "SharePointDsc" -tags "DesiredStateConfiguration DSC DSCResourceKit" -destinationPath .
    nuget pack ".\SharePointDsc.nuspec" -outputdirectory $env:APPVEYOR_BUILD_FOLDER
    $nuGetPackageName = "SharePointDsc." + $env:APPVEYOR_BUILD_VERSION + ".nupkg"
    Get-ChildItem "$env:APPVEYOR_BUILD_FOLDER\$nuGetPackageName" | % { Push-AppveyorArtifact $_.FullName -FileName $_.Name }
}

Export-ModuleMember -Function *
