#!/usr/bin/bash
# Azure CLI script to deploy an Azure Database for PostgreSQL flexible server with secure networking using private endpoints
# Once it's set up, you can create resource in the subnet that can now connect privately to the database server
# For a guide to this script see [Setting up Postgres on Azure private endpoints using CLI](https://dev.to/guybo/setting-up-postgres-on-azure-private-endpoints-using-cli-3g27) 

# Customize these values before running this script
resourceGroup="my-private-rg"
location="westus3"
vnetName="my-private-vnet"
subnetName="my-private-subnet"
dnsZoneName="privatelink.postgres.database.azure.com"
connectionName="privatelink"
privateEndpointName="myPrivateEndpoint"
privateLinkName="privatelink"
serverName="my-private-pg-server"
adminUser="myuser"

# Create an Azure resource group, and a Virtual Network with a subnet
az group create --name $resourceGroup --location $location
az network vnet create --resource-group $resourceGroup --name $vnetName --subnet-name $subnetName --subnet-prefixes 10.0.0.0/24

# Create a new PostgreSQL flexible server instance.
# Note: Setting public access to None, and assuming you've set an environment variable $password for the admin password
az postgres flexible-server create --resource-group $resourceGroup --name $serverName --tier Burstable --sku-name Standard_B1ms --public-access None --admin-user $adminUser --admin-password $password --wait

# Once the flexible server instance is running, create a private endpoint, and attach it to the flexible server resource id by dynamically calling "az resource show" to get the resource id
az network private-endpoint create --name $privateEndpointName --connection-name $connectionName --resource-group $resourceGroup --vnet $vnetName --subnet $subnetName --private-connection-resource-id $(az resource show -g $resourceGroup -n $serverName --resource-type "Microsoft.DBforPostgreSQL/flexibleServers" --query "id" -o tsv) --group-id postgresqlServer

# Create a private DNS zone and link it to the virtual network
az network private-dns zone create --resource-group $resourceGroup --name $dnsZoneName
az network private-dns link vnet create --resource-group $resourceGroup --zone-name $dnsZoneName --name $privateLinkName --virtual-network $vnetName --registration-enabled false

# Get the private IP address of the private endpoint, and create a private DNS record to point the Postgres server name to this address
networkInterfaceId=$(az network private-endpoint show --name $privateEndpointName --resource-group $resourceGroup --query 'networkInterfaces[0].id' -o tsv)

privateIP=$(az resource show --ids $networkInterfaceId --api-version 2019-04-01 -o json | grep privateIPAddress\" | grep -oP '(?<="privateIPAddress": ")[^"]+')

az network private-dns record-set a create --name $serverName --zone-name $dnsZoneName --resource-group $resourceGroup
az network private-dns record-set a add-record --record-set-name $serverName --zone-name $dnsZoneName --resource-group $resourceGroup -a $privateIP

