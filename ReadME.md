# Up Bank PowerShell Module

PowerShell Module for [Up Bank](https://up.com.au/)

[![PSGallery Version](https://img.shields.io/powershellgallery/v/UpBank.svg?style=flat&logo=powershell&label=PSGallery%20Version)](https://www.powershellgallery.com/packages/UpBank) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/UpBank.svg?style=flat&logo=powershell&label=PSGallery%20Downloads)](https://www.powershellgallery.com/packages/UpBank)

## Description
A PowerShell Module enabling simple methods for accessing your Up Bank Account. 

## Installation
Install from the PowerShell Gallery on Windows PowerShell 5.1+ or PowerShell Core 6.x or PowerShell.

```
Install-Module -name UpBank
```

## Cmdlets
The module currently contains 12 cmdlets 

- ### Set-UpBankCredential
Sets the default Up Bank API credentials used to authenticate to the Up Bank API

- ### Save-UpBankConfiguration
Saves default Up Bank configuration to a file in the current users Profile.
If this configuration file exists when the module is loaded the default profile is loaded automatically allowing profile settings to persist between sessions.
**Note:** PersonalAccessTokens are encrypted and the configuration file can not be used outside of the users profile that created the configuration.

- ### Switch-UpBankProfile
 Changes the Up Bank Account Credentials used to a different Up Bank Profile.

- ### Test-UpBankAPI
Test the credentials configured are valid and the API can be accessed.

- ### Get-UpBankAccounts
List UpBank Accounts.

- ### Get-UpBankAccount
Get a specific UpBank Account

- ### Get-UpBankTransactions
Retrieve a list of all transactions across all accounts for the currently authenticated user.

- ### Get-UpBankTransaction
Retrieve a specific Up Bank Transaction.

- ### Get-UpBankAccountTransactions
Retrieve a list of all transactions for a specific account for the currently authenticated user.

- ### Get-UpBankCategories 
Retrieve a list of all categories.

- ### Get-UpBankCategory
Retrieve a specific Up Bank Category.

- ### Get-UpBankTags 
Retrieve a list of all tags.

## Set Up Bank Credentials
The module supports multiple sets of credentials. One set can be set as default and will be automatically and securely loaded when the module loads. The avoids having to set the credentials everytime. 

To be used in conjunction with **Save-UpBankCredential** to negate the need to use **Set-UpBankCredential** each time the module is loaded. 

Set-UpBankCredential needs to be passed a PowerShell Credential object. This can be generated using **_Get-Credential_**
The value provided for User (when using get-credential) is used as the profile name.

```
$myUpBankCredentials = Get-Credential
Set-UpBankCredential -credential $myUpBankCredentials 
```

## Save Up Bank Configuration
Securely save credentials for an Up Bank user to the configuration file. 

The optional **default** switch means this profile will be automatically loaded next time the Up Bank PowerShell Module is loaded. 

Use **_Switch-UpBankProfile_** to switch to another Profile.

```
Save-UpBankConfiguration -default
```

## Switch Up Bank Configuration Profiles
The Up Bank PowerShell Module allows multiple account profiles to be configured. 

When using **_Set-UpBankCredential_** the value provided for User (when using get-credential) is used as the profile name. 

Switch-UpBankProfile -profile [ProfileName] can be used to switch profiles. 

```
Switch-UpBankProfile -profile Darren 
```

### Switch Up Bank Configuration Profiles and make the profile switched to the new default
Switch the current configuration to a profile name Kate and make it the new default profile. 

The Kate profile will then be loaded automatically the next time the module is loaded. 

```
Switch-UpBankProfile -profile Kate -default
```

## Inspect the Up Bank Configuration Settings
The following command to be used to see what profiles are stored in the Up Bank Configuration file.

**Note:** The PersonalAccessTokens are encrypted and the configuration file can not be used outside of the users profile that created the configuration. 

```
$configFile = Join-Path $env:LOCALAPPDATA UpBankConfiguration.clixml
import-clixml $configFile
```

## Test Up Bank API Connectivity
Test to see if the currently loaded credentials are valid by testing Up Bank API connectivity.

```
Test-UpBankAPI -verbose
```

## Get Up Bank Accounts
List UpBank Accounts

```
$myAccounts = Get-UpBankAccounts 
Write-Host -ForegroundColor Green "$($myAccounts.count) account(s) found."
foreach ($account in $myAccounts) {
    Write-Host -ForegroundColor Blue "    $($account.attributes.displayName)"
} 
```

## Get an Up Bank Account
Get a specific Up Bank Account

```
get-UpBankAccount -id $myAccounts[0].id
```

## Get Transactions across all accounts
Get most recent transactions (defaults to 100)

```
Get-UpBankTransactions -pageSize 4 
```

Get most recent 200 transactions 
```
Get-UpBankTransactions -pageSize 200 
```

## Get Transactions Since a date and time across all accounts

Get last transactions (defaults to max 100) since 27 July 2020.
```
Get-UpBankTransactions -since 2020-07-27T09:07:54+10:00 
```

Get last 10 transactions since 27 July 2020.
```
Get-UpBankTransactions -pageSize 10 -since 2020-07-27T09:07:54+10:00 
```

### Get the last Up Bank Account Transaction across all accounts

```
(Get-UpBankTransactions -pageSize 1).attributes
```

## Get an Up Bank Transaction
```
$transaction = Get-UpBankTransactions -pageSize 1
Get-UpBankTransaction -id $transaction.id
```

## Get Transactions for a specific account
Get most recent transaction(s) (defaults to max 100) on an account

```
$myAccounts = Get-UpBankAccounts 
Get-UpBankAccountTransactions -accountID $myAccounts[0].id
```

## Get the last transaction for a specific account
Get most recent 201 transactions on an account

```
$myAccounts = Get-UpBankAccounts 
Get-UpBankAccountTransactions -accountID $myAccounts[0].id -pageSize 201
```

## Get the last 10 Transactions since a date and time for a specific account
```
Get-UpBankAccountTransactions -accountID $myAccounts[1].id -since 2020-05-27T09:07:54+10:00 -pageSize 10
```

## Get the Transactions up to a date and time for a specific account (defaults to 100)
```
Get-UpBankAccountTransactions -accountID $myAccounts[1].id -until 2020-07-27T01:02:03+10:00 
```

## Get-UpBankCategories 
Retrieve a list of all categories.

```
Get-UpBankCategories
```

## Get-UpBankCategory
Retrieve a specific Up Bank Category.

```
Get-UpBankCategory -id technology
```

## Get-UpBankTags 
Retrieve a list of all tags.

```
Get-UpBankTags 
```

## How can I contribute to the project?
* Found an issue and want us to fix it? [Log it](https://github.com/darrenjrobinson/UpBank/issues)
* Want to fix an issue yourself or add functionality? Clone the project and submit a pull request.
* Any and all contributions are more than welcome and appreciated. 

## Keep up to date
* [Visit my blog](https://blog.darrenjrobinson.com)
* ![](http://twitter.com/favicon.ico) [Follow darrenjrobinson](https://twitter.com/darrenjrobinson)