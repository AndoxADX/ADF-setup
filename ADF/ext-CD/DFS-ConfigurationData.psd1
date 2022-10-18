#
# ConfigurationData.psd1
#

@{
    AllNodes = @(
        @{
            NodeName                    = "localhost"
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true

            ServiceSetStopped           = 'ShellHWDetection'

            # IncludesAllSubfeatures
            WindowsFeaturePresent       = @(
                'Failover-Clustering', 'RSAT-Clustering-PowerShell', 'RSAT-AD-PowerShell', 'FS-FileServer',
                'RSAT-File-Services', 'RSAT-Clustering-Mgmt', 'FS-DFS-Namespace', 'RSAT-DFS-Mgmt-Con',
                'Storage-Replica', 'RSAT-Storage-Replica'
            )

            ADComputerPresent           = @(
                @{
                    clustername = "AZE2{0}NTECLS03"
                    vcos        = "AZE2{0}DFS01"
                    svcaccount  = "localadmin"
                }
            )

            DisableIEESC                = $True

            PowerShellModulesPresent    = 'AzureAD', 'NTFSSecurity', 'Az'

            # Single set of features
            WindowsFeatureSetPresent    = 'GPMC', "NET-Framework-Core"

            DirectoryPresent2           = 'F:\Source'

            EnvironmentPathPresent      = 'F:\Source\Tools\'

            SOFSSharePresent            = @(
                @{ Name = "ABC" ; Volume = 'Volume1' },
                @{ Name = "DEF" ; Volume = 'Volume1' },
                @{ Name = "123" ; Volume = 'Volume2' }
            )

            LocalPolicyPresent2         = @(
                @{KeyValueName = "SOFTWARE\Microsoft\Internet Explorer\Main\NoProtectedModeBanner"; PolicyType = "User"; Data = "1"; Type = "DWord" },
                @{KeyValueName = "SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains\contoso.com\*"; PolicyType = "User"; Data = "2"; Type = "DWord" },
                @{KeyValueName = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\DontUsePowerShellOnWinX"; PolicyType = "User"; Data = "0"; Type = "DWord" },
                @{KeyValueName = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarGlomLevel"; PolicyType = "User"; Data = "1"; Type = "DWord" },
                @{KeyValueName = "Software\Policies\Microsoft\Internet Explorer\Main\DisableFirstRunCustomize"; PolicyType = "Machine"; Data = "1"; Type = "DWord" }
            )

            DirectoryPresentSource2     = @(
                @{
                    SourcePath      = '\\{0}.file.core.windows.net\source\SXS\'
                    DestinationPath = 'F:\Source\SXS\'
                    MatchSource          = $true
                },

                @{
                    SourcePath      = '\\{0}.file.core.windows.net\source\Tools\'
                    DestinationPath = 'F:\Source\Tools\'
                    MatchSource          = $true
                },

                @{
                    SourcePath      = '\\{0}.file.core.windows.net\source\AZFileSync\'
                    DestinationPath = 'F:\Source\AZFileSync\'
                    MatchSource          = $true
                }
            )

            SoftwarePackagePresent2     = @(
                @{
                    Name      = 'Storage Sync Agent'
                    Path      = 'F:\Source\AZFileSync\StorageSyncAgent_V5_WS2019.msi'
                    ProductId = '{F5EA481D-EECC-4AA8-B62D-108001DA2462}'
                    Arguments = ''
                }
            )
        }
    )
}





































