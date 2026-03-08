# How to generate documentations for Bicep templates and modules

> :memo: **NOTE:** The documentation (README.md) for all Bicep modules and templates in this repository has already been generated. You only need to re-run the documentation generation if you have made changes to any Bicep modules or templates.

This document provides instructions on how to generate documentation for Bicep templates and modules in the Azure Policy Factory repository using PSDocs.

## Table of Contents

- [How to generate documentations for Bicep templates and modules](#how-to-generate-documentations-for-bicep-templates-and-modules)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Required Bicep Metadata](#required-bicep-metadata)
  - [Generate documentation for a single Bicep file](#generate-documentation-for-a-single-bicep-file)
  - [Generate documentation for all Bicep templates](#generate-documentation-for-all-bicep-templates)
  - [Generate documentation for all Bicep modules](#generate-documentation-for-all-bicep-modules)
  - [Optional Parameters](#optional-parameters)
  - [What the script does](#what-the-script-does)

## Prerequisites

1. **PowerShell** - The script requires PowerShell 5.1 or later.
2. **Bicep CLI** - The Bicep CLI must be installed and available in the system PATH. It is used to compile `.bicep` files to ARM JSON templates before generating documentation.
3. **PSDocs PowerShell module** - Install the module by running:

```powershell
Install-Module -Name PSDocs -Scope CurrentUser
```

4. **PSDocs.Azure PowerShell module** - Install the module by running:

```powershell
Install-Module -Name PSDocs.Azure -Scope CurrentUser
```

## Required Bicep Metadata

Each Bicep file must define the following metadata attributes for the documentation to be generated correctly:

- `name` - The display name of the template or module.
- `description` - A detailed description of what the template or module does.
- `summary` - A short summary of the template or module.

For example, a **Bicep template** (`bicep/templates/policyDefinitions/main.bicep`):

```bicep
metadata name = 'Policy Definitions Template'
metadata description = 'This template deploys the policy definitions in Contoso.'
metadata summary = 'Deploys policy definitions in Contoso.'
```

A **Bicep module** (`bicep/modules/authorization/policy-definition/main.bicep`):

```bicep
metadata name = 'Policy Definitions (All scopes)'
metadata description = 'This module deploys Policy Definitions at a Management Group or Subscription scope.'
metadata summary = 'Deploys Policy Definitions at a Management Group or Subscription scope.'
```

## Generate documentation for a single Bicep file

Use the `-templatePath` parameter to generate documentation for a single Bicep template or module:

```powershell
# Generate docs for a single Bicep template
./scripts/support/psDocs/generateTemplateReadme.ps1 -templatePath ./bicep/templates/policyDefinitions/main.bicep

# Generate docs for a single Bicep module
./scripts/support/psDocs/generateTemplateReadme.ps1 -templatePath ./bicep/modules/authorization/policy-definition/main.bicep
```

This generates a `README.md` file in the same directory as the Bicep file.

## Generate documentation for all Bicep templates

Use the `-templateDirectory` parameter to generate documentation for all `main.bicep` files found recursively within a directory.

To generate documentation for **all Bicep templates**:

```powershell
./scripts/support/psDocs/generateTemplateReadme.ps1 -templateDirectory ./bicep/templates
```

This recursively finds all `main.bicep` files under `bicep/templates/` and generates a `README.md` for each one.

## Generate documentation for all Bicep modules

To generate documentation for **all Bicep modules**:

```powershell
./scripts/support/psDocs/generateTemplateReadme.ps1 -templateDirectory ./bicep/modules
```

This recursively finds all `main.bicep` files under `bicep/modules/` and generates a `README.md` for each one.

## Optional Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-templatePath` | Yes (single file) | - | Path to a single Bicep file. Cannot be used with `-templateDirectory`. |
| `-templateDirectory` | Yes (batch) | - | Path to a directory. The script recursively finds all `main.bicep` files within this directory. Cannot be used with `-templatePath`. |
| `-culture` | No | `en-us` | The culture/language for the generated documentation. |

## What the script does

1. **Locates Bicep files** - When using `-templateDirectory`, the script recursively searches for all `main.bicep` files in the specified directory.
2. **Validates metadata** - If a `metadata.json` file exists in the same directory as the Bicep file, the script validates it contains the required attributes (`itemDisplayName`, `description`, `summary`). If no `metadata.json` file exists, the script proceeds using the metadata defined in the Bicep file itself.
3. **Compiles Bicep to ARM JSON** - The script runs `bicep build` to compile the `.bicep` file into a temporary ARM JSON template, which is required by PSDocs.Azure.
4. **Generates documentation** - Uses the `PSDocs.Azure` module to generate a `README.md` file from the ARM template, including parameters, outputs, and usage snippets.
5. **Fixes file paths** - Replaces absolute git root directory paths with relative paths (`.`) in the generated Markdown for portability.
6. **Cleans up** - Removes the temporary ARM JSON template file after documentation generation.
