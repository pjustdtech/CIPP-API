function Push-ListMFAUsersQueue {
    <#
    .FUNCTIONALITY
        Entrypoint
    #>
    param($Item)

    # Write out the queue message and metadata to the information log.
    Write-Host "PowerShell queue trigger function processed work item: $($Item.defaultDomainName)"

    try {
        #Update-CippQueueEntry -RowKey $Item.QueueId -Status 'Running' -Name $Item.displayName
        $domainName = $Item.defaultDomainName
        $Table = Get-CIPPTable -TableName cachemfa
        Try {
            $GraphRequest = Get-CIPPMFAState -TenantFilter $domainName -ErrorAction Stop
        } catch {
            $GraphRequest = $null
        }
        if (!$GraphRequest) {
            $GraphRequest = @{
                Tenant          = [string]$domainName
                UPN             = [string]$domainName
                AccountEnabled  = 'none'
                PerUser         = [string]'Could not connect to tenant'
                MFARegistration = 'none'
                CoveredByCA     = [string]'Could not connect to tenant'
                CoveredBySD     = 'none'
                RowKey          = [string]"$domainName"
                PartitionKey    = 'users'
            }
        } else {
            $GraphRequest = foreach ($Request in $GraphRequest) {
                $Request.CAPolicies = try { [string](@($Request.CAPolicies) | ConvertTo-Json -Compress -Depth 5) } catch { [string]$Request.CAPolicies }
                $Request.MFAMethods = try { [string](@($Request.MFAMethods) | ConvertTo-Json -Compress -Depth 5) } catch { [string]$Request.MFAMethods }
                $Request
            }
        }
        Add-CIPPAzDataTableEntity @Table -Entity $GraphRequest -Force | Out-Null

    } catch {
        $Table = Get-CIPPTable -TableName cachemfa
        $GraphRequest = @{
            Tenant          = [string]$domainName
            UPN             = [string]$domainName
            AccountEnabled  = 'none'
            PerUser         = [string]'Could not connect to tenant'
            MFARegistration = 'none'
            CoveredByCA     = [string]'Could not connect to tenant'
            CoveredBySD     = 'none'
            RowKey          = [string]"$domainName"
            PartitionKey    = 'users'
        }
        Add-CIPPAzDataTableEntity @Table -Entity $GraphRequest -Force | Out-Null
    } finally {
        #Update-CippQueueEntry -RowKey $QueueItem -Status 'Completed'
    }

}
