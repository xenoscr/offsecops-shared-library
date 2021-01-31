def modifySolution(psScriptPath, targetPlatform, targetFramework = null) {
    if (targetFramework != null) {
        def stdout = powershell(returnStdout: true, script: """
            Write-Information "Importing PowerShell module: Update-Vsproject".
            Import-Module "${psScriptPath}Update-Vsproject.psm1"

            Write-Information "Gathering *.sln files to modify"
            \$slnPath = \$(Get-ChildItem -Filter *.sln)[0].FullName

            Write-Information "Modifying the Solution and Project."
            if (\$(Update-CSProjects -slnPath \$slnPath -Path \$(\$slnPath | Split-Path -Parent) -TargetPlatform "${targetPlatform}" -TargetFramework "${targetFramework}")) {
                Write-Information "Modifications successful."
                Exit 0
            } else {
                Write-Error "Modifications failed."
                Exit 1
            }
        """)
        println stdout
    } else {
            def stdout = powershell(returnStdout: true, script: """
            Write-Information "Importing PowerShell module: Update-Vsproject".
            Import-Module "${psScriptPath}Update-Vsproject.psm1"

            Write-Information "Gathering *.sln files to modify"
            \$slnPath = \$(Get-ChildItem -Filter *.sln)[0].FullName

            Write-Information "Modifying the Solution and Project."
            if (\$(Update-CSProjects -slnPath \$slnPath -Path \$(\$slnPath | Split-Path -Parent) -TargetPlatform "${targetPlatform}")) {
                Write-Information "Modifications successful."
                Exit 0
            } else {
                Write-Error "Modifications failed."
                Exit 1
            }
        """)
        println stdout
    }
}

def removeOldAssemblies() {
    def stdout = powershell(returnStdout: true, script: """
        Write-Information "Collection Assembly List."
        Get-ChildItem "*\\bin" | forEach { Remove-Item -Path \$_.FullName -Force -Recurse }
		Get-ChildItem "*\\obj" | forEach { Remove-Item -Path \$_.FullName -Force -Recurse }
        Write-Information "Clean-up complete."
        Exit 0
    """)
    println stdout
}

def compileSolution(psScriptPath, targetPlatform, targetFramework = null) {
    if (targetFramework != null) {
        def stdout = powershell(returnStdout: true, script: """
            Write-Information "Importing PowerShell module: Compile-CSProject"
            Import-Module "${psScriptPath}Compile-CSProject.psm1"

            Write-Information "Collecting *.sln list."
            \$slnPath = \$(Get-ChildItem -Filter *.sln)[0].FullName

            Write-Information "Compiling Solution, Platform = ${targetPlatform} Framwork = ${targetFramework}"
            if (\$(Invoke-CompileCSProject -targetPlatform "${targetPlatform}" -TargetConfiguration "Release" -slnPath \$slnPath -targetFrameworkVersion ${targetFramework})) {
                Write-Information "Compilation successful."
                Exit 0
            } else {
                Write-Error "Compilation failed."
                Exit 1
            }
        """)
        println stdout
    } else {
            def stdout = powershell(returnStdout: true, script: """
            Write-Information "Importing PowerShell module: Compile-CSProject"
            Import-Module "${psScriptPath}Compile-CSProject.psm1"

            Write-Information "Collecting *.sln list."
            \$slnPath = \$(Get-ChildItem -Filter *.sln)[0].FullName

            Write-Information "Compiling Solution, Platform = ${targetPlatform} Framwork = Default"
            if (\$(Invoke-CompileCSProject -targetPlatform "${targetPlatform}" -TargetConfiguration "Release" -slnPath \$slnPath)) {
                Write-Information "Compilation successful."
                Exit 0
            } else {
                Write-Error "Compilation failed."
                Exit 1
            }
        """)
        println stdout
    }
}

def confuseSolution(psScriptPath, confuserExPath) {
    def stdout = powershell(returnStdout: true, script: """
        Write-Information "Importing PowerShell Module: ConfuserExProj"
        Import-Module "${psScriptPath}ConfuserEXProj.psm1"

        Write-Information "Configuring ConfuserEx Protections."
        \$confuserProperties = Get-ConfuserExProtections
        \$confuserProperties.antiTamper.enabled = \$True
        \$confuserProperties.constants.enabled = \$true
        \$confuserProperties.ctrlFlow.enabled = \$true
        \$confuserProperties.refProxy.enabled = \$true
        \$confuserProperties.resources.enabled = \$true
        \$confuserProperties.antiILDasm.enabled = \$true
        \$confuserProperties.watermark.enabled = \$true
        \$confuserProperties.watermark.action = "remove"
        \$confuserProperties.packer = \$null

        Write-Information "Collecting list of Assemblies."
        \$assemblyList = Get-ChildItem -Recurse | Where-Object { \$_.name -match \'((x86|x64|AnyCPU)\\.exe\$|(x86|x64|AnyCPU)\\.dll\$)\' }

        Write-Information "Processing Assemblies."
        ForEach (\$assembly in \$assemblyList) {
            If (\$assembly.FullName -NotMatch \'\\\\obj\\\\\') {
                Write-Information "Creating ConfuserEx Project File."
                If (\$(New-ConfuserExProj -Protections \$confuserProperties -TargetAssembly "\$(\$assembly.FullName)")) {
                    try {
                        Write-Information "Running ConfuserEx on: \$(\$assembly.FullName)"
                        . "${confuserExPath}" -n "\$(\$assembly.FullName | Split-Path -Parent)\\ConfuserEx.crproj"
                    } catch {
                        Write-Error "ConfuserEx failed."
                        Exit 1
                    }
                    try {
                        Write-Information "Renaming Confused Assembly."
                        Move-Item "\$(\$assembly.FullName | Split-Path -Parent)\\Confused\\\$(\$assembly.FullName | Split-Path -Leaf)" -Destination "\$(\$assembly.FullName | Split-Path -Parent)\\Confused\\Confused_\$(\$assembly.FullName | Split-Path -Leaf)"
                    } catch {
                        Write-Error "Renaming Confused Assembly failed."
                        Exit 1
                    }
                } else {
                    Write-Error "Unable to create ConfuserEx configuration."
                    Exit 1
                }
            }
        }
    """)
    println stdout
}