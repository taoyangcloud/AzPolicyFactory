# Pre-requisites

Before you can use the ADO pipelines and GitHub Actions workflows provided in AzPolicyFactory, you need to have the following pre-requisites in place.

## Azure DevOps Project or GitHub Repository

You need to have an Azure DevOps project or a GitHub repository where you want to set up the pipelines or workflows.

Once the ADO project or GitHub repository is created, can add the files from this repository to your ADO or GitHub repository. You can either copy the files directly or use Git to clone this repository and push the files to your own repository.

To push the files to your own repository, you can follow these steps:

```bash
git remote add origin <your-repository-url>
git checkout -b feature/initial-ssetup
git add .
git commit -m "Initial commit of pipeline/workflow files"
git push --set-upstream origin feature/initial-ssetup
```

Once the files are in your repository, you can follow the setup guides to configure the pipelines or workflows for your environment.

## Service Principal with Required Permissions

You need to have a service principal with the necessary permissions to deploy Azure Policy resources on the top Enterprise Scale Landing zone (ESLZ) management group for each environment. The service principal should have at least the "Owner" role assigned at the management group level to ensure it has sufficient permissions to deploy policy definitions, initiatives, assignments, and exemptions.

> :memo: Note: The `Owner` role is required because policy assignments that assign `Modify` and `DeployIfNotExists` policies require role assignments to be created for the managed identity of the policy assignment. The `Owner` role ensures that the service principal has the necessary permissions to create these role assignments during policy deployment.

Once the service principal is created, you may use the following PowerShell command to assign the `Owner` role to the service principal at the management group level:

```powershell
New-AzRoleAssignment -ObjectId <Enterprise App Object ID> -Scope '/providers/Microsoft.Management/managementGroups/<MG-Name>' -RoleDefinitionId 8e3af657-a8ff-443c-a75c-2fe8c4bcb635

```

> :memo: Note: If you are using a same Microsoft Entra ID tenant for both development and production environments, make sure you have separate service principals for each environment. It is a security risk for using the same identity for production and non-production environments.
