# Azure Automation

This repository is a quick sample on using powershell and azure automation scripts.

>Note: Used to play with Azure Automation for Linux Servers


## Localhost Instructions

### Prerequisite

Ensure that you have a .ssh directory with the proper id_rsa and id_rsa.pub files located there.


### Setup

- ./initialize.ps1 <your_unique_string> <your_group> <your_vmname> <your_location>
  - Create a Resource Group
  - Create Storage Accounts
  - Create a Network Security Group
  - Create a Network
  - Create a Virtual Machine
  - Setup Automation
    - Automation Account
    - Run As Accounts and Certificates
    - Asset - RunAsConnection
    - Asset - Variables
    - Runbook - Uploads Runbooks loated in ./runbooks


