# You need to have powershell enabled. If you havent please follow the steps here to install. https://azure.microsoft.com/en-us/documentation/articles/powershell-install-configure/
Switch-AzureMode -Name AzureResourceManager

# Azure account and select a subscription (in case you have multiple subscriptions).
Add-AzureAccount

# Get list of Subscription and choose the one , where you want to host the using Get-AzureSubscription

#The storage account must be located in the same datacenter as the HDInsight cluster
# "Standard_LRS,Standard_ZRS,Standard_GRS,Standard_RAGRS,Premium_LRS" 
#

#Create storage container
$clusterNodes = 1
$version = "3.2"
$headnode = "Standard_D3"
$workernode = "Standard_D3"
#$ostype= "Windows"
$ostype= "Linux"
#Hadoop, HBase, Spark, Storm
$clustertype = "HBase"
$rootname="linx1spark1"
$vnetname = "SparklinuxHDnetwork"
$subnetName =$vnetname.ToLower() + "-snet"
$resourceGroupName = $rootname.ToLower()+"-rg"
$storageAccountName = $rootname.ToLower() + "storage"
$additionalstorageccountName1="primary"+$rootname.ToLower() 
$additionalstorageccountName2="secondary"+$rootname.ToLower() 
$containerName = $rootname.ToLower() + "container"
$clusterName = $rootname.ToLower() + "cluster"
$storagetype = "Standard_LRS"
$location = "Central US"
#Ensure the username and password.
$userName = "hadoopuser"
$password = "!!Focus2015!!"


#Add-AzureAccount
$SubscriptionName = "Internal Consumption"
Select-AzureSubscription -SubscriptionName $SubscriptionName

#Create Object to store additional storage accounts
$object = New-Object 'system.collections.generic.dictionary[string,string]'
$object.Add("storage1primary","$additionalstorageccountName1.blob.core.windows.net")
$object.Add("storage2secondary","$additionalstorageccountName2.blob.core.windows.net")



#Create Resoruce Group
New-AzureResourceGroup -name  $resourceGroupName -Location $location
#Create Storage Account 
$StorageCreationStatus = New-AzureStorageAccount -ResourceGroupName $resourceGroupName  -Name $storageAccountName -Location $location -Type $storagetype
#Create Additional Storage
$additionalsStorageCreationStatus1 = New-AzureStorageAccount -ResourceGroupName $resourceGroupName  -Name $additionalstorageccountName1 -Location $location -Type $storagetype
$additionalsStorageCreationStatus2 = New-AzureStorageAccount -ResourceGroupName $resourceGroupName  -Name $additionalstorageccountName2 -Location $location -Type $storagetype
#Get Storage Account Key
$storageaccountkey = Get-AzureStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName  | %{ $_.Key1 }

#Get Additional Storage Account Key
$additionalstorageaccountkey1 = Get-AzureStorageAccountKey -ResourceGroupName $resourceGroupName -Name $additionalstorageccountName1  | %{ $_.Key1 }
$additionalstorageaccountkey2 = Get-AzureStorageAccountKey -ResourceGroupName $resourceGroupName -Name $additionalstorageccountName2  | %{ $_.Key1 }

# Create a storage context object
$destContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageaccountkey  

# Create a storage context object for additional Storage 
$adddestContext1 = New-AzureStorageContext -StorageAccountName $additionalstorageccountName1 -StorageAccountKey $additionalstorageaccountkey1  
$adddestContext2 = New-AzureStorageContext -StorageAccountName $additionalstorageccountName2 -StorageAccountKey $additionalstorageaccountkey2  

# Create a Blob storage container
$storagecontainerStatus = New-AzureStorageContainer -Name $containerName -Context $destContext

# Create a Blob storage container
$addcontainerName1 = "con1"+$containerName1
$addcontainerName2 = "con2"+$containerName2
$additionalstoragecontainerStatus1 = New-AzureStorageContainer -Name $addcontainerName1 -Context $adddestContext1
$additionalstoragecontainerStatus2 = New-AzureStorageContainer -Name $addcontainerName2 -Context $adddestContext2

# Script location - example but not used inthis code.
$scriptlocation = "https://hdiconfigactions.blob.core.windows.net/linuxsparkconfigactionv02/spark-installer-v02.sh"

#------ Creating Networking -----------------------#

$subnet = New-AzureVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.0.64.0/24" 
Write-Host "Creating Vnet"
$vnet = New-AzureVirtualNetwork -Name $vnetname -ResourceGroupName  $resourceGroupName -Location  $location -AddressPrefix "10.0.0.0/16" -Subnet $subnet
Write-Host "Creating Subnet"
$subnetid = (Get-AzureVirtualNetworkSubnetConfig -Name $subnet.Name -VirtualNetwork $vnet).Id
Write-Host "Getting Network ID"
$networkid =  (Get-AzureVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetname).Id
Write-Host $networkid -ForegroundColor DarkMagenta
$subnetResourceID = Get-AzureResource -ResourceType "Microsoft.Network/virtualNetworks"  -ResourceGroupName $resourceGroupName |  %{ $_.ResourceId }

Write-Host "Resource Group" + $resourceGroupName
Write-Host "Cluster Name" + $clusterName
Write-Host "Storage" + "$storageAccountName.blob.core.windows.net"
Write-Host "Storage Account key" + $storageaccountKey 
Write-Host "Container name" + $containerName 
Write-Host "Cluster Nodes" + $clusterNodes
Write-Host "Subnetname"  + $subnetname
Write-Host -ForegroundColor yellow "Additional Storage" + $($object)
 

$credential = Get-Credential -UserName $userName -Message "Please enter the Username for HDInsight Cluster"

Write-Host  "Network ID"  $networkid -ForegroundColor Green
Write-Host  "Subnet Resoruce ID"  $subnetResourceID  -ForegroundColor Green

    $startDTM = (Get-Date)
    Write-Host "Creating '$clusterNodes' Node Cluster named: $clustername" -f yellow 
    
    New-AzureHDInsightCluster -ResourceGroupName $resourceGroupName `
        -Debug `
        -ClusterName $clusterName `
        -VirtualNetworkId $networkid `
        -SubnetName $subnetid `
        -AdditionalStorageAccounts $object `
        -Location $location `
        -DefaultStorageAccountName "$storageAccountName.blob.core.windows.net" `
        -DefaultStorageAccountKey $storageaccountKey `
        -DefaultStorageContainer $containerName  `
        -ClusterSizeInNodes $clusterNodes `
        -HeadNodeSize $headnode -WorkerNodeSize $workernode `
        -ClusterType $clustertype `
        -OSType $ostype `
        -HttpCredential $credential `
        -SshCredential $credential `
        -SshPublicKey "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCu0ZWTQqZx8Tlq61Y9ZnNFwvyvfN1mRnNL2satrQHKONexf5lwoFKqX5wELyRKw36TWg+jHxqUnwt6TILYiLoGohjrH+WzXVh8/rFQlxQjO9/2aKjWHoo+w1zJcQB39aQNnd+6ZxrtlbDh3F5EDoZFeFZSHeZR4/0Q1zAXKYaTENqDeuL6zBhFyxdNwtq3qjXlrI8mwjxRSh0vLgz+wpR2Jh42T9V/L8AUEZcUGzKDTrILx+VgtfPcCB/icXl/M9qA0IBPh4nwiR9EWUmEpcGwCEEjyzavEA5ut8erS8/S3vsIbi7AkD7DcPwz5jRj5EhjKOSnDwV+Fs8doj1e2YGz"
 
   
# Get End Time
$endDTM = (Get-Date)

# Echo Time elapsed
"Elapsed Time: $(($endDTM-$startDTM).totalseconds) seconds"
 

 
