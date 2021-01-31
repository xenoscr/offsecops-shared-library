function Get-CSProjLangVer
{
	param(
		[Parameter(Mandatory=$true,
		Position=0,
		HelpMessage="The base path of the Visual Studio project.")]
		[ValidateScript({
			if (-Not ($_ | Test-Path)) {
				throw "The provided path does not exist."
			}
			return $true
		})]
		[System.IO.FileInfo]
		$Path
	)
	<#
	.SYNOPSIS
		Get the language version from a visual studio project.
	.DESCRIPTION
		Get the language version from a visual studio project.
	.PARAMETER Path
		The base path of the Visual Studio project.
	.INPUTS
		None. You cannot pipe objects to Get-CSProjLangVer.
	.OUTPUTS
		The language version is returned as a string.
	.EXAMPLE
		PS> Get-CSProjLangVer -Path C:\foo\
	#>

	$projFiles = Get-ChildItem $Path -Recurse -Filter *.csproj
	$maxLangVersion = 0
	foreach($file in $projFiles)
	{
		$content = New-Object xml
		$content.PreserveWhitespace = $true
		try {
			$content.Load($file.FullName)
		}
		catch {
			Write-Error "Failed to load $file.FullName."
			return $false
		}

		$langVersionNodes = $content.GetElementsByTagName("LangVersion");
        
		If ($langVersionNodes.Count -gt 0)
		{
			ForEach ($entry in $langVersionNodes)
			{
				$version = $entry.InnerText;
				if($version -gt $maxLangVersion)
				{
					$maxLangVersion = $version
				}
			}
		}
	}
	return $maxLangVersion
}

function Get-CSProjFrameworkVer
{
	param(
		[Parameter(Mandatory=$true,
		Position=0,
		HelpMessage="The base path of the Visual Studio project.")]
		[ValidateScript({
			if (-Not ($_ | Test-Path)) {
				throw "The provided path does not exist."
			}
			return $true
		})]
		[System.IO.FileInfo]
		$Path
	)
	<#
	.SYNOPSIS
		Get the .NET Framework version from a visual studio project.
	.DESCRIPTION
		Get the .NET Framework version from a visual studio project.
	.PARAMETER Path
		The base path of the Visual Studio project.
	.INPUTS
		None. You cannot pipe objects to Get-CSProjLangVer.
	.OUTPUTS
		The language version is returned as a string.
	.EXAMPLE
		PS> Get-CSProjFrameworkVer -Path C:\foo\
	#>

	$projFiles = Get-ChildItem $Path -Recurse -Filter *.csproj
	$maxLangVersion = 0
	foreach($file in $projFiles)
	{
		$content = New-Object xml
		$content.PreserveWhitespace = $true
		try {
			$content.Load($file.FullName)
		}
		catch {
			Write-Error "Failed to load $file.FullName."
			return $false
		}

		$frameworkNodes = $content.GetElementsByTagName("TargetFrameworkVersion");
        
		If ($frameworkNodes.Count -gt 0)
		{
			ForEach ($entry in $frameworkNodes)
			{
				$version = $entry.InnerText.Trim("v");
				if($version -gt $maxLangVersion)
				{
					$maxLangVersion = $version
				}
			}
		}
	}
	return $maxLangVersion
}

# Language Version information I used is located here
# https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-options/langversion-compiler-option
function Get-MSBuildPath
{
	param(
		[Parameter(Mandatory=$true,
		Position=0,
		HelpMessage="The target language version.")]
		[string]
		$langVersion
	)
	<#
	.SYNOPSIS
		Returns the path of the appropriate MSBuild.exe to use.
	.DESCRIPTION
		Returns the path of the appropriate MSBuild.exe to use based on the target language version.
	.PARAMETER langVersion
		The target language version
	.INPUT
		None.
	.OUTPUT
		A string containing the full path of the correct MSBuild.exe to use.
	.EXAMPLE
		PS> Get-MSBuildPath -langVersion 8.0
	#>
	If (([float]$langVersion -ge 8.0))
	{
		return "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe"
	}
	ElseIf (([float]$langVersion -lt 8.0) -and ([float]$langVersion -ge 7.0))
	{
		return "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\MSBuild\15.0\Bin\MSBuild.exe"
	}
	Else
	{
		return $false
	}
}

function Invoke-MSBuildEnv
{
	param(
		[Parameter(Mandatory=$true,
		Position=0,
		HelpMessage="The target language version.")]
		[string]
		$langVersion
	)
	<#
	.SYNOPSIS
		Invokes the appropriate VsMsBuildCmd.bat and duplicates the environment variables.
	.DESCRIPTION
		Invokes the appropriate VsMsBuildCmd.bat and duplicates the environment variables.
	.PARAMETER langVersion
		The target language version
	.INPUT
		None.
	.OUTPUT
		A string containing the full path of the correct MSBuild.exe to use.
	.EXAMPLE
		PS> Get-MSBuildPath -langVersion 8.0
	#>
	If (([float]$langVersion -ge 8.0))
	{
		Invoke-DevEnvironment "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\Common7\Tools\VsMSBuildCmd.bat"
	}
	ElseIf (([float]$langVersion -lt 8.0) -and ([float]$langVersion -ge 7.0))
	{
		Invoke-DevEnvironment "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\VsMSBuildCmd.bat"
	}
}

# Borrowed from https://github.com/majkinetor/posh/blob/master/MM_Admin/Invoke-Environment.ps1
function Invoke-DevEnvironment {
	param
	(
		# Any cmd shell command, normally a configuration batch file.
		[Parameter(Mandatory=$true)]
		[string] $Command
	)
	<#
	.SYNOPSIS
	    Invokes a command and imports its environment variables.

	.DESCRIPTION
	    It invokes any cmd shell command (normally a configuration batch file) and
	    imports its environment variables to the calling process. Command output is
	    discarded completely. It fails if the command exit code is not 0. To ignore
	    the exit code use the 'call' command.

	.EXAMPLE
	    # Invokes Config.bat in the current directory or the system path
	    Invoke-Environment Config.bat

	.EXAMPLE
	    # Visual Studio environment: works even if exit code is not 0
	    Invoke-Environment 'call "%VS100COMNTOOLS%\vsvars32.bat"'

	.EXAMPLE
	    # This command fails if vsvars32.bat exit code is not 0
	    Invoke-Environment '"%VS100COMNTOOLS%\vsvars32.bat"'
	#>

	try {
		$Command = "`"" + $Command + "`""
			cmd /c "$Command > nul 2>&1 && set" | . { process {
				if ($_ -match '^([^=]+)=(.*)') {
					[System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
				}
			}
		}
	}
	catch {
		Write-Error "Failed to load Dev Environment."
		return $false
	}
	return $true
}

function Invoke-CSProjectCleanup
{
	param(
		[Parameter(Mandatory=$true,
		Position=0,
		HelpMessage="Path to a Visual Studio Solution File")]
		[ValidateScript({
			if (-Not ($_ | Test-Path)){
				throw "The provided .sln file path does not exist."
			}
			if (-Not ($_ | Test-Path -PathType Leaf)) {
				throw "The provided argument must be a file. Folder paths are not allowed."
			}
			if ($_ -NotMatch "(\.sln)") {
				throw "The file specified does not have the correct file extention."
			}
			return $true
		})]
		[System.IO.FileInfo]
		$slnPath,
		[Parameter(Mandatory=$true,
		Position=1,
		HelpMessage="The target configuration.")]
		[ValidateSet("Debug", "Release")]
		[string]
		$targetConfiguration,
		[Parameter(Mandatory=$true,
		Position=2,
		HelpMessage="The target CPU platform.")]
		[ValidateSet("x86", "x64", "Any CPU")]
		[string]
		$targetPlatform,
		[Parameter(Mandatory=$false,
		Position=3,
		HelpMessage="Force delete the `"obj`" and `"bin`" folders.")]
		[bool]
		$forceDelete = $false
	)
	<#
	.SYNOPSIS
		Clean a target C# solution.
	.DESCRIPTION
		Clean a target C# solution.
	.PARAMETER targetPlatform
		The target CPU Architecture. (x86, x64, Any CPU)
	.PARAMETER targetConfiguration
		The target configuration. (Debug, Release)
	.PARAMETER slnPath
		The target Visual Studio solution.
	.INPUTS
		None. You cannot pipe objects to Compile-Solution.
	.OUTPUTS
		None. There is no output other than status printed to the console.
	.EXAMPLE
		PS> Invoke-CSProjectCleanup -targetPlatform "x86" -TargetConfiguration "Release" -slnPath "C:\foo\bar.sln"
	#>
	$langVersion = Get-CSProjLangVer -Path $(Split-Path $slnPath -Parent)
	If ($(Invoke-MSBuildEnv -langVersion $langVersion)) {
		$msBuildPath = Get-MSBuildPath -langVersion $langVersion

		try {
			$buildOutput = (& "$($msBuildPath)" "$($slnPath)" "/t:Clean" "/p:configuration=$($targetConfiguration);platform=$(targetPlatform)" | Write-Output)
		}
		catch {
			Write-Error "Failed to run cleanup."
			return $false
		}
		If ($buildOutput -like "*Build succeeded*") {
			Write-Host $buildOutput
			return $true
		}
		else {
			Write-Error "Clean Failed"
			Write-Host $buildOutput
			return $false
		}
		If ($forceDelete) {
			Get-ChildItem "$(Split-Path $slnPath -Parent)\*\bin" | forEach { Remove-Item -Path $_.FullName -Force -Recurse }
			Get-ChildItem "$(Split-Path $slnPath -Parent)\*\obj" | forEach { Remove-Item -Path $_.FullName -Force -Recurse }
		}
	}
	else {
		return $false
	}
}

function Invoke-CompileCSProject
{
	param(
		[Parameter(Mandatory=$true,
		Position=0,
		HelpMessage="The target CPU platform.")]
		[ValidateSet("x86", "x64", "Any CPU")]
		[string]
		$targetPlatform,
		[Parameter(Mandatory=$true,
		Position=1,
		HelpMessage="The target configuration.")]
		[ValidateSet("Debug", "Release")]
		[string]
		$targetConfiguration,
		[Parameter(Mandatory=$true,
		Position=2,
		HelpMessage="Path to a Visual Studio Solution File")]
		[ValidateScript({
			if (-Not ($_ | Test-Path)){
				throw "The provided .sln file path does not exist."
			}
			if (-Not ($_ | Test-Path -PathType Leaf)) {
				throw "The provided argument must be a file. Folder paths are not allowed."
			}
			if ($_ -NotMatch "(\.sln)") {
				throw "The file specified does not have the correct file extention."
			}
			return $true
		})]
		[System.IO.FileInfo]
		$slnPath,
		[Parameter(Mandatory=$false,
		Position=3,
		HelpMessage="The target .NET Framework Version.")]
		[String]
		$targetFrameworkVersion = $null,
		[Parameter(Mandatory=$false,
		Position=4,
		HelpMessage="Clean up first?")]
		$cleanup = $false
	)
	<#
	.SYNOPSIS
		Compile a target C# solution.
	.DESCRIPTION
		Compile a target C# solution.
	.PARAMETER targetPlatform
		The target CPU Architecture. (x86, x64, Any CPU)
	.PARAMETER targetConfiguration
		The target configuration. (Debug, Release)
	.PARAMETER slnPath
		The target Visual Studio solution.
	.INPUTS
		None. You cannot pipe objects to Compile-Solution.
	.OUTPUTS
		None. There is no output other than status printed to the console.
	.EXAMPLE
		PS> Invoke-CompileCSProject -targetPlatform "x86" -TargetConfiguration "Release" -slnPath "C:\foo\bar.sln"
	#>
	$slnName = $(Get-Item $slnPath).Basename
	$langVersion = Get-CSProjLangVer -Path $(Split-Path $slnPath -Parent)
	If (-Not $targetFrameworkVersion) {
		$targetFrameworkVersion = Get-CSProjFrameworkVer -Path $(Split-Path $slnPath -Parent)
	}
	If ($(Invoke-MSBuildEnv -langVersion $langVersion)) {
		$msBuildPath = Get-MSBuildPath -langVersion $langVersion

		If ($cleanup) {
			try {
				If (-Not (Invoke-ProjectCleanup -slnPath $slnPath -targetConfiguration $targetConfiguration -targetPlatform $targetPlatform)) {
					Write-Error "Cleanup failed."
					return $false
				}
			}
			catch {
				Write-Error "Failed to run cleanup."
				return $false
			}
		}
		
		try {
			# Build the soltuion
			$buildOutput = (& "$($msBuildPath)" "$($slnPath)" "/t:Build" "/p:configuration=$($targetConfiguration);platform=$($targetPlatform);targetFrameworkVersion=v$($targetFrameworkVersion);OutputPath=bin\$($targetConfiguration)\$($targetFrameworkVersion)\$($targetPlatform.Replace(`" `", `"`"))\;AssemblyName=$($slnName).$($targetFrameworkVersion).$($targetPlatform.Replace(`" `",`"`"))" | Write-Output)
		}
		catch {
			Write-Error "Failed to run build."
			return $false
		}
		If ($buildOutput -like "*Build succeeded*") {
			Write-Host "Build Success."
			Write-Host $buildOutput
			return $true
		}
		else {
			Write-Error "Build Failed"
			Write-Host $buildOutput
			return $false
		}
	}
	else {
		return $false
	}
}

Export-ModuleMember -Function Get-CSProjLangVer
Export-ModuleMember -Function Get-CSProjFrameworkVer
Export-ModuleMember -Function Get-MSBuildPath
Export-ModuleMember -Function Invoke-MSBuildEnv
Export-ModuleMember -Function Invoke-DevEnvironment
Export-ModuleMember -Function Invoke-CSProjectCleanup
Export-ModuleMember -Function Invoke-CompileCSProject
