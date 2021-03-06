Param (
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot),
    
    [String]
    $BuildOutput = (property BuildOutput "BuildOutput"),
    
    [String]
    $ResourcesFolder = (property ResourcesFolder "DSC_Resources"),
    
    [String]
    $ConfigurationsFolder =  (property ConfigurationsFolder "DSC_Configurations"),

    [ScriptBlock]
    $Filter = (property Filter {}),

    $Environment = (property Environment 'DEV'),

    $ConfigDataFolder = (property ConfigDataFolder 'DSC_ConfigData'),

    $FilterNode = (property FilterNode $false),

    $ModuleToLeaveLoaded = (property ModuleToLeaveLoaded @('InvokeBuild','PSReadline','PackageManagement') )

)
    task PSModulePath_BuildModules {
        if(!([io.path]::isPathRooted($BuildOutput))) {
            $BuildOutput = Join-Path $ProjectPath $BuildOutput
        }

        $ConfigurationPath = Join-Path $ProjectPath $ConfigurationsFolder
        $ResourcePath = Join-Path $ProjectPath $ResourcesFolder
        $BuildModulesPath = Join-Path $BuildOutput 'modules'
        
        Set-PSModulePath -ModuleToLeaveLoaded $ModuleToLeaveLoaded -PathsToSet @($ConfigurationPath, $ResourcePath, $BuildModulesPath)
    }

    Task Compile_Datum_DSC Load_Datum_ConfigData, Compile_Root_Configuration, compile_root_meta_mof, create_MOF_checksums

    Task Load_Datum_ConfigData {
        if ( ![io.path]::IsPathRooted($BuildOutput) ) {
            $BuildOutput = Join-Path $ProjectPath -ChildPath $BuildOutput
        }
        $ConfigDataPath    = Join-Path $ProjectPath $ConfigDataFolder
        $ConfigurationPath = Join-Path $ProjectPath $ConfigurationsFolder
        $ResourcePath      = Join-Path $ProjectPath $ResourcesFolder
        $BuildModulesPath  = Join-Path $BuildOutput 'modules'
        
        Set-PSModulePath -ModuleToLeaveLoaded $ModuleToLeaveLoaded -PathsToSet @($ConfigurationPath,$ResourcePath,$BuildModulesPath)

        Import-Module PowerShell-Yaml -scope Global
        Import-Module Datum -Force -Scope Global

        $DatumDefinitionFile = Join-Path -Resolve $ConfigDataPath 'Datum.yml'
        Write-Build Green "Loading Datum Definition from $DatumDefinitionFile"
        $Global:Datum = New-DatumStructure -DefinitionFile $DatumDefinitionFile
        

        $Global:ConfigurationData = Get-FilteredConfigurationData -Environment $Environment -Filter $Filter -FilteredNode $FilteredNode -Datum $Datum
}

task Compile_Root_Configuration {
    '-----------------------'
    "FilteredNode: $($FilteredNode -Join ', ')"
    '-----------------------'

    if($ConfigDataCopy) {
        $Global:ConfigurationData = $ConfigDataCopy.Clone()
        $Global:ConfigurationData.AllNodes = @($ConfigurationData.AllNodes.Where{$_.Name -in $FilteredNode})

        $Global:Datum = $ConfigDataCopy.Datum
    }
    else {
        $Configurationdata = Get-FilteredConfigurationData -Environment $Environment -Filter $Filter -FilteredNode $FilteredNode
    }
    try {
        . (Join-path $ProjectPath 'RootConfiguration.ps1')
    }
    catch {
        Write-Build Red "ERROR OCCURED DURING COMPILATION"
    }
}

task compile_root_meta_mof {
    . (Join-path $ProjectPath 'RootMetaMof.ps1')
    RootMetaMOF -ConfigurationData $ConfigurationData -outputPath (Join-Path $BuildOutput 'MetaMof')
}

task create_MOF_checksums {
    Import-Module DscBuildHelpers -Scope Global
    New-DscChecksum -Path (Join-Path $BuildOutput MOF) -verbose:$false
}