$CommandsToExport = @()
$Global:token = $null 
$Global:profileName = $null
$Global:APIVersion = $null 

$UpBankConfigurationFile = Join-Path $env:LOCALAPPDATA UpBankConfiguration.clixml
if (Test-Path $UpBankConfigurationFile) {
    $UpBankConfiguration = Import-Clixml $UpBankConfigurationFile

    if ($UpBankConfiguration.APIVersion) {
        $Global:APIVersion = $UpBankConfiguration.APIVersion
    }

    if ($UpBankConfiguration.defaultProfile) {
        $profile = $UpBankConfiguration.defaultProfile
        $Global:token = [System.Runtime.InteropServices.marshal]::PtrToStringAuto([System.Runtime.InteropServices.marshal]::SecureStringToBSTR($UpBankConfiguration.$profile.PersonalAccessToken))
    }
}
else {
    $UpBankConfiguration = @{
        APIVersion = "v1"
    }
    $Global:APIVersion = "v1"
}

function Set-UpBankCredential {
    <#
.SYNOPSIS
Sets the default Up Bank API credentials.

.DESCRIPTION
Sets the default Up Bank API credentials. Configuration values can
be securely saved to a user's profile using Save-UpBankConfiguration.

.PARAMETER Credential
A standard Powershell Credential object. 

.EXAMPLE
$cred = Get-Credential -Message 'Custom message...' -UserName 'Custom Username'
Set-UpBankCredential -Credential $cred

.LINK
http://darrenjrobinson.com/

#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSCredential]$Credential
    )

    $newProfile = @{$Credential.UserName = @{PersonalAccessToken = $Credential.Password } }
    $UpBankConfiguration += $newProfile 
    $Global:token = [System.Runtime.InteropServices.marshal]::PtrToStringAuto([System.Runtime.InteropServices.marshal]::SecureStringToBSTR($Credential.Password))
    $Global:profileName = $Credential.UserName
}
$CommandsToExport += 'Set-UpBankCredential'


function Switch-UpBankProfile {
    <#
.SYNOPSIS
Changes the Up Bank Account Credentials used to a different Up Bank Profile.

.DESCRIPTION
Changes the Up Bank Account Credentials used to a different Up Bank Profile.
Optionally sets the default Up Bank API credentials to a different profile. 
Configuration values can be securely saved to a user's profile using Save-UpBankConfiguration.

.PARAMETER profile
Profile Name to switch too. 

.PARAMETER default
(Optional) Set the profile being switched to as the new Default Profile that will be loaded on Module Load. 

.EXAMPLE
Switch-UpBankProfile -profile Darren

.EXAMPLE
Switch-UpBankProfile -profile Darren -default 

.LINK
http://darrenjrobinson.com/

#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$profile,
        [Parameter(Mandatory = $false, Position = 0)]
        [switch]$default
    )

    if ($UpBankConfiguration.$profile) {
        $Global:token = [System.Runtime.InteropServices.marshal]::PtrToStringAuto([System.Runtime.InteropServices.marshal]::SecureStringToBSTR($UpBankConfiguration.$profile.PersonalAccessToken))

        if ($default) {
            $UpBankConfiguration.defaultProfile = $profile
            Export-Clixml -Path $UpBankConfigurationFile -InputObject $UpBankConfiguration
        }
    }
    else {
        Write-Error "No Profile with name $($profile) was found in the Up Bank Configuration file."
        break
    }
}
$CommandsToExport += 'Switch-UpBankProfile'


function Save-UpBankConfiguration {
    <#
.SYNOPSIS
    Saves default Up Bank configuration to a file in the current users Profile.

.DESCRIPTION
    Saves default Up Bank configuration to a file within the current
    users Profile. If it exists, this file is then read, each time the
    Up Bank Module is imported. Allowing settings to persist between
    sessions.

.EXAMPLE
    Save-UpBankConfiguration

.LINK
    http://darrenjrobinson.com/
#>

    [CmdletBinding()]
    param ([switch]$default)
    if ($default) { $UpBankConfiguration.defaultProfile = $Global:profileName }

    Export-Clixml -Path $UpBankConfigurationFile -InputObject $UpBankConfiguration

}
$CommandsToExport += 'Save-UpBankConfiguration'

function Test-UpBankAPI {
    <#
.SYNOPSIS
Ping UpBank

.DESCRIPTION
Ping UpBank

.PARAMETER URI
(Optional) Path of UpBank Ping URI
Defaults to https://api.up.com.au/api/v1/util/ping

.PARAMETER token
Personal Access Token

.EXAMPLE
Test-UpBankAPI -token up:yeah:Y3Rh981Ez.....py

.LINK
http://darrenjrobinson.com/

#>

    param()

    if (!$token) {
        Write-Error "No Personal Access Token found in Up Bank Configuration. Use Set-UpBankCredential and Save-UpBankConfiguration to securely store you Up Bank Personal Access Token."
        break
    }
    
    try {

        $response = Invoke-RestMethod -Method Get `
            -Uri "https://api.up.com.au/api/$($APIVersion)/util/ping" `
            -Headers @{Authorization = "Bearer $($token)" }
        return $response.meta  
    }
    catch {    
        Write-Error $_
        break 
    }
}
$CommandsToExport += 'Test-UpBankAPI'

function Get-UpBankAccounts {
    <#
.SYNOPSIS
List UpBank Accounts

.DESCRIPTION
List UpBank Accounts

.PARAMETER pageSize
The number of records to return in each page. Defaults to 100

.EXAMPLE
Get-UpBankAccounts 

.LINK
http://darrenjrobinson.com/

#>

    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [String] $pageSize = "100"
    )

    if ($token) {
        try {
            if (!$pageSize -lt "100") {
                $recordsToReturn = $pageSize
            }
            else {
                $recordsToReturn = $pageSize
                $pageSize = "100"
            }

            $response = Invoke-RestMethod -Method Get `
                -Uri "https://api.up.com.au/api/$($APIVersion)/accounts?page[size]=$($pageSize)" `
                -Headers @{Authorization = "Bearer $($token)" }
            
            if ($response.links.next) {
                $fullResponse = $null 
                $fullResponse += $response.data
                while ($response.links.next) {
                    $results = $null 
                    $results = Invoke-RestMethod -Method Get `
                        -Uri $response.links.next `
                        -Headers @{Authorization = "Bearer $($token)" }
                    if ($results) {
                        $fullResponse += $results.data
                        $response = $results
                    }
                    if ($fullResponse.count -gt $recordsToReturn) {
                        return $fullResponse | Select-Object -First $recordsToReturn
                        break  
                    }
                }
                return $fullResponse.data
            }
            else {
                return $response.data  
            }

        }
        catch {    
            Write-Error $_
            break 
        }
    }
    else {
        Write-Error "No Personal Access Token found in Up Bank Configuration. Use Set-UpBankCredential and Save-UpBankConfiguration to securely store you Up Bank Personal Access Token."
        break
    }
}
$CommandsToExport += 'Get-UpBankAccounts'

function Get-UpBankAccount {
    <#
.SYNOPSIS
Get an UpBank Account

.DESCRIPTION
Get an UpBank Account

.PARAMETER id
(Required) The id of account to return 

.EXAMPLE
Get-UpBankAccount -id af78838b-95a9-47f6-aa38-70d827af9539

.LINK
http://darrenjrobinson.com/

#>

    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $id
    )

    if ($token) {
        try {
            $response = Invoke-RestMethod -Method Get `
                -Uri "https://api.up.com.au/api/$($APIVersion)/accounts/$($id)" `
                -Headers @{Authorization = "Bearer $($token)" }
            return $response.data  
        }
        catch {    
            Write-Error $_
            break 
        }
    }
    else {
        Write-Error "No Personal Access Token found in Up Bank Configuration. Use Set-UpBankCredential and Save-UpBankConfiguration to securely store you Up Bank Personal Access Token."
        break
    }
}
$CommandsToExport += 'Get-UpBankAccount'

function Get-UpBankTransactions {
    <#
.SYNOPSIS
Retrieve a list of all transactions across all accounts for the currently authenticated user.

.DESCRIPTION
Retrieve a list of all transactions across all accounts for the currently authenticated user.

.PARAMETER pageSize
The number of records to return in each page. Defaults to 100

.PARAMETER since
(Optional) The start date-time from which to return records, formatted according to rfc-3339.

.PARAMETER until
(Optional) The end date-time up to which to return records, formatted according to rfc-3339.

.EXAMPLE
Get-UpBankTransactions -pageSize 30 

.EXAMPLE
Get-UpBankTransactions -pageSize 30 -since 2020-02-01T01:02:03+10:00

.EXAMPLE
Get-UpBankTransactions -pageSize 30 -until 2020-02-01T01:02:03+10:00


.LINK
http://darrenjrobinson.com/

#>

    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [String] $pageSize = "100",
        [Parameter(Mandatory = $false, Position = 0)]
        [String] $since,
        [Parameter(Mandatory = $false, Position = 0)]
        [String] $until
    )

    if ($token) {
        Add-Type -AssemblyName System.Web
        try {
            [boolean]$blnPage, $blnSince, $blnUntil = $false 
            $baseURI = "https://api.up.com.au/api/$($APIVersion)/transactions"
            $query = $null 

            if (!$pageSize -lt "100") {
                $recordsToReturn = $pageSize
                $query = "?page[size]=100"
            }
            else {
                $recordsToReturn = $pageSize
                $query = "?page[size]=$($pageSize)"
            }

            if ($since) {
                [boolean]$blnSince = $true 
                if ($blnPage) {
                    $query += "&filter[since]=$($since)"
                }
                else {
                    $query = "?filter[since]=$($since)"
                }
            }
            if ($until) {
                [boolean]$blnUntil = $true 

                if ($blnPage -or $blnSince) {
                    $query += "&filter[until]=$($until)"
                }
                else {
                    $query = "?filter[until]=$($until)"
                }
            }

            $queryEncoded = [System.Web.HttpUtility]::UrlEncode($query)
            $queryEncoded = (Get-Culture).TextInfo.ToUpper($queryEncoded)
            $queryEncoded = $queryEncoded.Replace("%3F", "?")
            $queryEncoded = $queryEncoded.Replace("%3D", "=")
            $queryEncoded = $queryEncoded.Replace("%26", "&")
            $queryEncoded = $queryEncoded.Replace("SINCE", "since")
            $queryEncoded = $queryEncoded.Replace("FILTER", "filter")
            $queryEncoded = $queryEncoded.Replace("UNTIL", "until")
            $queryEncoded = $queryEncoded.Replace("PAGE", "page")
            $queryEncoded = $queryEncoded.Replace("SIZE", "size")

            $response = Invoke-RestMethod -Method Get `
                -Uri "$($baseURI)$($queryEncoded)" `
                -Headers @{Authorization = "Bearer $($token)" }
                
            if ($response.links.next) {
                $fullResponse = $null 
                $fullResponse += $response.data
                while ($response.links.next) {
                    $results = $null 
                    $results = Invoke-RestMethod -Method Get `
                        -Uri $response.links.next `
                        -Headers @{Authorization = "Bearer $($token)" }
                    if ($results) {
                        $fullResponse += $results.data
                        $response = $results
                    }
                    if ($fullResponse.count -gt $recordsToReturn) {
                        return $fullResponse | Select-Object -First $recordsToReturn
                        break  
                    }
                }
                return $fullResponse.data
            }
            else {
                return $response.data  
            }            
        }
        catch {    
            Write-Error $_
            break 
        }
    }
    else {
        Write-Error "No Personal Access Token found in Up Bank Configuration. Use Set-UpBankCredential and Save-UpBankConfiguration to securely store you Up Bank Personal Access Token."
        break
    }
}
$CommandsToExport += 'Get-UpBankTransactions'

function Get-UpBankTransaction {
    <#
.SYNOPSIS
Retrieve a specific Up Bank Transaction.

.DESCRIPTION
Retrieve a specific Up Bank Transaction.

.PARAMETER id
(Required) ID of the transaction to return.

.EXAMPLE
Get-UpBankTransaction -id 167ae4de-084f-4ed0-85f7-152525f790fb

.LINK
http://darrenjrobinson.com/

#>

    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $id
    )

    if ($token) {
        try {
            $response = Invoke-RestMethod -Method Get `
                -Uri "https://api.up.com.au/api/$($APIVersion)/transactions/$($id)" `
                -Headers @{Authorization = "Bearer $($token)" }
            return $response.data  
        }
        catch {    
            Write-Error $_
            break 
        }
    }
    else {
        Write-Error "No Personal Access Token found in Up Bank Configuration. Use Set-UpBankCredential and Save-UpBankConfiguration to securely store you Up Bank Personal Access Token."
        break
    }
}
$CommandsToExport += 'Get-UpBankTransaction'


function Get-UpBankAccountTransactions {
    <#
.SYNOPSIS
Retrieve a list of all transactions for a specific account for the currently authenticated user.

.DESCRIPTION
Retrieve a list of all transactions for a specific account for the currently authenticated user.

.PARAMETER accountID
(Required) Account ID to return transactions from.

.PARAMETER pageSize
The number of records to return in each page. Defaults to 100

.PARAMETER since
(Optional) The start date-time from which to return records, formatted according to rfc-3339.

.PARAMETER until
(Optional) The end date-time up to which to return records, formatted according to rfc-3339.

.EXAMPLE
Get-UpBankAccountTransactions -accountID 4bda3ac4-034e-44bc-b761-8277ccbfe2ee

.LINK
http://darrenjrobinson.com/

#>

    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $accountID,
        [Parameter(Mandatory = $false, Position = 0)]
        [String] $pageSize = "100",
        [Parameter(Mandatory = $false, Position = 0)]
        [String] $since,
        [Parameter(Mandatory = $false, Position = 0)]
        [String] $until
    )

    if ($token) {
        Add-Type -AssemblyName System.Web

        try {
            [boolean]$blnPage, $blnSince, $blnUntil = $false 
            $baseURI = "https://api.up.com.au/api/$($APIVersion)/accounts/$($accountID)/transactions"
            $query = $null 

            if (!$pageSize -lt "100") {
                $blnPage = $true
                $recordsToReturn = $pageSize
                $query = "?page[size]=100"
            }
            else {
                $blnPage = $true
                $recordsToReturn = $pageSize
                $query = "?page[size]=$($pageSize)"
            }

            if ($since) {
                [boolean]$blnSince = $true        
                if ($blnPage) {
                    $query += "&filter[since]=$($since)"
                }
                else {
                    $query = "?filter[since]=$($since)"
                }
            }
            if ($until) {
                [boolean]$blnUntil = $true 

                if ($blnPage -or $blnSince) {
                    $query += "&filter[until]=$($until)"
                }
                else {
                    $query = "?filter[until]=$($until)"
                }
            }

            $queryEncoded = [System.Web.HttpUtility]::UrlEncode($query)
            $queryEncoded = (Get-Culture).TextInfo.ToUpper($queryEncoded)
            $queryEncoded = $queryEncoded.Replace("%3F", "?")
            $queryEncoded = $queryEncoded.Replace("%3D", "=")
            $queryEncoded = $queryEncoded.Replace("%26", "&")
            $queryEncoded = $queryEncoded.Replace("SINCE", "since")
            $queryEncoded = $queryEncoded.Replace("FILTER", "filter")
            $queryEncoded = $queryEncoded.Replace("UNTIL", "until")
            $queryEncoded = $queryEncoded.Replace("PAGE", "page")
            $queryEncoded = $queryEncoded.Replace("SIZE", "size")
            
            $response = Invoke-RestMethod -Method Get `
                -Uri "$($baseURI)$($queryEncoded)"  `
                -Headers @{Authorization = "Bearer $($token)" }
                
            if ($response.links.next) {
                $fullResponse = $null 
                $fullResponse += $response.data
                while ($response.links.next) {
                    $results = $null 
                    $results = Invoke-RestMethod -Method Get `
                        -Uri $response.links.next `
                        -Headers @{Authorization = "Bearer $($token)" }
                    if ($results) {
                        $fullResponse += $results.data
                        $response = $results
                    }
                    if ($fullResponse.count -gt $recordsToReturn) {
                        return $fullResponse | Select-Object -First $recordsToReturn
                        break  
                    }
                }
                return $fullResponse.data
            }
            else {
                return $response.data  
            }
                

        }
        catch {    
            Write-Error $_
            break 
        }
    }
    else {
        Write-Error "No Personal Access Token found in Up Bank Configuration. Use Set-UpBankCredential and Save-UpBankConfiguration to securely store you Up Bank Personal Access Token."
        break
    }
}
$CommandsToExport += 'Get-UpBankAccountTransactions'

function Get-UpBankCategories {
    <#
.SYNOPSIS
List UpBank Categories 

.DESCRIPTION
List UpBank Categories 

.PARAMETER pageSize
The number of records to return in each page. Defaults to 100

.EXAMPLE
Get-UpBankCategories 

.LINK
http://darrenjrobinson.com/

#>

    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [String] $pageSize = "100"
    )

    if ($token) {
        try {
            if (!$pageSize -lt "100") {
                $recordsToReturn = $pageSize
            }
            else {
                $recordsToReturn = $pageSize
                $pageSize = "100"
            }

            $response = Invoke-RestMethod -Method Get `
                -Uri "https://api.up.com.au/api/$($APIVersion)/categories?page[size]=$($pageSize)" `
                -Headers @{Authorization = "Bearer $($token)" }
            
            if ($response.links.next) {
                $fullResponse = $null 
                $fullResponse += $response.data
                while ($response.links.next) {
                    $results = $null 
                    $results = Invoke-RestMethod -Method Get `
                        -Uri $response.links.next `
                        -Headers @{Authorization = "Bearer $($token)" }
                    if ($results) {
                        $fullResponse += $results.data
                        $response = $results
                    }
                    if ($fullResponse.count -gt $recordsToReturn) {
                        return $fullResponse | Select-Object -First $recordsToReturn
                        break  
                    }
                }
                return $fullResponse.data
            }
            else {
                return $response.data  
            }

        }
        catch {    
            Write-Error $_
            break 
        }
    }
    else {
        Write-Error "No Personal Access Token found in Up Bank Configuration. Use Set-UpBankCredential and Save-UpBankConfiguration to securely store you Up Bank Personal Access Token."
        break
    }
}
$CommandsToExport += 'Get-UpBankCategories'

function Get-UpBankCategory {
    <#
.SYNOPSIS
Retrieve a specific Up Bank Category.

.DESCRIPTION
Retrieve a specific Up Bank Category.

.PARAMETER id
(Required) ID of the Category to return.

.EXAMPLE
Get-UpBankCategory -id technology

.LINK
http://darrenjrobinson.com/

#>

    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $id
    )

    if ($token) {
        try {
            $response = Invoke-RestMethod -Method Get `
                -Uri "https://api.up.com.au/api/$($APIVersion)/categories/$($id)" `
                -Headers @{Authorization = "Bearer $($token)" }
            return $response.data  
        }
        catch {    
            Write-Error $_
            break 
        }
    }
    else {
        Write-Error "No Personal Access Token found in Up Bank Configuration. Use Set-UpBankCredential and Save-UpBankConfiguration to securely store you Up Bank Personal Access Token."
        break
    }
}
$CommandsToExport += 'Get-UpBankCategory'

function Get-UpBankTags {
    <#
.SYNOPSIS
List UpBank Tags 

.DESCRIPTION
List UpBank Tags 

.PARAMETER pageSize
The number of records to return in each page. Defaults to 100

.EXAMPLE
Get-UpBankTags 

.LINK
http://darrenjrobinson.com/

#>

    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [String] $pageSize = "100"
    )

    if ($token) {
        try {
            if (!$pageSize -lt "100") {
                $recordsToReturn = $pageSize
            }
            else {
                $recordsToReturn = $pageSize
                $pageSize = "100"
            }

            $response = Invoke-RestMethod -Method Get `
                -Uri "https://api.up.com.au/api/$($APIVersion)/tags?page[size]=$($pageSize)" `
                -Headers @{Authorization = "Bearer $($token)" }
            
            if ($response.links.next) {
                $fullResponse = $null 
                $fullResponse += $response.data
                while ($response.links.next) {
                    $results = $null 
                    $results = Invoke-RestMethod -Method Get `
                        -Uri $response.links.next `
                        -Headers @{Authorization = "Bearer $($token)" }
                    if ($results) {
                        $fullResponse += $results.data
                        $response = $results
                    }
                    if ($fullResponse.count -gt $recordsToReturn) {
                        return $fullResponse | Select-Object -First $recordsToReturn
                        break  
                    }
                }
                return $fullResponse.data
            }
            else {
                return $response.data  
            }

        }
        catch {    
            Write-Error $_
            break 
        }
    }
    else {
        Write-Error "No Personal Access Token found in Up Bank Configuration. Use Set-UpBankCredential and Save-UpBankConfiguration to securely store you Up Bank Personal Access Token."
        break
    }
}
$CommandsToExport += 'Get-UpBankTags'

# SIG # Begin signature block
# MIIX8wYJKoZIhvcNAQcCoIIX5DCCF+ACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUXC4eQZtpri4l7IZ8EULQr2w2
# AlSgghMmMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggUwMIIEGKADAgECAhAECRgbX9W7ZnVTQ7VvlVAIMA0GCSqGSIb3DQEBCwUAMGUx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9v
# dCBDQTAeFw0xMzEwMjIxMjAwMDBaFw0yODEwMjIxMjAwMDBaMHIxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNp
# Z25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQD407Mcfw4R
# r2d3B9MLMUkZz9D7RZmxOttE9X/lqJ3bMtdx6nadBS63j/qSQ8Cl+YnUNxnXtqrw
# nIal2CWsDnkoOn7p0WfTxvspJ8fTeyOU5JEjlpB3gvmhhCNmElQzUHSxKCa7JGnC
# wlLyFGeKiUXULaGj6YgsIJWuHEqHCN8M9eJNYBi+qsSyrnAxZjNxPqxwoqvOf+l8
# y5Kh5TsxHM/q8grkV7tKtel05iv+bMt+dDk2DZDv5LVOpKnqagqrhPOsZ061xPeM
# 0SAlI+sIZD5SlsHyDxL0xY4PwaLoLFH3c7y9hbFig3NBggfkOItqcyDQD2RzPJ6f
# pjOp/RnfJZPRAgMBAAGjggHNMIIByTASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDAzB5BggrBgEFBQcBAQRtMGsw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcw
# AoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBP
# BgNVHSAESDBGMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93
# d3cuZGlnaWNlcnQuY29tL0NQUzAKBghghkgBhv1sAzAdBgNVHQ4EFgQUWsS5eyoK
# o6XqcQPAYPkt9mV1DlgwHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8w
# DQYJKoZIhvcNAQELBQADggEBAD7sDVoks/Mi0RXILHwlKXaoHV0cLToaxO8wYdd+
# C2D9wz0PxK+L/e8q3yBVN7Dh9tGSdQ9RtG6ljlriXiSBThCk7j9xjmMOE0ut119E
# efM2FAaK95xGTlz/kLEbBw6RFfu6r7VRwo0kriTGxycqoSkoGjpxKAI8LpGjwCUR
# 4pwUR6F6aGivm6dcIFzZcbEMj7uo+MUSaJ/PQMtARKUT8OZkDCUIQjKyNookAv4v
# cn4c10lFluhZHen6dGRrsutmQ9qzsIzV6Q3d9gEgzpkxYz0IGhizgZtPxpMQBvwH
# gfqL2vmCSfdibqFT+hKUGIUukpHqaGxEMrJmoecYpJpkUe8wggVVMIIEPaADAgEC
# AhAM7NF1d7OBuRMX7VCjxmCvMA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25p
# bmcgQ0EwHhcNMjAwNjE0MDAwMDAwWhcNMjMwNjE5MTIwMDAwWjCBkTELMAkGA1UE
# BhMCQVUxGDAWBgNVBAgTD05ldyBTb3V0aCBXYWxlczEUMBIGA1UEBxMLQ2hlcnJ5
# YnJvb2sxGjAYBgNVBAoTEURhcnJlbiBKIFJvYmluc29uMRowGAYDVQQLExFEYXJy
# ZW4gSiBSb2JpbnNvbjEaMBgGA1UEAxMRRGFycmVuIEogUm9iaW5zb24wggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDCPs8uaOSScUDQwhtE/BxPUnBT/FRn
# pQUzLoBTKW0YSKAxUbEURehXJuNBfAj2GGnMOHaB3EvdbxXl1NfLOo3wtRdro04O
# MjOH56Al/9+Rc6DNY48Pl9Ogvuabglah+5oDC/YOYjZS2C9AbBGGRTFjeGHT4w0N
# LLPbxyoTF/wfqZNNy5p+C7823gDR12OvWFgEdTiDnVkn3phxGy8xlK7yrJwFQ0Sn
# z8RknEFSaoKnuYqLvaOiOSG77q6M4+LbGAbwhYToaqWa4xWFFJS8XsX0+t6LA+0a
# Kb3ZEb1GyfySDW2TFf/V1RhuM4iBc6YTUUCj9BTqcpWKgkw2k2xUQHP9AgMBAAGj
# ggHFMIIBwTAfBgNVHSMEGDAWgBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAdBgNVHQ4E
# FgQU6HpAuSSJdceLWep4ajN6JIQcAOgwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQM
# MAoGCCsGAQUFBwMDMHcGA1UdHwRwMG4wNaAzoDGGL2h0dHA6Ly9jcmwzLmRpZ2lj
# ZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3JsMDWgM6Axhi9odHRwOi8vY3Js
# NC5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDBMBgNVHSAERTBD
# MDcGCWCGSAGG/WwDATAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2Vy
# dC5jb20vQ1BTMAgGBmeBDAEEATCBhAYIKwYBBQUHAQEEeDB2MCQGCCsGAQUFBzAB
# hhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTgYIKwYBBQUHMAKGQmh0dHA6Ly9j
# YWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURDb2RlU2ln
# bmluZ0NBLmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IBAQA1agcO
# M3seD1Cs5pnHRXwwrhzieRgF4UMJgDI/9KrBh4C0o8DsXvaa+YlXoTdhmeKW/xv5
# i9mkVNmvD3wa3AKe5CNwiPc5kx96lC7BXWfdLoY7ejfTGkoa7qHR3gusmQhuZW+L
# dFmvtTyu4eqcjhOBthoJYp3B8tv8JR99pSxFfsE6C4VGdhKHAmZkDMiaAHHava9Z
# xl4+Uof+TuS6lQBZJjw8Xw76W93DNU9JUNb4+hOp8jir1q7/RTvtQ3QWr+iEzJD8
# JRfvfXF4LpFvlOOWYOF22EU/ciGjUVfQYi7nk/LnHzipb46747K1BwAVnHbYMDx0
# BRtLc/s4g9qZxTrxMYIENzCCBDMCAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8G
# A1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQ
# DOzRdXezgbkTF+1Qo8ZgrzAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUKxGjBOhYfIspZFAkqnoS
# 0fZswpQwDQYJKoZIhvcNAQEBBQAEggEAH8/62j7CLGN555WK0TIeBpqmos1X3Sn2
# 4eS36u3RB/6KnvDgIN/0d3LamvhXjMRuJUxBjQKhRuXv8Z8pk81UdZk357MzSHn8
# uHvKcluvVUMxvw46+8XRJrPU6hwadlsWaK0f7STuseqhcjX+t0x3pqgV+l6/AIRM
# F3zZ2L/GAyl1n1GWfjZL6GbWvDRQCgGqaWbpekKdDXmkckWNb7ra5cKVM5s146Dw
# 2rqUmYlSjGm/XC8d8iusYiIvdyBiNew2/iCAu35HlY9PCsCEXev0krzZjtAA5Ty0
# lTmjKcN8KcvXmh8wGdycdTp5tDmIDeEuzUsapSQqMfkZw6wKSEj5ZaGCAgswggIH
# BgkqhkiG9w0BCQYxggH4MIIB9AIBATByMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQK
# ExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBT
# dGFtcGluZyBTZXJ2aWNlcyBDQSAtIEcyAhAOz/Q4yP6/NW4E2GqYGxpQMAkGBSsO
# AwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEP
# Fw0yMDA4MzEwNjQzNTdaMCMGCSqGSIb3DQEJBDEWBBQdveAGXCwIcsJHfzP/PEJ3
# NdaM3DANBgkqhkiG9w0BAQEFAASCAQBBWBMkv8LF0HmlMXxgp/RkCqhQPhHtaW5b
# 6kQ+1aTsaylFw/6xNkH4DpiVSr+qvDfnhROUHTNt6d7qkf4oEoJU6Ju3pIdE6/sU
# cXmZIb6bp/lOHASdtXrNHeDNrL1TV0f0AUi21QO3VE59wobVjmCroKh84iju91WW
# qmJNTtsLu33jZFJka+cZT+K2EWmjFJld8f59T4ekXGKY4hviwtn1wY4jFtG7NHXC
# 5o5gQ1wHoXWnpzxMouRr3WeYumtPadvvKEfWB+Oclht87MVsOaqnK/BXTv+u1jp7
# UpUX2Pkxv/2S8iWENdNnm0N8ooS4SEKR13AZefH4x3TZJRkb1yd8
# SIG # End signature block
