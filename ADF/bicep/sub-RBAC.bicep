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
param Environment string

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
param DeploymentID string
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object



targetScope = 'subscription'

var enviro = '${Environment}${DeploymentID}' // D1
var deployment = '${Prefix}-${Global.orgname}-${Global.Appname}-${enviro}' // AZE2-BRW-HUB-D1
var rg = '${Prefix}-${Global.orgname}-${Global.Appname}-RG-${enviro}' // AZE2-BRW-HUB-D1

var locationlookup = json(loadTextContent('./global/prefix.json'))
var location = locationlookup[Prefix].location

var uaiinfo = contains(DeploymentInfo, 'uaiinfo') ? DeploymentInfo.uaiinfo : []
var rolesInfo = contains(DeploymentInfo, 'rolesInfo') ? DeploymentInfo.rolesInfo : []
var SPInfo = contains(DeploymentInfo, 'SPInfo') ? DeploymentInfo.SPInfo : []

var sps = [for sp in SPInfo: {
    RBAC: sp.RBAC
    name: replace(replace(replace(sp.Name, '{GHProject}', Global.GHProject), '{ADOProject}', Global.ADOProject), '{RGNAME}', rg)
}]

module UAI 'sub-RBAC-ALL.bicep' = [for (uai, index) in uaiinfo: if (bool(Stage.UAI) && contains(uai,'RBAC')) {
    name: 'dp-rbac-uai-${Prefix}-${uai.name}'
    params: {
        Deployment: deployment
        Prefix: Prefix
        rgName: rg
        Enviro: enviro
        Global: Global
        roleInfo: uai
        providerPath: 'Microsoft.ManagedIdentity/userAssignedIdentities'
        namePrefix: '-uai'
        providerAPI: '2018-11-30'
        principalType: 'ServicePrincipal'
    }
}]

module RBAC 'sub-RBAC-ALL.bicep' = [for (role, index) in rolesInfo: if (bool(Stage.RBAC)) {
    name: 'dp-rbac-role-${Prefix}-${role.name}'
    params: {
        Deployment: deployment
        Prefix: Prefix
        rgName: rg
        Enviro: enviro
        Global: Global
        roleInfo: role
        providerPath: ''
        namePrefix: ''
        providerAPI: ''
    }
}]

module SP 'sub-RBAC-ALL.bicep' = [for sp in sps: if (bool(Stage.SP)) {
    name: 'dp-rbac-sp-${Prefix}-${sp.name}'
    params: {
        Deployment: deployment
        Prefix: Prefix
        rgName: rg
        Enviro: enviro
        Global: Global
        roleInfo: sp
        providerPath: ''
        namePrefix: ''
        providerAPI: ''
        principalType: 'ServicePrincipal'
    }
}]

output enviro string = enviro
output deployment string = deployment
output location string = location
