function Set-CurrentContext($subscriptionId, $tenantId, $logger)
{
    Get-AzSubscription -SubscriptionId $subscriptionId -TenantId $tenantId | Set-AzContext
}