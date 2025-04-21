function Get-AutomationRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SubscriptionId,
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroup,
        [Parameter(Mandatory=$true)]
        [string]$WorkspaceName
    )

    Write-Verbose "Getting automation rules..."
    
    try {
        # Get all automation rules
        $automationRules = Get-AzSentinelAutomationRule -ResourceGroupName $ResourceGroup -WorkspaceName $WorkspaceName
        
        # Create mapping of automation rules
        $automationMappings = @()
        
        foreach ($rule in $automationRules) {
            $triggerConditions = $rule.Properties.TriggerConditions
            $actions = $rule.Properties.Actions
            
            # Get analytic rules that trigger this automation
            $analyticRuleTriggers = $triggerConditions | Where-Object { $_.Operator -eq "Contains" -and $_.PropertyName -eq "AlertRuleName" }
            $triggeringRules = $analyticRuleTriggers.PropertyValues
            
            # Get action details
            $actionDetails = foreach ($action in $actions) {
                switch ($action.ActionType) {
                    "ModifyProperties" {
                        "Modify Properties: " + ($action.ModifyProperties | ConvertTo-Json -Compress)
                    }
                    "RunPlaybook" {
                        "Run Playbook: " + $action.PlaybookName
                    }
                    default {
                        $action.ActionType
                    }
                }
            }
            
            # Create mapping object
            $mapping = [PSCustomObject]@{
                AutomationRuleName = $rule.Properties.DisplayName
                Order = $rule.Properties.Order
                TriggeringRules = $triggeringRules
                Actions = $actionDetails
                Enabled = $rule.Properties.Enabled
            }
            
            $automationMappings += $mapping
        }
        
        Write-Verbose ("Found " + $automationMappings.Count + " automation rules")
        return $automationMappings
    }
    catch {
        Write-Error ("Failed to get automation rules: " + $_.Exception.Message)
        Write-Verbose $_.ScriptStackTrace
        return $null
    }
}

Export-ModuleMember -Function Get-AutomationRules 