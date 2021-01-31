<# .SYNOPSIS
	This script can manipulate a Visual Studio C# project an solution to retarget it to use a specific .NET version and output seperate x86 and x64 versions.
.DESCRIPTION
	The script will find all .csproj files in a target directory. If the .csproj files it finds does not contain an x86 and x64 targets. If the target .NET version needs to be changed, it will do this too. The script will then use slngen to generate a new solution file.
.NOTES
	You will need to install slngen to use this script: https://microsoft.github.io/slngen/
.LINK
	https://github.com/xenoscr/SharpProjMangler
#>

# Print out formatted XML
function Write-PrettyXml
{
	param(
		[Parameter(Madatory=$true,
		Position=0)]
		[xml]
		$xml
	)
	<#
	.SYNOPSIS
		Print formatted XML to the console.
	.DESCRIPTION
		Print formatted XML to the console. This function requires an XML object as an argument.
	.PARAMETER xml
		An [xml] object that will be formatted and printed to the console.
	.INPUTS
		None. You cannot pipe objects to Write-PrettyXml.
	.OUTPUTS
		None. The output is printed to the console.
	.EXAMPLE
		PS> Write-PrettyXml [xml]$xmlContent
	#>

	$StringWriter = New-Object System.IO.StringWriter;
	$XmlWriter = New-Object System.Xml.XmlTextWriter $StringWriter;
	$XmlWriter.Formatting = "indented";
	$xml.WriteTo($XmlWriter);
	$XmlWriter.Flush();
	$StringWriter.Flush();
	Write-Output $StringWriter.ToString();
}

# Update the target .NET version
function Update-CSProjDotNetVer
{
	param(
		[Parameter(Mandatory=$true,
		Position=0,
		HelpMessage="A system.object[] containing project file details.")]
		[System.Object[]]
		$projFiles,
		[Parameter(Mandatory=$true,
		Position=1,
		HelpMessage="The target .NET Framework")]
		[Version]
		$targetFrameworkVersion
	)
	<#
	.SYNOPSIS
		Update the target .NET Framework of C# projects.
	.DESCRIPTION
		Update the target .NET Framework of all C# projects passed to the function.
	.PARAMETER projFiles
		A System.Object[] containing C# project file locations.
	.PARAMETER targetFrameworkVersion
		The target .NET Framework version.
	.INPUTS
		None. You cannot pipe objects to Update-CSProjDotNetVer.
	.OUTPUTS
		None. The changes are saved to the C# project files.
	.EXAMPLE
		PS> Update-CSProjDotNetVer -projFiles $(Get-ChildItem C:\Example\ -Recurse -Filter *.csproj) -Version [Version]"v3.5"
	#>

	$projsWithVersion = New-Object Collections.Generic.List[object]
	foreach($file in $projFiles)
	{
		try {
			$content = New-Object xml
			$content.PreserveWhitespace = $true
			$content.Load($file.FullName)
			$versionNodes = $content.GetElementsByTagName("TargetFrameworkVersion");
		}
		catch {
			Write-Error "Failed to load $file.FullName"
			return $false
		}
        
		switch($versionNodes.Count)
		{
			0 {
				Write-Host "The project has no framework version: $file.FullName"
				break;
			}
			1 {
				try {
					$version = $versionNodes[0].InnerText;

					$projsWithVersion.Add([PsCustomObject]@{
						File = $file;
						XmlContent = $content;
						VersionNode = $versionNodes[0];
						VersionRaw = $version;
						Version = [Version]::new($version.Replace("v", ""))
					})
				}
				catch {
					Write-Error "Failed to collect .NET Framework Version."
					return $false
				}
				break;
			}
			default {
				Write-Host "The project has multiple elements of TargetFrameworkVersion: $file.FullName"
				break;
			}
		}
	}

	foreach($proj in $projsWithVersion)
	{    
		if($targetFrameworkVersion -ne $proj.Version)
		{
			try {
				$proj.VersionNode.set_InnerXML("v$targetFrameworkVersion")
				$proj.XmlContent.Save($proj.File.FullName);
				#Write-Host "It would have been changed from $($proj.Version) to $targetFrameworkVersion."
				#Write-PrettyXml $proj.XmlContent
			}
			catch {
				Write-Error "Failed to modify .NET Framework Version."
				return $false
			}
		}
	}
	return $true
}

Function Update-CSProjPlatform
{
	param(
		[Parameter(Mandatory=$true,
		Position=0,
		HelpMessage="System.Object[] containing project file paths")]
		[System.Object[]]
		$projFiles,
		[Parameter(Mandatory=$true,
		Position=1,
		HelpMessage="The target CPU Platform: x86 or x64")]
		[ValidateSet("x86", "x64")]
		[string]
		$targetPlatform
	)
	<#
	.SYNOPSIS
		Update C# project files to include the specified platform configuration.
	.DESCRIPTION
		Update C# project files to include the specified platform configuration.
	.PARAMETER projFiles
		A System.Object[] containing C# project file locations.
	.PARAMETER targetPlatform
		The target CPU architecture.
	.INPUTS
		None. You cannot pipe objects to Update-CSProjPlatform.
	.OUTPUTS
		None. The changes are saved to the C# project files.
	.EXAMPLE
		PS> Update-CSProjPlatform -projFiles $(Get-ChildItem C:\Example\ -Recurse -Filter *.csproj) -targetPlatform "x86"
	#>

	foreach($file in $projFiles)
	{
		$projsWithPlatforms = New-Object Collections.Generic.List[object]
		$targetPlatformFound = $False
		$content = New-Object xml
		$content.PreserveWhitespace = $true

		try {
			$content.Load($file.FullName)
		}
		catch {
			Write-Error "Failed to load $file.FullName"
			return $false
		}

		ForEach ($propGroup in $content.Project.PropertyGroup)
		{
			If ($propGroup.AssemblyName)
			{
				try {
					$propGroup.AssemblyName = "`$(MSBuildProjectName).`$(TargetFrameworkVersion).`$(Platform)"
				}
				catch {
					Write-Error "Failed to modify AssemblyName value."
					return $false
				}
			}
			If ($propGroup.OutputPath)
			{
				try {
					$propGroup.OutputPath = "bin\`$(Configuration)\`$(Platform)\`$(TargetFrameworkVersion)\"
				}
				catch {
					Write-Error "Failed to modify OutputPath value."
					return $false
				}
			}
			If ($propGroup.Condition)
			{
				If ($propGroup.PlatformTarget -eq $targetPlatform)
				{
					$targetPlatformFound = $True
				}
				
				
				$projsWithPlatforms.Add($propGroup)
			}
		}
		If (-Not $targetPlatformFound)
		{
			$DebugDone = $False
			$ReleaseDone = $False
			$newReleaseNode = $Null
			$newDebugNode = $Null
			ForEach ($projEntry in $projsWithPlatforms)
			{
				If (([regex]::Match($propGroup.Condtion, "Release")) -and ($ReleaseDone -ne $True))
				{
					$newReleaseNode = $projEntry.Clone()
					$patternMatch = [regex]::Match($newReleaseNode.Condition, "((Debug|Release)\|.*)'").Captures.Groups[1].value
					try {
						$newReleaseNode.Condition = $newReleaseNode.Condition.Replace($patternMatch, "Release|$targetPlatform")
					}
					catch {
						Write-Error "Failed to modify condition value."
						return $false
					}

					try {
						$newReleaseNode.PlatformTarget = $targetPlatform
					}
					catch {
						Write-Error "Failed to modify PlatformTarget value."
					}

					If (($newReleaseNode.Prefer32Bit -eq 'false') -and ($targetPlatform -eq 'x86'))
					{
						try {
							$newReleaseNode.Prefer32Bit = 'true'
						}
						catch {
							Write-Error "Failed to set Prefer32Bit."
							return $false
						}
					}

					try {
						$newReleaseNode.OutputPath = "bin\`$(Configuration)\`$(Platform)\`$(TargetFrameworkVersion)\"
					}
					catch {
						Write-Error "Failed to modify OutputPath value."
						return $false
					}

					Write-Host "DefineConstants = $($newReleaseNode.DefineConstants.GetType())"
					If ($newReleaseNode.DefineConstants -is [System.Xml.XmlElement])
					{
						try {
							$result = $newReleaseNode.DefineConstants.AppendChild($content.CreateTextNode(""))
						}
						catch {
							Write-Error "Failed to modify DefineConstants value."
							return $false
						}
					}
					else
					{
						try {
							$newReleaseNode.DefineConstants = [string]""
						}
						catch {
							Write-Error "Failed to modify DefineConstants value."
							return $false
						}
					}
					$ReleaseDone = $True
				}
				ElseIf (([regex]::Match($propGroup.Condtion, "Debug")) -and ($DebugDone -ne $True))
				{
					$newDebugNode = $projEntry.Clone()
					$patternMatch = [regex]::Match($newDebugNode.Condition, "((Debug|Release)\|.*)'").Captures.Groups[1].value
					try {
						$newDebugNode.Condition = $newDebugNode.Condition.Replace($patternMatch, "Debug|$targetPlatform")
					}
					catch {
						Write-Error "Failed to modify Condition value."
						return $false
					}

					try {
						$newDebugNode.PlatformTarget = $targetPlatform
					}
					catch {
						Write-Error "Failed to modify PlatformTarget value."
						return $false
					}

					If (($newDebugNode.Prefer32Bit -eq 'false') -and ($targetPlatform -eq 'x86'))
					{
						$newDebugNode.Prefer32Bit = 'true'
					}

					try {
						$newDebugNode.OutputPath = "bin\`$(Configuration)\`$(Platform)\`$(TargetFrameworkVersion)\"
					}
					catch {
						Write-Error "Failed to modify OutputPath value."
						return $false
					}

					Write-Host "DefineConstants = $($newDebugNode.DefineConstants.GetType())"
					If ($newDebugNode.DefineConstants -is [System.Xml.XmlElement])
					{
						try {
							$result = $newDebugNode.DefineConstants.AppendChild($content.CreateTextNode("DEBUG;TRACE"))
						}
						catch {
							Write-Error "Failed to add DefineConstansts value."
							return $false
						}
					}
					else
					{
						try {
							$newDebugNode.DefineConstants = [string]"DEBUG;TRACE"
						}
						catch {
							Write-Error "Failed to modify DefineConstants value."
							return $false
						}
					}
					$DebugDone = $True
				}
			}
			If (($DebugDone) -And ($ReleaseDone))
			{
				try {
					$content.Project.InsertAfter($newReleaseNode, $content.Project.PropertyGroup[0]) | Out-Null
					$content.Project.InsertAfter($newDebugNode, $content.Project.PropertyGroup[0]) | Out-Null
					$content.Save($file.FullName);
					#Write-PrettyXml $content
					Remove-Variable content
				}
				catch {
					Write-Error "Failed to add new PropertyGroups."
					return $false
				}
			}
		}
	}
	return $true
}

Function Add-SlnConfig
{
	param(
		[Parameter(Mandatory=$true,
		Position=0,
		HelpMessage="Full path to the .sln file.")]
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
		$Path,
		[Parameter(Mandatory=$true,
		Position=1,
		HelpMessage="The CPU architecture to target.")]
		[ValidateSet("x86", "x64")]
		[string]
		$cpuArch
	)
	<#
	.SYNOPSIS
		Update Visual Studio Solution file to include the specified platform configuration.
	.DESCRIPTION
		Update Visual Studio Solution file to include the specified platform configuration.
	.PARAMETER Path
		A file path pointing to a Visual Studio solution file (.sln).
	.PARAMETER cpuArch
		The target CPU architecture.
	.INPUTS
		None. You cannot pipe objects to Add-SlnConfig.
	.OUTPUTS
		None. The changes are saved to the solution file.
	.EXAMPLE
		PS> Add-SlnConfig -Path C:\foo\bar.sln -cpuArch "x86"
	#>

	# Get the raw contents of the solution file.
	$slnContent = Get-Content -Raw $Path

	# Regex to capture all project configurations
	[regex]$regexProjEntry = '(?<=Project)(?ms).*?(?=EndProject)'

	# Regex to capture Solution Platform Configurations
	[regex]$regexSolPlatformConf = '(?<=GlobalSection\(SolutionConfigurationPlatforms\) = preSolution)(?ms).*?(?=EndGlobalSection)'

	# Regex to capture Project Configurations
	[regex]$regexProjConf = '(?<=GlobalSection\(ProjectConfigurationPlatforms\) = postSolution)(?ms).*?(?=EndGlobalSection)'

	# Regex to capture UUIDs
	[regex]$regexUUID = '[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}'

	# Get the Platform Configurations from the solution file
	$solPlatformConf = $regexSolPlatformConf.Matches($slnContent)

	# Get the Project Entries from the solution file
	$allProjEntries = $regexProjEntry.Matches($slnContent)

	# Get current configurations from the solution file
	$allConfigurations = $regexProjConf.Matches($slnContent)

	# The list of configurations to add.
	$confList = ("Debug|$cpuArch", "Release|$cpuArch")

	# Loop through each configuration
	ForEach ($curConf in $confList)
	{			
		$solPlatformConf = $regexSolPlatformConf.Matches($slnContent)
		$newSolPlatformConf = "$curConf = $curConf"
		[regex]$regexNewSolPlatformConf = [regex]::escape($newSolPlatformConf)

		if ($regexNewSolPlatformConf.Match($solPlatformConf[0].value).Success -eq $false)
		{
			$whitespace = $solPlatformConf[0].Value.Substring(0, $solPlatformConf[0].Value.Length - $solPlatformConf[0].Value.TrimStart().Length)
			$newSolPlat = "$whitespace$curConf = $curConf"
			try {
				$slnContent = $slnContent.Insert([int]$solPlatformConf[0].Index, $newSolPlat)
			}
			catch {
				Write-Error "Failed to insert solution."
				return $false
			}
		}
		
		ForEach ($projEntry in $allProjEntries)
		{
			$uuidMatch = $regexUUID.Matches($projEntry.value)[1]
			if ($uuidMatch -eq $null)
			{
				continue
			}
			else
			{
				$curUUID = $uuidMatch.value
				[regex]$regexUUIDCheck = $curUUID
				[regex]$regexNewConfig = [regex]::escape("{$curUUID}.$curConf.ActiveCfg = $curConf")
				$foundUUID = $regexUUIDCheck.Matches($allConfigurations)
				$foundMatch = $regexNewConfig.Match($slnContent)
				
				if (($foundMatch[0].Success -eq $false) -and ($foundUUID[0].Success -eq $true) -and ($curUUID.Length -gt 0))
				{
					[regex]$regexFindConfig = "\t*\{$curUUID}\..*\.*ActiveCfg.*"
					$profMatch = $regexFindConfig.Match($slnContent)
					$whitespace = $profMatch.value.Substring(0, $profMatch.value.Length - $profMatch.value.TrimStart().Length)
					$newCfg = "$whitespace{$curUUID}.$curConf.ActiveCfg = $curConf`n$whitespace{$curUUID}.$curConf.Build.0 = $curConf`n"
					try {
						$slnContent = $slnContent.Insert([int]$profMatch[0].Index, $newCfg)
					}
					catch {
						Write-Error "Failed to insert new solution UUID."
						return $false
					}
				}
				else
				{
					Write-Host "{$curUUID}.$curConf.ActiveCfg = $curConf"
				}
			}
		}
	}	
	try {
		# Write the contents and replace all the Windows newlines with unix style new lines, which is the default for a solution file.
		[byte[]][char[]]$slnContent.Replace("`r`n", "`n")  | Set-Content -NoNewLine -Encoding Byte -Path $Path
	}
	catch {
		Write-Error "Failed to save changes to the solution file."
		return $false
	}

	return $true
}

Function Update-CSProjects
{
	param(
		[Parameter(Mandatory=$true,
		Position=0,
		HelpMessage="Full path to the .sln file.")]
		[ValidateScript({
			if (-Not ($_ | Test-Path)) {
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
		HelpMessage="Enter the base path of the Visual Studio Project")]
		[ValidateScript({
			if (-Not ($_ | Test-Path)) {
				throw "The provided path does not exist."
			}
			return $true
		})]
		[System.IO.FileInfo]
		$Path,
		[Parameter(Mandatory=$true,
		Position=2,
		HelpMessage="Enter the target CPU platform: x86 or x64")]
		[ValidateSet("x86", "x64", "all")]
		[string]
		$TargetPlatform = "all",
		[Parameter(Mandatory=$false,
		Position=3,
		HelpMessage="Enter the target .NET framework version")]
		[string]
		$TargetFramework
	)
	<#
	.SYNOPSIS
		Update a C# solution and project files to include the specified platform configuration.
	.DESCRIPTION
		Update a C# solution and project files to include the specified platform configuration.
	.PARAMETER slnPath
		A file path pointing to a Visual Studio solution file (.sln).
	.PARAMETER Path
		The base path of the Visual Studio project.
	.PARAMETER TargetPlatform
		The target platform to be used. Valid options are: all, x86, and x64.
	.PARAMETER TargetFramework
		The .NET Framework version to target.
	.INPUTS
		None. You cannot pipe objects to Update-CSProjects.
	.OUTPUTS
		None. The changes are saved to the solution and project files.
	.EXAMPLE
		PS> Update-CSProjects -slnPath C:\foo\bar.sln -Path C:\foo -TargetPlatform "x86" -TargetFramework "4.0"
	#>

	# Find all the .csproj files in the target path
	$projFiles = Get-ChildItem $Path -Recurse -Filter *.csproj
	if ($projFiles.Count -lt 1)
	{
		Write-Host "No .csproj files were found. Did you specify the correct path?"
		return $false
	}
	else
	{
		if ($targetFramework -ne "")
		{
			if ($(Update-CSProjDotNetVer $projFiles $targetFramework) -eq $false) {
				return $false
			}
		}
		if ($targetPlatform -eq "all")
		{
			if ($(Add-SlnConfig $slnPath "x86") -eq $false) {
				return $false
			}
			if ($(Add-SlnConfig $slnPath "x64") -eq $false) {
				return $false
			}
			if ($(Update-CSProjPlatform $projFiles "x86") -eq $false) {
				return $false
			}
			if ($(Update-CSProjPlatform $projFiles "x64") -eq $false) {
				return $false
			}
		}
		else
		{
			if ($(Add-SlnConfig $slnPath $targetPlatform) -eq $false) {
				return $false
			}
			if ($(Update-CSProjPlatform $projFiles $targetPlatform) -eq $false) {
				return $false
			}
		}
	}
	return $true
}

Export-ModuleMember -Function Update-CSProjects
Export-ModuleMember -Function Update-CSProjDotNetVer
Export-ModuleMember -Function Update-CSProjPlatform
Export-ModuleMember -Function Write-PrettyXml
Export-ModuleMember -Function Add-SlnConfig
