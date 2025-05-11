# DevOps Integration Exercises Guide

## Exercise #1: JQ Patterns for Quick Data Extraction

### Kubernetes Deployment Patterns
Extract the specified information from the provided Kubernetes deployment objects with these JQ patterns:

```
.spec.replicas                                              # Get replica count
.spec.strategy.type                                         # Get deployment strategy
.metadata.labels.service + "-" + .metadata.labels.environment   # Combine service and environment labels
```

### Implementation Example
Use the bash command as shown below to get each information from the Kubernetes deployment stored in `k8s-deploy.json`
e.g
```bash
jq '.spec.replicas' k8s-deploy.json
```

### Jira Subtask Extraction
Get all subtask IDs from the provided Jira issue? Use this pattern:

```
[.fields.subtasks[].key]
```
Run:
```bash
jq '[.fields.subtasks[].key]' issue-response.json
```
This creates an array of all subtask IDs from the provided Jira Issue response.
---

## Exercise #2: Jira and GitHub Integration

This exercise demonstrates integrating Jira with GitHub via Port's platform to create relations between Jira issues and GitHub repositories.

### Implementation Steps

1. **Create a Port organization**
   - Signed up at https://app.getport.io
   - Completed the initial setup wizard

2. **Install Port's GitHub app**
   - Navigate to the Data Source tab in the Builds page in Port
   - Click on Add Data Source
   - Select GitHub and click on install Github apps
   - Authorize the app on my GitHub account
   - Select repositories to include in Port

3. **Create a Jira account**
   - Create a free Jira Software Cloud account https://ioctec.atlassian.net/
   - Create a new project using:
     - Software development category
     - Scrum template
     - Company managed project type to access the components feature

4. **Create Jira components matching GitHub repositories**
   - Create components named the same as the GitHub repositories
   - Create at least two components for two repositories:
     - `tpss-api`
     - `trivia-api`

5. **Install Port's Ocean integration for Jira**
   - From the [Ocean’s Jira integration](https://docs.port.io/build-your-software-catalog/sync-data-to-catalog/project-management/jira/) link
   - Select Real-time (self-hosted) setup option
   - Also, set up a Kind cluster and deploy the Ocean Jira integration via helm
   - Use Kubernetes deployment approach via Helm chart
   - Create a user token from Jira
   - installation script:
         ```bash
         helm repo add --force-update port-labs https://port-labs.github.io/helm-charts
         helm upgrade --install jira port-labs/port-ocean \
            --set port.clientId="6rtbtxxxxxxxxxxxxx"  \
            --set port.clientSecret="mfxgOAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxKX1"  \
            --set port.baseUrl="https://api.port.io"  \
            --set initializePortResources=true  \
            --set sendRawDataExamples=true  \
            --set scheduledResyncInterval=360  \
            --set integration.identifier="jira"  \
            --set integration.type="jira"  \
            --set integration.eventListener.type="POLLING"  \
            --set integration.config.jiraHost="Enter value here"  \
            --set integration.secrets.atlassianUserEmail="Enter value here"  \
            --set integration.secrets.atlassianUserToken="Enter value here" 
         ```
  - After successful deployment, you should be able to see the various Jira integrations on the Port UI

6. **Update Port's data model**
   - Add relation from "Jira Issue" to "Repository"
   - Configure the relation in the Builder:
     - Go to the "Builder" page
     - Select "Jira Issue" blueprint
     - Add a new relation property:
       - Type: `array`
       - Name: `related_repositories`
       - Title: `Related Repositories`
       - Format: `relation`
       - Target: `Repository`

7. **Update Jira integration mapping**
   - Update the mapping configuration to relate Jira issues to GitHub repositories based on components
   - Create/modify the integration mapping file:

    ```yaml
    - kind: issue
        selector:
          query: 'true'
          jql: (statusCategory != Done) OR (created >= -1w) OR (updated >= -1w)
        port:
          entity:
            mappings:
              identifier: .key
              title: .fields.summary
              blueprint: '"jiraIssue"'
              properties:
                url: (.self | split("/") | .[:3] | join("/")) + "/browse/" + .key
                status: .fields.status.name
                issueType: .fields.issuetype.name
                components: .fields.components
                creator: .fields.creator.emailAddress
                priority: .fields.priority.name
                labels: .fields.labels
                created: .fields.created
                updated: .fields.updated
                resolutionDate: .fields.resolutiondate
              relations:
                project: .fields.project.key
                parentIssue: .fields.parent.key
                subtasks: .fields.subtasks | map(.key)
                related_repository: '[.fields.components[].name] // ""' # I added this mapping
                jira_user_assignee: .fields.assignee.accountId
                jira_user_reporter: .fields.reporter.accountId
                assignee:
                  combinator: '"or"'
                  rules:
                    - property: '"jira_user_id"'
                      operator: '"="'
                      value: .fields.assignee.accountId // ""
                    - property: '"$identifier"'
                      operator: '"="'
                      value: .fields.assignee.email // ""
                reporter:
                  combinator: '"or"'
                  rules:
                    - property: '"jira_user_id"'
                      operator: '"="'
                      value: .fields.reporter.accountId // ""
                    - property: '"$identifier"'
                      operator: '"="'
                      value: .fields.reporter.email // ""
      
    ```

## Exercise #3: PR Scorecard for Repositories

This exercise involves creating a scorecard to track the number of open PRs for repositories with specific thresholds.

### Implementation Steps
1. **Update Port's data model**
   - There is already a relation from "Pull Requests" to "Repository"
2. **Create a property to count open PRs**
   - Add a new property of type "Aggregation" to the Repository blueprint:
     - Name: `pull_request_count`
     - Title: `Pull Request Count`
     - Type: `Aggregation`
     - Related blueprint: `Pull Request`
     - Calculate by: `entities`
     - Function: `count`
     - Query: 
         ```json
           {
            "combinator": "and",
            "rules": [
                {
                "property": "status",
                "operator": "=",
                "value": "open"
                }
            ]
          }
         ```
 The above uses the query to aggregate all Pull requests whose status is open, as indicated in the query rules

3. **Create a scorecard on the Repository blueprint**
   - Add a new scorecard to visualize the PR status:
     - Name: `open-prs-status`
     - Title: `Open PRs Status`
     - Description: `Tracks repository health based on number of open PRs`
     - Rules:
       - Gold: `pull_request_count < 5`
       - Silver: `pull_request_count >= 5 && pull_request_count < 10`
       - Bronze: `pull_request_count >= 10 && pull_request_count < 15`

4. **Configure the scorecard in Port UI**
   - Navigate to the Builder page in Port
   - Select the Repository blueprint
   - Add a new scorecard
   - Configure the rules with the following JSON:

    ```json
    {
      "identifier": "open-prs-status",
      "title": "Open PRs Status",
      "levels": [
        {
          "color": "paleBlue",
          "title": "Basic"
        },
        {
          "color": "bronze",
          "title": "Bronze"
        },
        {
          "color": "silver",
          "title": "Silver"
        },
        {
          "color": "gold",
          "title": "Gold"
        }
      ],
      "rules": [
        {
          "identifier": "gold",
          "title": "Gold",
          "level": "Gold",
          "query": {
            "combinator": "and",
            "conditions": [
              {
                "operator": ">=",
                "property": "pull_request_count",
                "value": 0
              },
              {
                "operator": "<",
                "property": "pull_request_count",
                "value": 5
              }
            ]
          }
        },
        {
          "identifier": "silver",
          "title": "Silver",
          "level": "Silver",
          "query": {
            "combinator": "and",
            "conditions": [
              {
                "operator": ">=",
                "property": "pull_request_count",
                "value": 5
              },
              {
                "operator": "<",
                "property": "pull_request_count",
                "value": 10
              }
            ]
          }
        },
        {
          "identifier": "bronze",
          "title": "Bronze",
          "level": "Bronze",
          "query": {
            "combinator": "and",
            "conditions": [
              {
                "operator": ">=",
                "property": "pull_request_count",
                "value": 10
              },
              {
                "operator": "<",
                "property": "pull_request_count",
                "value": 15
              }
            ]
          }
        }
      ]
    }
    ```

### Result

With this implementation:
- The `pull_request_count` property is automatically updated for each repository
- The scorecard visually indicates the health status of each repository based on open PRs
- Gold, Silver, or Bronze badges are automatically assigned based on the defined thresholds
