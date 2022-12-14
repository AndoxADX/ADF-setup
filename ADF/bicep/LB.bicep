param Prefix string

@allowed([
  'I'
  'D'
  'T'
  'U'
  'P'
  'S'
  'G'
  'A'
])
param Environment string = 'D'

@allowed([
  '0'
  '1'
  '2'
  '3'
  '4'
  '5'
  '6'
  '7'
  '8'
  '9'
])
param DeploymentID string = '1'
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object



var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var subscriptionId = subscription().subscriptionId
var Domain = split(Global.DomainName, '.')[0]
var resourceGroupName = resourceGroup().name

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}
var VNetID = resourceId(subscriptionId, resourceGroupName, 'Microsoft.Network/VirtualNetworks', '${Deployment}-vn')
var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'

var LBInfo = contains(DeploymentInfo, 'LBInfo') ? DeploymentInfo.LBInfo : []

var LB = [for (lb,Index) in LBInfo : {
  match: ((Global.CN == '.') || contains(array(Global.CN), lb.Name))
}]

module PublicIP 'x.publicIP.bicep' = [for (lb,index) in LBInfo: if(LB[index].match) {
  name: 'dp${Deployment}-LB-publicIPDeploy${lb.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    NICs: lb.FrontEnd
    VM: lb
    PIPprefix: 'lb'
    Global: Global
  }
}]

module LBs 'LB-LB.bicep' = [for (lb,index) in LBInfo: if(LB[index].match) {
  name: 'dp${Deployment}-LB-Deploy${lb.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
    backEndPools: (contains(lb, 'BackEnd') ? lb.BackEnd : json('[]'))
    NATRules: (contains(lb, 'NATRules') ? lb.NATRules : json('[]'))
    NATPools: (contains(lb, 'NATPools') ? lb.NATPools : json('[]'))
    outboundRules: (contains(lb, 'outboundRules') ? lb.outboundRules : json('[]'))
    Services: (contains(lb, 'Services') ? lb.Services : json('[]'))
    probes: (contains(lb, 'probes') ? lb.probes : json('[]'))
    LB: lb
    Global: Global
  }
  dependsOn: [
    PublicIP
  ]
}]
