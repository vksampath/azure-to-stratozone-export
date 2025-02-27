#Add performance data to the global array for specified VM

function CheckMetricValue{
	param
	(
		# VM 
		[Parameter(Mandatory = $true)]
		$metricValue
	)
		try{
				if($metricValue -gt 0){
					return $metricValue
				}
				return 0
		}
		catch{
			ModuleLogMessage "Error - CheckMetricValue - $_.Exception.Message" $log
			return 0
		}
}


function SetPerformanceInfo{
	param
	(
		# VM 
		[Parameter(Mandatory = $true)]
		$ids,
		[Parameter(Mandatory = $true)]
		[string]$log
	)
	try{
		$vmPerfObjectList = @()
		$endTime = Get-Date
		$startTime = $endTime.AddDays(-30)
		
		$metricName = "Percentage CPU,Available Memory Bytes,Disk Read Operations/Sec,Disk Write Operations/Sec,Network Out Total,Network In Total"
		$vmMetric = Get-AzMetric -ResourceId $ids.rid -MetricName $metricName -EndTime $endTime -StartTime  $startTime -TimeGrain 0:30:00 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
		
		$metricNameList = $vmMetric.Name.Value

		if(-not $vmMetric){
			$vmPerfMetrics = [pscustomobject]@{
				"MachineId"=$ids.vmID
				"TimeStamp"=Get-Date -format "MM/dd/yyyy HH:mm:ss"
				"CpuUtilizationPercentage"=0
				"AvailableMemoryBytes"=0
				"DiskReadOperationsPerSec"=0
				"DiskWriteOperationsPerSec"=0
				"NetworkBytesPerSecSent"=0
				"NetworkBytesPerSecReceived"=0
				}
			$vmPerfObjectList += $vmPerfMetrics
			return $vmPerfObjectList
		}
		
		$perfDataCount = $vmMetric[0].Data.Count

		$CpuUtilizationPercentageIndex = [array]::IndexOf($metricNameList,"Percentage CPU")
		$AvailableMemoryBytesIndex = [array]::IndexOf($metricNameList,"Available Memory Bytes")
		$DiskReadOperationsPerSecIndex = [array]::IndexOf($metricNameList,"Disk Read Operations/Sec")
		$DiskWriteOperationsPerSecIndex = [array]::IndexOf($metricNameList,"Disk Write Operations/Sec")
		$NetworkBytesPerSecOutIndex = [array]::IndexOf($metricNameList,"Network Out Total")
		$NetworkBytesPerSecInIndex = [array]::IndexOf($metricNameList,"Network In Total")

		if($vmMetric.Count -gt 5){
			for($i =0;$i -lt $perfDataCount; $i++){
				try{
					$CpuUtilizationPercentage = GetMetricAverageValue $DiskWriteOperationsPerSecIndex $i  $vmMetric  $ids  $log $metricNameList
					$AvailableMemoryBytes = GetMetricAverageValue $DiskWriteOperationsPerSecIndex $i  $vmMetric  $ids  $log $metricNameList
					$DiskReadOperationsPerSec = GetMetricAverageValue $DiskWriteOperationsPerSecIndex $i  $vmMetric  $ids  $log $metricNameList
					$DiskWriteOperationsPerSec = GetMetricAverageValue $DiskWriteOperationsPerSecIndex $i  $vmMetric  $ids  $log $metricNameList
					$NetworkBytesPerSecSent = GetMetricTotalValue $NetworkBytesPerSecOutIndex  $i  $vmMetric  $ids  $log $metricNameList
					$NetworkBytesPerSecReceived = GetMetricTotalValue $NetworkBytesPerSecInIndex  $i  $vmMetric  $ids  $log $metricNameList
					
					$vmPerfMetrics = [pscustomobject]@{
						"MachineId"=$ids.vmID
						"TimeStamp"=$vmMetric[0].Data[$i].TimeStamp
						"CpuUtilizationPercentage" = [math]::Round($CpuUtilizationPercentage,10)
						"AvailableMemoryBytes" = CheckMetricValue([math]::ceiling($AvailableMemoryBytes))
						"DiskReadOperationsPerSec" = CheckMetricValue([math]::Round(([decimal]$DiskReadOperationsPerSec),10))
						"DiskWriteOperationsPerSec" = CheckMetricValue([math]::Round([decimal]$DiskWriteOperationsPerSec,10))
						"NetworkBytesPerSecSent " = CalculateNetworkDataPerSec([decimal]$NetworkBytesPerSecSent)
						"NetworkBytesPerSecReceived" = CalculateNetworkDataPerSec([decimal]$NetworkBytesPerSecReceived)
					}
					$vmPerfObjectList += $vmPerfMetrics
				}
				catch{
					$errorMsg = $_.Exception.Message
					$vmId = $ids.vmID
					$line = $_.InvocationInfo.ScriptLineNumber

					ModuleLogMessage "Error - module - vmid:$vmId - $errorMsg at $line" $log
				}
			}
			return $vmPerfObjectList
		}
	}
	catch{
		ModuleLogMessage "Error - module - collection performance for vmID: $ids.vmID. $_" $log
	}
}

function GetMetricTotalValue($metricIndex, $dataIndex, $vmMetric, $ids, $log, $metricNameList) {
    try {
        return $vmMetric[$metricIndex].Data[$dataIndex].Total
    }
    catch{
        $errorMsg = $_.Exception.Message
	$vmId = $ids.vmID
	$line = $_.InvocationInfo.ScriptLineNumber
	$metric = $metricNameList[$metricIndex]

	ModuleLogMessage "Error - module - vmid:$vmId - metricName: $metric - $errorMsg at $line" $log
    }
 
    return "0"
}

function GetMetricAverageValue($metricIndex, $dataIndex, $vmMetric, $ids, $log, $metricNameList) {
    try {
        return $vmMetric[$metricIndex].Data[$dataIndex].Average
    }
    catch{
        $errorMsg = $_.Exception.Message
	$vmId = $ids.vmID
	$line = $_.InvocationInfo.ScriptLineNumber
	$metric = $metricNameList[$metricIndex]

	ModuleLogMessage "Error - module - vmid:$vmId - metricName: $metric - $errorMsg at $line" $log
    }
 
    return "0"
}



# Divide the network data by the time period used in the query
function CalculateNetworkDataPerSec($NetworkTotal){
	try{
		return [math]::Round((CheckMetricValue($NetworkTotal)) /1800,10)
	}
	catch{
		return 0
	}
}

#write data to log file
function ModuleLogMessage
{
    param(
		[Parameter(Mandatory = $true)]
		[string]$Message,
		[Parameter(Mandatory = $true)]
		[string]$log
	)
	
	try{
    	Add-content $log -value ((Get-Date).ToString() + " - " + $Message)
	}
	catch{
		Write-Host "Unable to Write to log file. $_"
	}
}


Export-ModuleMember -Function SetPerformanceInfo, ModuleLogMessage
