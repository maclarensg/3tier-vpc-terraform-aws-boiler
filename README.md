# 3tier-vpc-terraform-aws-boiler

## Description

This git repo is a boiler template containing terraform script to automate creation of VPC and subnets in 3 tier architecture
This repo can be clone and modify to support CI with Travis-CI. A deploy script and .travis.yml is already provided.

## 3 Tier Architecture Network

In this boiler template, the 3 tier architecture is seggrated by AWS networking principles accirding to 3 zones.

- **Red Zone** -  The DMZ/Web layer
- **Orange Zone** - The Application layer
- **Green Zone** - The Data Storage layer

## Continous Integration/ Continous Deployment
Travis-CI is used for CI/CD. Commiting and pushing the *master* branch will trigger Travis to initiate a build. This build will first use Rake(Ruby Task Manager) to run tasks, example testing, and follow by executing a deployment script *deploy.sh* to run terraform commands and apply terraform configurations files in this repo.

To setup the credentials for Travis to access AWS. Run the following:
```
travis encrypt AWS_ACCESS_KEY_ID=<access_key> AWS_SECRET_ACCESS_KEY=<secret_access_key> 
```

## Files

- main.tf

  This files contains the provider to be used

- backend.tf

  This files instructed terraform to use a S3 bucket. S3 bucket need to be created first prior to executing terraform.

- vpc.tf

  The main file responsible for creating the 3 tier achitecture VPC. Apart from creating VPCs and Subnets. This vpc.tf defines the Network ACLs and routes private networks such as the green zone and orange to NAT egress Internet, purpose for fetching packages. Security can be redefine and tighten, by making use of a http proxy to fetch packages or setup internal package repository. Network ACLs are used to control and limit access between zones are implement as part of the 3 tier network security.

- Rakefile

  A dummy rake file for travis to run build. Test or setup can be implemented to  pre-setup Travis's VM enviroment

- .travis.yml
 
   This file is require for travis to initiate build and deploy, base on environment.
  
  

