#!/usr/bin/bash
# Azure CLI script to deploy an Azure Database for PostgreSQL server and set up a read replica in another region with virtual endpoint

# Customize these values before running this script
resourceGroup="my-virtual-endpoint-test"
location="westus3"
replicaLocation="swedencentral"
primaryServerName="my-primary"
replicaServerName="my-replica"
virtualEndpointBase="my-server-endpoint"
tier="GeneralPurpose"
skuName="Standard_D2ds_v4"
adminUser="myadmin"

# Create an Azure resource group
az group create --name $resourceGroup --location $location

# Create a new PostgreSQL flexible server instance.
# Note: Setting public access to None, and assuming you've set an environment variable $password for the admin password
az postgres flexible-server create \
  --name $primaryServerName \
  --resource-group $resourceGroup \
  --location $location \
  --tier $tier \
  --sku-name $skuName \
  --admin-user $adminUser \
  --admin-password $password \
  --version 18 

# Create a read replica in a different zone
az postgres flexible-server replica create \
  --replica-name $replicaServerName \
  --resource-group $resourceGroup \
  --source-server $primaryServerName \
  --location $replicaLocation \
  --tier $tier \
  --sku-name $skuName 

# Create a writer endpoint
az postgres flexible-server virtual-endpoint create \
  --resource-group $resourceGroup \
  --server-name $primaryServerName \
  --name $virtualEndpointBase \
  --endpoint-type ReadWrite \
  --members $replicaServerName

# Show endpoints
az postgres flexible-server virtual-endpoint list \
  --resource-group $resourceGroup \
  --server-name $primaryServerName -o table
