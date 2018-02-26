Write-Host ""
Write-Host "*************** Beginning SQL Agent Deployment Process ***************"
Write-Host ""


. '.\SQL_Agent_Functions.ps1'

[xml] $jobDeployments = Get-Content .\Job_Deployments.xml
$jobs = $jobDeployments.SelectNodes("//Job")

foreach ($job in $jobs)
{
    createAgentJob $job.name $job.agentServerName $job.owner
    
    $scheduleJob = [System.Convert]::ToBoolean($job.scheduleJob)    
    if ($scheduleJob)
    {
        $startDate = Get-Date
        scheduleAgentJob $job.name $job.agentServerName $job.startHour $job.startMinute $job.frequency $job.interval $startDate
    }
        
    foreach ($jobStep in $job.JobStep)
    {        
        if ($jobStep.type = "SSIS")
        {
            $32bitRuntime = [System.Convert]::ToBoolean($jobStep.thirtyTwoBitRuntime)
            $goToNextStepOnSuccess = [System.Convert]::ToBoolean($jobStep.goToNextStepOnSuccess)
            $goToNextStepOnFailure = [System.Convert]::ToBoolean($jobStep.goToNextStepOnFailure)           

            addSSISPackageStepToAgentJob $job.Name $job.agentServerName $jobStep.folder $jobStep.project $jobStep.masterPackage $jobStep.environmentReference $jobStep.catalog $32bitRuntime $goToNextStepOnSuccess $goToNextStepOnFailure
        }
    }
}


Write-Host ""
Write-Host "*************** Deployment Complete ***************"
Write-Host ""