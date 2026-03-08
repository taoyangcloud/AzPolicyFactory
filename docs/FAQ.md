# AzPolicyFactory — Frequently Asked Questions (FAQ)

## Table of Contents

- [AzPolicyFactory — Frequently Asked Questions (FAQ)](#azpolicyfactory--frequently-asked-questions-faq)
  - [Table of Contents](#table-of-contents)
  - [Pipeline Configurations](#pipeline-configurations)
    - [How do I exclude certain Pester tests from being executed in the Azure DevOps pipelines or GitHub Actions?](#how-do-i-exclude-certain-pester-tests-from-being-executed-in-the-azure-devops-pipelines-or-github-actions)
    - [Why do the policy assignment and exemption Bicep templates use custom definition files instead of Bicep parameter files?](#why-do-the-policy-assignment-and-exemption-bicep-templates-use-custom-definition-files-instead-of-bicep-parameter-files)
    - [I'm using self-hosted runners / agents for the pipelines / workflows. What software and tools do I need to install on the runners / agents?](#im-using-self-hosted-runners--agents-for-the-pipelines--workflows-what-software-and-tools-do-i-need-to-install-on-the-runners--agents)
  - [Azure DevOps Pipelines](#azure-devops-pipelines)
    - [How do I configure the ADO pipelines to use self-hosted agents instead of Microsoft-hosted agents?](#how-do-i-configure-the-ado-pipelines-to-use-self-hosted-agents-instead-of-microsoft-hosted-agents)
    - [Do these pipelines support Azure DevOps servers?](#do-these-pipelines-support-azure-devops-servers)
  - [GitHub Actions](#github-actions)
    - [How do I configure the GitHub Actions workflows to use self-hosted runners instead of GitHub-hosted runners?](#how-do-i-configure-the-github-actions-workflows-to-use-self-hosted-runners-instead-of-github-hosted-runners)
  - [Policy Resources](#policy-resources)
    - [How does the Policy Assignments pipeline / workflow populate the non-compliance messages for each policy assignment?](#how-does-the-policy-assignments-pipeline--workflow-populate-the-non-compliance-messages-for-each-policy-assignment)

## Pipeline Configurations

### How do I exclude certain Pester tests from being executed in the Azure DevOps pipelines or GitHub Actions?

<details>
<summary>Click to expand</summary>
You can exclude specific Pester tests by excluding the test tags associated with those tests in the pipeline YAML files.

For the 3 sets of tests included from the `AzPolicyTest` module, use the following commands to get the list of available tags for each test:

1. Firstly, install the `AzPolicyTest` module from the PowerShell Gallery if you haven't already:

```powershell
Install-Module -Name AzPolicyTest -Scope CurrentUser
```

2. To get the list of tags for each test, you can run the following command:

```powershell
#Policy Definition tests
$results = Test-AzPolicyDefinition -Path <path_to_policy_definitions_folder>

#policy Initiative tests
$results = Test-AzPolicyInitiative -Path <path_to_policy_initiatives_folder>

#List the test names and tags
$result.tests | format-table Name, Tag -AutoSize
```

For other Pester tests that are included in the repository, you can check the test files to identify the tags associated with each test.

Once you have identified the tags for the tests you want to exclude, you can update the pipeline YAML files to exclude those tags from being executed in the pipelines.

The pipeline / workflow parameters for excluded tags for each test type are as follows:

- Policy Definition tests
  - ADO Pipelines
    - Pipeline Names: `Policy-Definition` & `Policy-Initiative`
    - Pipeline Stages: `Policy Definition Tests`
    - Parameter Name: `definitionTestExcludeTags`
  - GitHub Action Workflows
    - Workflow Names: `policy-definitions` & `policy-initiatives`
    - Workflow Jobs: `Policy Definition Tests`
    - Parameter Name: `definition-test-exclude-tags`
- Policy Assignment and Exemption Configuration File Syntax tests
  - ADO Pipelines
    - Pipeline Names: `Policy-Assignment` & `Policy-Exemption`
    - Pipeline Stages: `Test Dev` & `Test Prod`
    - Pipeline Template: `template-job-policy-assignment-exemption-config-syntax-validate.yml`
    - Parameter Name: `excludeTags`
  - GitHub Action Workflows
    - Workflow Names: `policy-assignments` & `policy-exemptions`
    - Workflow Jobs: `Test Dev` & `Test Prod`
    - Custom Action: `validate-policy-assignment-and-exemption-config-syntax`
    - Parameter Name: `exclude-tags`

At the moment, the following Pester tests used in this project do not support excluding tags:

- Bicep Support File tests
- PSRule tests
- Policy Assignment Environment Consistency tests

</details>

### Why do the policy assignment and exemption Bicep templates use custom definition files instead of Bicep parameter files?

<details>
<summary>Click to expand</summary>
A fundamental design decision we have made is that each policy resource should be self-contained in separate files.

Initially, we implemented the policy assignment and exemption Bicep templates using parameter files for each policy assignment and exemption. To increase deployment velocity, we had to leverage matrix jobs in the pipelines / workflows to deploy each assignment and exemption in parallel.

This approach has some significant drawbacks:

- The maximum concurrent jobs are determined by how many concurrent agent jobs are purchased in your Azure DevOps environment (or how many available self-hosted pipeline agents you have). It can become very expensive to increase the concurrent job limit in Azure DevOps.
- The Policy Assignments and Exemptions ADO pipelines can potentially consume all available agents in your Azure DevOps environment, which can impact other pipelines running at the same time.
- Lengthy deployment times when there are a large number of policy assignments and exemptions to be deployed, even with parallel jobs.

To overcome these challenges, we have designed the policy assignment and exemption Bicep templates to use custom definition files (in JSON format) for each policy assignment and exemption instead of using parameter files.

By using this approach, we can deploy all policy assignments and exemptions in a single job (single Bicep deployment) while still maintaining the self-contained design for each policy resource.

The Bicep templates are designed to create the policy assignments and exemptions concurrently (with up to 15 concurrent resource deployment defined in Bicep), which can significantly reduce the deployment time without the need to increase the concurrent job limit in Azure DevOps.

In summary, using custom definition files for each policy assignment and exemption allows us to achieve faster deployment times and reduce the cost of running the pipelines while still maintaining a clean and organized structure for our policy resources.

</details>

### I'm using self-hosted runners / agents for the pipelines / workflows. What software and tools do I need to install on the runners / agents?

<details>
<summary>Click to expand</summary>

The following software and tools need to be installed on the self-hosted runners / agents to run the pipelines / workflows successfully:

- PowerShell 7.2 or later
- Azure PowerShell Az module (latest version)
- Bicep CLI (latest version)
- Pester PowerShell module (latest version)
- AzPolicyTest PowerShell module (latest version)
- PSRule PowerShell module (latest version)
- PSRule.Rules.Azure PowerShell module (latest version)
- PowerShell-Yaml PowerShell module (latest version, GitHub action runners only)
</details>

## Azure DevOps Pipelines

### How do I configure the ADO pipelines to use self-hosted agents instead of Microsoft-hosted agents?

<details>
<summary>Click to expand</summary>
All the ADO pipeline templates are designed to work with both Microsoft-hosted agents and self-hosted agents. If you want to use self-hosted agents, you will need to search for the `vmImage` parameters in each pipeline YAML file and replace them with `poolName`, and make sure the value for the `poolName` parameter matches the name of your self-hosted agent pool.
</details>

### Do these pipelines support Azure DevOps servers?

<details>
<summary>Click to expand</summary>
Short answer: Yes. You can run all the ADO pipelines in Azure DevOps Server (on-premises) environment.

However, you will need to make some adjustments to the pipeline YAML files to use self-hosted agents instead.
</details>

## GitHub Actions

### How do I configure the GitHub Actions workflows to use self-hosted runners instead of GitHub-hosted runners?

<details>
<summary>Click to expand</summary>
In each workflow YAML file, you will need to update the `runs-on` property to specify the name of your self-hosted runner. Details of this configuration can be found in the [GitHub documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idruns-on).
</details>

## Policy Resources

### How does the Policy Assignments pipeline / workflow populate the non-compliance messages for each policy assignment?

<details>
<summary>Click to expand</summary>
The non-compliance messages for each policy assignment are defined in the `nonComplianceMessages` property in the policy assignment configuration files. The Policy Assignments pipeline / workflow uses a [PowerShell script](../scripts/pipelines/pipeline-set-policy-non-compliance-messages.ps1) to populate the non-compliance messages for each policy assignment during the build stage / job.

The script does the following:

1. Sets the default message to `You have not met all standards set by '<name of assigned policy or initiative>'. Refer to the policy for requirements.`
2. If a policy initiative is assigned, the script will iterate through all the policies included in the initiative and add a non-compliance message for each policy in the initiative with the format `PolicyID: <policy reference id> Violation in <policy initiative name> Initiative - '<member policy display name>'`
</details>
