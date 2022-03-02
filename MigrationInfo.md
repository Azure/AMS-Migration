# README (for migration)

Older version of product will be referred to as Azure Monitor for SAP Solutions (classic) or AMS (classic). AMS (classic) is currently in public preview.

**New** version of the product will be referred to as Azure Monitor for SAP solutions or AMS. AMS is currently in private preview and is subjected to allow-listing of subscription.

Below are steps to migrate AMS (classic) to AMS monitor resource.

Pre-requisite

- _ **Deploy new AMS resource:** _ Please follow [AMS onboarding wiki](https://github.com/Azure/Azure-Monitor-for-SAP-solutions-preview/wiki) to deploy new AMS resource manually.

_Please note:_ While following onboarding wiki, please deploy _only_ the AMS resource (without providers). Providers will be migrated automatically using the automation script (instructions below).

_Please note:_To retain previously collected telemetry data please select checkbox for &quot;Use existing log analytics workspace&quot; while creating new AMS resource. Instructions can be found in boarding wiki. This selection will ensure that log analytics workspace associated with your current AMS (classic) resource is used with new AMS resource. Therefore, you will be able to retain previously collected telemetry.

- _ **Hosts file entries:** _ If you have one or more active SAP NetWeaver provider, this pre-requite is for you. Please keep hosts.json file or contents of hosts.json file handy. One way to get to contents of hosts.json file by logging into collector VM of AMS (classic) managed resource group. (@mohit to put steps after talking to Suhani)

Migration steps

1. Continue running AMS (Azure Monitor for SAP Solutions) 1.0 as is.
2. Assuming you have completed the pre-requisite you should have a successfully deployed AMS, follow the cmds below to automatically migrate all your SAP HANA &amp; SAP NetWeaver providers.

  1. Log into [Azure Portal](https://ms.portal.azure.com/?feature.canmodifystamps=true&amp;microsoft_azure_workloadmonitor=s1&amp;appInsightsExtension=ppe&amp;microsoft_azure_workloadmonitor_assettypeoptions=%7B%22SapMonitorV2%22%3A%7B%22options%22%3A%22%22%7D%7D#home) and open PowerShell. Alternatively, you can use your local PowerShell.

![](RackMultipart20220302-4-8k1tza_html_884e5c299f33610f.png)

  1. Clone migration GitHub repository

_ **git clone** _ [_ **https://github.com/Azure/AMS-Migration.git** _](https://github.com/Azure/AMS-Migration.git)

  1. Set context of migration by providing your subscription ID and Tenant ID.

_**[string]$subscriptionId = &quot;\&lt;subscription ID\&gt;&quot;**_

_**[string]$tenantId = &quot;\&lt;Tenant ID\&gt;&quot;**_

You can find your subscription ID by navigating to your AMS (classic) resource -\&gt; overview page.

![](RackMultipart20220302-4-8k1tza_html_a318278767c2216a.png)

You can find tenant ID by navigating to Azure Active Directory in Azure portal -\&gt; overview page.

![](RackMultipart20220302-4-8k1tza_html_4d6f70e3d6c28b8d.png)

  1. Select which providers you want to migrate. You can choose between 3 options
    - Option 1: All providers - Migrates all SAP HANA &amp; SAP NetWeaver providers
    - Option 2: &quot;saphana&quot; providers – Migrates all SAP HANA providers
    - Option 3: &quot;sapnetweaver&quot; providers – Migrates all SAP NetWeaver providers

_We recommend Option 1._

Please execute the following cmd:

_**[string]$providerType = &quot;all&quot;**_

_ **OR** _

_**[string]$providerType = &quot;saphana&quot;**_

_ **OR** _

_**[string]$providerType = &quot;sapnetweaver&quot;**_

  1. Provider the AMS (classic) resource ARM ID and new AMS resource ARM ID. You can find those by navigating to AMS resource -\&gt; properties -\&gt; Resource ID. Then, execute the following cmds:

_**[string]$amsv1ArmId = &quot;\&lt;AMS (classic) ARM ID\&gt;&quot;**_

_**[string]$amsv2ArmId = &quot;\&lt;AMS ARM ID\&gt;&quot;**_

Find resource ID for AMS (classic) resource:

![](RackMultipart20220302-4-8k1tza_html_4066082f4a3f1eaf.png)

Find resource ID for AMS resource:

![](RackMultipart20220302-4-8k1tza_html_9c00b631a67e8805.png)

  1. Execute the script by using the following cmd:

_ **$command = &quot;.\Migration.ps1 -subscriptionId $subscriptionId -tenantId $tenantId -providerType $providerType -amsv1ArmId $amsv1ArmId -amsv2ArmId $amsv2ArmId&quot;** _

_ **Invoke-Expression $command** _

After the script executes successfully, you will see the following output. (@Mohit to put screenshot)

1. _ **Optional but HIGHLY Recommended:** _After successfully migrating all SAP HANA &amp; SAP NetWeaver providers, navigate back to AMS (classic) resource and m_anually_ delete all SAP HANA &amp; SAP NetWeaver providers. Since these providers have already migrated to AMS resource you will continue to receive monitoring telemetry in same Log Analytics workspace from these.

_Please note:_ You can choose to _not_ delete these providers in AMS (classic) resource after successfully migrating these providers – AMS will work just fine. However, you will incur additional costs on log analytics workspace since duplicate data will get pumped into it (from both AMS (classic) and AMS). Therefore, we highly recommend that you delete all successfully migrated providers from AMS (classic) resource.

1.  Optional: manually recreate all alert rules for SAP HANA &amp; SAP NetWeaver in new AMS resource.

If you have other providers besides SAP HANA &amp; SAP NetWeaver, please check this guide next month. AMS engineering team is planning to support other providers such as High-availability (pacemaker) cluster, SQL Server and OS in coming months.

Please DO NOT DELETE AMS (classic) resource even after successfully migrating all providers.

Please DO NOT DELETE AMS (classic) managed resource group even after successfully migrating all providers.

For data continuity purpose, if you are reusing the log analytics workspace from AMS (classic) for AMS, deleting either AMS (classic) resource or managed resource group will lead to deletion of log analytics workspace. Unfortunately, that would lead to losing all previously collected telemetry from AMS (classic) and halt new telemetry collection from AMS.

Support

Please use &#39;Issues&#39; in GitHub repository to open support cases for AMS engineering team.

![](RackMultipart20220302-4-8k1tza_html_9cd32e8fa1addb68.png)