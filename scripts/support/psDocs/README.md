# PSDocs Related scripts

* [**generateTemplateReadme.ps1**](./generateTemplateReadme.ps1) - Script to generate README.md for the bicep template
 process.

## generateTemplateReadme.ps1

To execute `generateTemplateReadme.ps1`, make sure the following metadata are defined in the Bicep file, and run:

```PowerShell
./generateTemplateReadme.ps1 -templatePath <path-to-bicep-file>
```

The metadata of the bicep template must contain the following attributes:

- name
- description
- summary

For example:

```bicep

  metadata name = 'Management Group Hierarchy Template'
  metadata description = 'This template deploys the Management Group Hierarchy in an Azure tenant. It is used to create all child management groups under the tier-1 management group "ABCD".'
  metadata summary = 'Deploys the Management Group Hierarchy in an Azure tenant.'

```
