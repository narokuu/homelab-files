# Connect to Exchange Online PowerShell module
Connect-ExchangeOnline

# Get a list of users with an Office 365 E5 license
$E5Users = Get-MSOLUser -All | Where-Object {$_.Licenses.AccountSkuId -like "*:ENTERPRISEPACK"}

# Loop through the list of E5 users and change their license to Microsoft Business Premium
foreach ($user in $E5Users) {
    $newLicense = New-MsolLicenseOptions -AccountSkuId "yourdomain:BUSINESSPREMIUM" 
    Set-MsolUserLicense -UserPrincipalName $user.UserPrincipalName -LicenseOptions $newLicense
    Write-Host "Changed license for $($user.UserPrincipalName) from E5 to Business Premium."