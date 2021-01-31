function Get-ConfuserExProtections
{
	<#
	.SYNOPSIS
		Returns a PSCustomObject populated with the default ConfuserEX protections settings
	.DESCRIPTION
		Returns a PSCustomObject populated with the default ConfuserEX protections settings
	.EXAMPLE
		PS > $protections = Get-ConfuserExProtections
	#>

	return $protections = [PSCustomObject]@{
		seed = $null
		debug = $null
		preset = $null
		packer = "compressor"
		antiDebug = [PSCustomObject]@{
			id = "anti debug"
			preset = "Minimum"
			action = "add"
			enabled = $false
			argument = [PSCustomObject]@{
				mode = "safe"
			}
		}
		antiDump = [PSCustomObject]@{
			id = "anti dump"
			preset = "Maximum"
			action = "add"
			enabled = $false
			argument = $null
		}
		antiILDasm = [PSCustomObject]@{
			id = "anti ildasm"
			preset = "Minimum"
			action = "add"
			enabled = $false
			argument = $null
		}
		antiTamper = [PSCustomObject]@{
			id = "anti tamper"
			preset = "Maximum"
			action = "add"
			enabled = $false
			argument = [PSCustomObject]@{
				mode = "normal"
				key = "normal"
			}
		}
		constants = [PSCustomObject]@{
			id = "constants"
			preset = "Normal"
			action = "add"
			enabled = $false
			argument = [PSCustomObject]@{
				mode = "normal"
				decoderCount = 5
				elements = "SI"
				cfg = "false"
				compressor = "lzma"
				compress = "Auto"
			}
		}
		ctrlFlow = [PSCustomObject]@{
			id = "ctrl flow"
			preset = "Normal"
			action = "add"
			enabled = $false
			argument = [PSCustomObject]@{
				type = "switch"
				predicate = "normal"
				intensity = 60
				depth = 4
				junk = "false"
			}
		}
		invalidMetadata = [PSCustomObject]@{
			id = "invalid metadata"
			preset = "Maximum"
			action = "add"
			enabled = $false
			argument = $null
		}
		rename = [PSCustomObject]@{
			id = "rename"
			preset = "Minimum"
			action = "add"
			enabled = $false
			argument = [PSCustomObject]@{
				mode = "unicode"
				password = $null
				renameArgs = "true"
				renEnum = "false"
				flatten = "true"
				forceRen = "false"
				renPublic = "false"
				renPdb = "false"
				renXaml = "true"
			}
		}
		harden = [PSCustomObject]@{
			id = "harden"
			preset = "Minimum"
			action = "add"
			enabled = $false
			argument = $null
		}
		refProxy = [PSCustomObject]@{
			id = "ref proxy"
			preset = "Normal"
			action = "add"
			enabled = $false
			argument = [PSCustomObject]@{
				mode = "mild"
				encoding = "normal"
				internal = "false"
				typeErasure = "false"
				depth = 3
				initCount = 16
			}
		}
		resources = [PSCustomObject]@{
			id = "resources"
			preset = "Normal"
			action = "add"
			enabled = $false
			argument = [PSCustomObject]@{
				mode = "normal"
			}
		}
		watermark = [PSCustomObject]@{
			id = "watermark"
			preset = "Normal"
			action = "remove"
			enabled = $true
			argument = $null
		}
	}
}

function New-ConfuserEXProj {
	<#
	.SYNOPSIS
		Writes a ConfuserEX project file with the provided protections
	.DESCRIPTION
		Writes a ConfuserEX project file with the provided protections
	.EXAMPLE
		PS > Write-ConfuserEXProj -Protections $protections -TargetAssembly "C:\foo\bar.exe"
	#>

	param(
		[Parameter(Mandatory=$true,
		Position=0,
		HelpMessage="A ConfuserEx Protections PowerShell Object.")]
		[System.Object]
		$Protections,
		[Parameter(Mandatory=$true,
		Position=1,
		HelpMessage="The path to the Assembly to be protected.")]
		[ValidateScript({
			if (-Not ($_ | Test-Path)){
				throw "The provided file path does not exist."
			}
			if (-Not ($_ | Test-Path -PathType Leaf)) {
				throw "The provided argument must be a file. Folder paths are not allowed."
			}
			if (($_ -NotMatch "(\.exe)") -AND ($_ -NotMatch "(\.dll)")) {
				throw "The file specified does not have the correct file extention."
			}
			return $true
		})]
		[String]
		$TargetAssembly
	)

	# Get the base directory
	$cesBaseDir = $targetAssembly | Split-Path -Parent

	# Set the outpuat directory
	$cexOutputDir = "$cesBaseDir\Confused"

	# Set the outputFile
	$outputFile = "$cesBaseDir\ConfuserEX.crproj"

	# Set target Bin
	$targetBin = $targetAssembly | Split-Path -Leaf

	$xmlSettings = New-Object System.Xml.XmlWriterSettings
	$xmlSettings.OmitXmlDeclaration = $true
	$xmlSettings.Indent = $true
	$xmlSettings.IndentChars = "     "

	$xmlWriter = [System.XML.XmlWriter]::Create($outputFile, $xmlSettings)

	$xmlWriter.WriteStartElement("project", "http://confuser.codeplex.com")
	$xmlWriter.WriteAttributeString("outputDir", $cexOutputDir)
	$xmlWriter.WriteAttributeString("baseDir", $cesBaseDir)

	if ($protections.seed) {
		$xmlWriter.WriteAttributeString("seed", $protections.seed)
	}

	if ($protections.debug) {
		$xmlWriter.WriteAttributeString("debug", "true")
	}

	# Create the rules element
	$xmlWriter.WriteStartElement("rule")
	$xmlWriter.WriteAttributeString("pattern", "true")
	if ($protections.preset)
	{
		$presets = "minimum","normal","aggressive","maximum"
		if ($presets.Contains($protections.preset.ToLower())) {
			$xmlWriter.WriteAttributeString("preset", $protections.preset.ToLower())
		}
	}
	$xmlWriter.WriteAttributeString("inherit", "false")

	# Anti Debug option
	if ($protections.antiDebug.enabled)
	{
		$xmlWriter.WriteStartElement("protection")
		$xmlWriter.WriteAttributeString("id", "anti debug")
		
		if ($protections.antiDebug.argument.mode.ToLower() -ne "safe")
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "mode")
			$xmlWriter.WriteAttributeString("value", $protections.antiDebug.argument.mode.ToLower())
			$xmlWriter.WriteEndElement()
		}
		$xmlWriter.WriteEndElement()
	}

	# Anti Dump options
	if ($protections.antiDump.enabled)
	{
		$xmlWriter.WriteStartElement("protection")
		$xmlWriter.WriteAttributeString("id", "anti dump")
		$xmlWriter.WriteEndElement()
	}

	# Anti ildasm options
	if ($protections.antiILDasm.enabled)
	{
		$xmlWriter.WriteStartElement("protection")
		$xmlWriter.WriteAttributeString("id", "anti ildasm")
		$xmlWriter.WriteEndElement()
	}

	# Anti Tamper options
	if ($protections.antiTamper.enabled)
	{
		$xmlWriter.WriteStartElement("protection")
		$xmlWriter.WriteAttributeString("id", "anti tamper")

		if ($protections.antiTamper.argument.mode.ToLower() -ne "normal")
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "mode")
			$xmlWriter.WriteAttributeString("value", $protections.antiTamper.argument.mode.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.antiTamper.argument.key.ToLower() -ne "normal")
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "key")
			$xmlWriter.WriteAttributeString("value", $protections.antiTamper.argument.key.ToLower())
			$xmlWriter.WriteEndElement()
		}
		$xmlWriter.WriteEndElement()
	}

	# Constants options
	if ($protections.constants.enabled)
	{
		$xmlWriter.WriteStartElement("protection")
		$xmlWriter.WriteAttributeString("id", "constants")
		
		if ($protections.constants.argument.mode.ToLower() -ne "safe")
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "mode")
			$xmlWriter.WriteAttributeString("value", $protections.constants.argument.mode.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.constants.argument.decoderCount -ne 5)
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "decoderCount")
			$xmlWriter.WriteAttributeString("value", $protections.constants.argument.decoderCount.ToLower())
			$xmlWriter.WriteEndElement()
		}
		$xmlWriter.WriteEndElement()
	}

	# Ctrl Flow options
	if ($protections.ctrlFlow.enabled)
	{
		$xmlWriter.WriteStartElement("protection")
		$xmlWriter.WriteAttributeString("id", "ctrl flow")

		if ($protections.ctrlFlow.argument.type.ToLower() -ne "switch")
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "type")
			$xmlWriter.WriteAttributeString("value", $protections.ctrlFlow.argument.type.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.ctrlFlow.argument.predicate.ToLower() -ne "normal")
		{
			$xmlWriter.WriteStartElment("argument")
			$xmlWriter.WriteAttributeString("name", "predicate")
			$xmlWriter.WriteAttributeString("value", $protections.ctrlFlow.argument.predicate.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.ctrlFlow.argument.intensity -ne 60)
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "intensity")
			$xmlWriter.WriteAttributeString("valu", $protections.ctrlFlow.argument.intensity.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.ctrlFlow.argument.depth -ne 4)
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "depth")
			$xmlWriter.WriteAttributeStirng("value", $protections.ctrlFlow.argument.depth.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.ctrlFlow.argument.junk.ToLower() -ne "false")
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "junk")
			$xmlWriter.WriteAttributeString("value", $protections.ctrlFlow.argument.junk.ToLower())
			$xmlWriter.WriteEndElement()
		}
		$xmlWriter.WriteEndElement()
	}

	# Harden option
	if ($protections.harden.enabled)
	{
		$xmlWriter.WriteStartElement("protection")
		$xmlWriter.WriteAttributeString("id", "harden")
		$xmlWriter.WriteEndElement()
	}

	# Invalid Metadata options
	if ($protections.invalidMetadata.enabled)
	{
		$xmlWriter.WriteStartElement("protection")
		$xmlWriter.WriteAttributeString("id", "invalid metadata")
		$xmlWriter.WriteEndElement()
	}

	# Reference Proxy options
	if ($protections.refProxy.enabled)
	{
		$xmlWriter.WriteStartElement("protection")
		$xmlWriter.WriteAttributeString("id", "ref proxy")

		if ($protections.refProxy.argument.mode.ToLower() -ne "mild")
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "mode")
			$xmlWriter.WriteAttributeString("value", $protections.refProxy.argument.mode.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.refProxy.argument.encoding.ToLower() -ne "normal")
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "encoding")
			$xmlWriter.WriteAttributeString("value", $protections.refProxy.argument.encoding.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.refProxy.argument.internal.ToLower() -ne "false")
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "internal")
			$xmlWriter.WriteAttributeString("value", $protections.refProxy.argument.internal.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.refProxy.argument.typeErasure.ToLower() -ne "false")
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "typeErasure")
			$xmlWriter.WriteAttributeString("value", $protections.refProxy.argument.typeErasure.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if (($protections.refProxy.argument.depth -ne 3) -and (($protections.refProxy.argument.encoding.ToLower() -eq "expression") -or ($protections.refProxy.argument.encoding.ToLower() -eq "x86")))
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "depth")
			$xmlWriter.WriteAttributeString("value", $protections.refProxy.argument.depth.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if (($protections.refProxy.argument.initCount -ne 16) -and ($protections.refProxy.argument.mode.ToLower() -eq "strong"))
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "initCount")
			$xmlWriter.WriteAttributeString("value", $protections.refProxy.argument.initCount.ToLower())
			$xmlWriter.WriteEndElement()
		}
		$xmlWriter.WriteEndElement()
	}

	# Resource Protection options
	if ($protections.resources.enabled)
	{
		$xmlWriter.WriteStartElement("protection")
		$xmlWriter.WriteAttributeString("id", "resources")

		if ($protections.resources.argument.mode.ToLower() -ne "normal")
		{
			$xmlWriter.WriteStartElement("argument")
			$xmlWriter.WriteAttributeString("name", "mode")
			$xmlWriter.WriteAttributeString("value", $protections.resources.argument.mode.ToLower())
			$xmlWriter.WriteEndElement()
		}
		$xmlWriter.WriteEndElement()
	}

	# Name Protection options
	if ($protections.rename.enabled)
	{
		$xmlWriter.WriteStartElement("protection")
		$xmlWriter.WriteAttributeString("id", "rename")

		if ($protections.rename.argument.mode.ToLower() -ne "unicode")
		{
			$xmlWriter.StartElement("argument")
			$xmlWriter.WriteAttributeString("name", "mode")
			$xmlWriter.WriteAttributeString("value", $protections.resources.argument.mode.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.rename.argument.mode.ToLower() -eq "reversible")
		{
			$xmlWriter.StartElement("argument")
			$xmlWriter.WriteAttributeString("name", "password")
			$xmlWriter.WriteAttributeString("value", $protections.resources.argument.password.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.rename.argument.renameArgs.ToLower() -ne "true")
		{
			$xmlWriter.StartElement("argument")
			$xmlWriter.WriteAttributeString("name", "renameArgs")
			$xmlWriter.WriteAttributeString("value", $protections.resources.argument.renameArgs.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.rename.argument.renEnum.ToLower() -ne "false")
		{
			$xmlWriter.StartElement("argument")
			$xmlWriter.WriteAttributeString("name", "renEnum")
			$xmlWriter.WriteAttributeString("value", $protections.resources.argument.renEnum.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.rename.argument.flatten.ToLower() -ne "true")
		{
			$xmlWriter.StartElement("argument")
			$xmlWriter.WriteAttributeString("name", "flatten")
			$xmlWriter.WriteAttributeString("value", $protections.resources.argument.flatten.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.rename.argument.forceRen.ToLower() -ne "false")
		{
			$xmlWriter.StartElement("argument")
			$xmlWriter.WriteAttributeString("name", "forceRen")
			$xmlWriter.WriteAttributeString("value", $protections.resources.argument.forceRen.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.rename.argument.renPublic.ToLower() -ne "false")
		{
			$xmlWriter.StartElement("argument")
			$xmlWriter.WriteAttributeString("name", "renPublic")
			$xmlWriter.WriteAttributeString("value", $protections.resources.argument.renPublic.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.rename.argument.renPdb.ToLower() -ne "false")
		{
			$xmlWriter.StartElement("argument")
			$xmlWriter.WriteAttributeString("name", "renPdb")
			$xmlWriter.WriteAttributeString("value", $protections.resources.argument.renPdb.ToLower())
			$xmlWriter.WriteEndElement()
		}

		if ($protections.rename.argument.renXaml.ToLower() -ne "true")
		{
			$xmlWriter.StartElement("argument")
			$xmlWriter.WriteAttributeString("name", "renXaml")
			$xmlWriter.WriteAttributeString("value", $protections.resources.argument.renXaml.ToLower())
			$xmlWriter.WriteEndElement()
		}
		$xmlWriter.WriteEndElement()
	}

	# watermark options
	if ($protections.watermark.enabled)
	{
		$xmlWriter.WriteStartElement("protection")
		$xmlWriter.WriteAttributeString("id", "watermark")
		$xmlWriter.WriteAttributeString("action", $protections.watermark.action.ToLower())
		$xmlWriter.WriteEndElement()
	}

	# Close out the rules
	$xmlWriter.WriteEndElement()

	# Set Packer option if enabled and the target assembly is an EXE
	# DLLs cannot be compressed with ConfuserEX
	if (($protections.packer) -AND ($targetBin -match '\.exe$')) {
		$xmlWriter.WriteStartElement("packer")
		$xmlWriter.WriteAttributeString("id", $protections.packer.ToLower())
		$xmlWriter.WriteEndElement()
	}

	# Set the target binary
	$xmlWriter.WriteStartElement("module")
	$xmlWriter.WriteAttributeString("path", $targetBin)
	$xmlWriter.WriteEndElement()

	# Close out the project
	$xmlWriter.WriteEndElement()

	# End and finalize the document
	$xmlWriter.WriteEndDocument()
	$xmlWriter.Flush()
	$xmlWriter.Close()
	return $true
}

Export-ModuleMember -Function Get-ConfuserExProtections
Export-ModuleMember -Function New-ConfuserEXProj
