
##### HOW TO CONNECT TO BASTION HOST #####

 1) HAVE THE PRIVATE SSH KEYPAIR:

 2) CONVERT TO OpenSSH NORMAL FORMAT:
 
 3) Change SSH KEY PERMISISONS [Windows_11] [PowerShell]:

---------------------------------------------------------------------------------------------

$path = "C:\Users\simeo\Desktop\IT_General\KeyPairs\Test_env"

$acl = Get-Acl $path
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "BUILTIN\Users", "FullControl", "Allow"
)
$acl.RemoveAccessRule($rule)  
Set-Acl $path $acl  

$acl = Get-Acl $path
$acl.SetAccessRuleProtection($True, $False)  # Protect the file from inheritance
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "simeo", "FullControl", "Allow"
)
$acl.AddAccessRule($rule)  
Set-Acl $path $acl  

---------------------------------------------------------------------------------------------

##### How to Connect to Bastion_Host (SSH Agent Forwarding) #####

Check correct file permissions: 
Get-Acl C:\Users\simeo\Desktop\IT_General\KeyPairs\Test_env | Format-List

Add key to ssh-agent with PowerShell:
ssh-add C:\Users\simeo\Desktop\IT_General\KeyPairs\Test_env

Check if key is importer correctly in PowerShell:
ssh-add -L

Connect to Bastion_Host in PowerShell:
ssh -A -i C:\Users\simeo\Desktop\IT_General\KeyPairs\Test_env ec2-user@13.217.59.81

Check if key is correctly forwarded to the Bastion_Host:
ssh-add -L

Connect to servers in the private subnets using bastion ec2-user: 
ssh ec2-user@ip-10-0-0-42.ec2.internal

