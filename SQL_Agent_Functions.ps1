function createAgentJob($jobName, $ssisServerName, $owner)
{
    # Create the job
    $ssisServer = New-Object -TypeName  Microsoft.SQLServer.Management.Smo.Server($ssisServerName) 
    $sqlJob = $ssisServer.JobServer.Jobs[$JobName]

    if ($sqlJob)
    {
          $sqlJob.Rename("z_"+$sqlJob.Name +"_OLD_" + (Get-Date -f MM-dd-yyyy_HH_mm_ss))
          $sqlJob.IsEnabled = $false
          $sqlJob.Alter()
    }

    $sqlJob = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.Job -argumentlist $ssisServer.JobServer, $jobName
    $sqlJob.OwnerLoginName = $owner
    $sqlJob.Create()     
    
    $sqlJob.ApplyToTargetServer($ssisServerName)
    $sqlJob.Alter()    
}

function scheduleAgentJob($jobName, $ssisServerName, $jobStartHour, $jobStartMinute, $jobFrequency, $jobFrequencyInterval, $jobStartDate)
{
    $ssisServer = New-Object -TypeName  Microsoft.SQLServer.Management.Smo.Server($ssisServerName) 
    $sqlJob = $ssisServer.JobServer.Jobs[$JobName]

    $jobStartTime = New-TimeSpan -Hour $jobStartHour -Minute $jobStartMinute
    $sqlJobSchedule = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Agent.JobSchedule -ArgumentList $sqlJob, "$jobFrequency $jobStartTime"
    $sqlJobSchedule.IsEnabled = $true
    $sqlJobSchedule.FrequencyTypes = [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::$jobFrequency
    $sqlJobSchedule.FrequencyInterval = $jobFrequencyInterval # Recurs Every Day
    $sqlJobSchedule.ActiveStartDate = $jobStartDate
    $sqlJobSchedule.ActiveStartTimeofDay = $jobStartTime
    $sqlJobSchedule.Create()

    $sqlJob.Alter()
}

function addSSISPackageStepToAgentJob($jobName, $ssisServerName, $folderName, $projectName, $masterPackage, $environmentName, $catalogName, $32bitRuntime, $goToNextStepOnSuccess, $goToNextStepOnFailure)
{
    $ssisServer = New-Object -TypeName  Microsoft.SQLServer.Management.Smo.Server($ssisServerName) 
    $sqlJob = $ssisServer.JobServer.Jobs[$JobName]

    # Get a reference to the environment
    $integrationServices = New-Object "Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices" $ssisServer
    $catalog = $integrationServices.Catalogs[$catalogName]
    $folder = $catalog.Folders[$folderName]    
    $project = $folder.Projects[$projectName]
    $environmentReferences = $project.References[$environmentName, $folderName]

    $32bitRuntimeSnippet = ""
    if ($32bitRuntime)
    {
        $32bitRuntimeSnippet = "/X86"
    }

    # Setup the job step
    $sqlJobStep = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.JobStep -argumentlist $sqlJob, "Project:$projectName Package:$masterPackage"
    #This command will create the SSIS step
    $sqlCommand = '/ISSERVER "\"\'+$catalogName+'\'+$folderName+'\'+$projectName+'\'+$masterPackage+'\"" /SERVER "\"'+$ssisServerName+'\"" '+ $32bitRuntimeSnippet +' /ENVREFERENCE ' + $environmentReferences.ReferenceId + ' /Par "\"$ServerOption::LOGGING_LEVEL(Int16)\"";1 /Par "\"$ServerOption::SYNCHRONIZED(Boolean)\"";True /CALLERINFO SQLAGENT /REPORTING E'    
    
    if ($goToNextStepOnSuccess)
    {
        $sqlJobStep.OnSuccessAction = [Microsoft.SqlServer.Management.Smo.Agent.StepCompletionAction]::GoToNextStep
    }
    else
    {
        $sqlJobStep.OnSuccessAction = [Microsoft.SqlServer.Management.Smo.Agent.StepCompletionAction]::QuitWithSuccess
    }

    if ($goToNextStepOnFailure)
    {
        $sqlJobStep.OnFailAction = [Microsoft.SqlServer.Management.Smo.Agent.StepCompletionAction]::GoToNextStep
    }
    {
        $sqlJobStep.OnFailAction = [Microsoft.SqlServer.Management.Smo.Agent.StepCompletionAction]::QuitWithFailure
    }
    
    $sqlJobStep.SubSystem = "SSIS"
    $sqlJobStep.DatabaseName = $ssisServerName
    $sqlJobStep.Command = $sqlCommand
    $sqlJobStep.Create() 

    $sqlJob.Alter()
}