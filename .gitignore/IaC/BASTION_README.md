
##### HOW TO CONNECT TO BASTION HOST #####

 1) HAVE THE PRIVATE SSH KEYPAIR:

 2) CONVERT TO OpenSSH NORMAL FORMAT:
 
 3) Change SSH KEY PERMISISONS [Windows_11] [PowerShell]:

==========================================================================================
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
==========================================================================================


##### Connect to bastion (SSH Agent Forwarding) #####

 4) Check correct file permissions: 
Get-Acl C:\Users\simeo\Desktop\IT_General\KeyPairs\Test_env | Format-List

 5) Add key to ssh-agent with PowerShell:
ssh-add C:\Users\simeo\Desktop\IT_General\KeyPairs\Test_env

 6) Check if key is importer correctly in PowerShell:
ssh-add -L

 7) Connect to Bastion_Host in PowerShell:
ssh -A -i C:\Users\simeo\Desktop\IT_General\KeyPairs\Test_env ec2-user@13.217.59.81

 8) Check if key is correctly forwarded to the Bastion_Host:
ssh-add -L

 9) Connect to servers in the private subnets using bastion ec2-user: 
ssh ec2-user@ip-10-0-0-42.ec2.internal

