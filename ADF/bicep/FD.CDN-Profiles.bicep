param Deployment string
param DeploymentURI string
param cdn object
param Global object
param Prefix string
param Environment string
param DeploymentID string

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var GlobalRGJ = json(Global.GlobalRG)
// var HubKVJ = json(Global.hubKV)
// var HubRGJ = json(Global.hubRG)

var gh = {
  globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
  globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
  globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
  globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

  // hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  // hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  // hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  // hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
// var HubKVRGName = '${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-RG-${gh.hubKVRGName}'
// var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

// resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
//   name: HubKVName
//   scope: resourceGroup(HubKVRGName)
// }

// resource cert 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' existing = {
//   name: Global.CertName
//   parent: KV
// }

resource FDWAFPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2020-11-01' existing = if (contains(cdn, 'WAFPolicy')) {
  name: '${DeploymentURI}Policyafd${cdn.WAFPolicy}'
}

resource CDNProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: toLower('${DeploymentURI}cdn${cdn.name}')
  location: 'global'
  sku: {
    #disable-next-line BCP036
    name: '${cdn.skuName}_AzureFrontDoor' //'Premium_AzureFrontDoor' // 'Standard_AzureFrontDoor' // 'Standard_Microsoft' // 'Standard_Verizon'
  }
  properties: {
    originResponseTimeoutSeconds: 240
    // identity: {
    //   type: 'SystemAssigned'
    //   // userAssignedIdentities: {
    //   //   '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    //   // }
    // }
  }
}

resource CDNProfileDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'service'
  scope: CDNProfile
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'FrontDoorAccessLog'
        enabled: true
      }
      {
        category: 'FrontDoorHealthProbeLog'
        enabled: true
      }
      {
        category: 'FrontDoorWebApplicationFirewallLog'
        enabled: true
      }
    ]
    metrics: [
      {
        enabled: true
        category: 'AllMetrics'
      }
    ]
  }
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = [for (ep, index) in cdn.endPoints: {
  name: toLower(ep.name)
  parent: CDNProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
    // autoGeneratedDomainNameLabelScope: 'ResourceGroupReuse'
  }
}]

module DNSCNAME 'x.DNS.Public.CNAME.bicep' = [for (ep, index) in cdn.endPoints: {
  name: 'dp-AddDNSCNAME-${endpoint[index].name}.${cdn.zone}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: toLower(endpoint[index].name)
    cname: endpoint[index].properties.hostName
    Global: Global
  }
}]

resource customDomains 'Microsoft.Cdn/profiles/customDomains@2021-06-01' = [for (ep, index) in cdn.endPoints: {
  name: toLower(replace('${endpoint[index].name}.${cdn.zone}', '.', '-'))
  parent: CDNProfile
  properties: {
    hostName: toLower('${endpoint[index].name}.${cdn.zone}')
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
      // secret: {
      //   id: 
      // }
    }
  }
  dependsOn: [
    DNSCNAME[index]
  ]
}]

module verifyDNS 'x.DNS.Public.TXT.bicep' = [for (ep, index) in cdn.endPoints: {
  name: 'dp-AddDNSVerifyTXT-${endpoint[index].name}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    name: '_dnsauth.${endpoint[index].name}'
    DomainNameExt: Global.DomainNameExt
    value: customDomains[index].properties.validationProperties.validationToken
  }
}]

module originGroups 'FD.CDN-Profiles-OrginGroups.bicep' = [for (originGroup, index) in cdn.endPoints: {
  name: 'dp-FD.CDN-Profiles-originGroup-${originGroup.name}'
  params: {
    Environment: Environment
    Global: Global
    Prefix: Prefix
    cdn: cdn
    originGroup: originGroup
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
  }
  dependsOn: [
    endpoint[index]
    verifyDNS[index]
  ]
}]

// var wafPolicy = {
//   id: contains(cdn, 'WAFPolicy') ? FDWAFPolicy.id : null
// }

// resource securityPolicies 'Microsoft.Cdn/profiles/securityPolicies@2021-06-01' = if (contains(cdn, 'WAFPolicy')) {
//   name: toLower('${DeploymentURI}cdn${cdn.WAFPolicy}')
//   parent: CDNProfile
//   properties: {
//     parameters: {
//       type: 'WebApplicationFirewall'
//       wafPolicy: contains(cdn, 'WAFPolicy') ? wafPolicy : null
//       associations: [
//         {
//           domains: [
//             {
//               id: customDomains.id
//             }
//           ]
//           patternsToMatch: cdn.pattern
//         }
//       ]
//     }
//   }
// }

// output domain object = customDomains.properties
