# Define the path to your CSV file
$csvPath = "C:\path\to\your\guestUsers.csv"

# Define the Object ID or Name of the security group
$securityGroupObjectId = "your-security-group-object-id"

# Install the AzureAD module if not already installed
# Install-Module AzureAD

# Connect to Azure AD
Connect-AzureAD

# Import users from the CSV file
$guestUsers = Import-Csv -Path $csvPath

foreach ($user in $guestUsers) {
    try {
        # Create a new guest user
        $newGuestUser = New-AzureADMSInvitation -InvitedUserEmailAddress $user.Email -InviteRedirectUrl "https://myapps.microsoft.com" -SendInvitationMessage $true

        # Add the guest user to the security group
        Add-AzureADGroupMember -ObjectId $securityGroupObjectId -RefObjectId $newGuestUser.InvitedUser.Id

        Write-Host "User $($user.Email) invited and added to the group successfully."
    }
    catch {
        Write-Host "Error inviting or adding user $($user.Email): $_"
    }
}
