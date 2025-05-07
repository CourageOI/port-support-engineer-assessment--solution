# Port Support Engineer Assignment Solutions

## Exercise #1: JQ Patterns for Data Extraction
This exercise focuses on using JQ patterns to extract specific information from API responses.

### Kubernetes Deployment Object

Given a Kubernetes deployment object snippet, here are the JQ patterns to extract the required information:

1. **Current replica count:**
```
.spec.replicas
```
Explanation: This pattern directly accesses the `replicas` field within the `spec` object of the deployment, which indicates the configured number of replicas.

2. **Deployment strategy:**
```
.spec.strategy.type
```
Explanation: This pattern navigates to the `strategy` object and extracts the `type` field, which defines the deployment strategy (e.g., "RollingUpdate" or "Recreate").

3. **Service label concatenated with environment label with a hyphen in the middle:**
```
.metadata.labels.service + "-" + .metadata.labels.environment
```
Explanation: This pattern first accesses the `service` label under `.metadata.labels`, concatenates a hyphen, and then adds the `environment` label from the same path.

#### Example Implementation

**Using a JQ Script File:**
1. Save your K8s deployment JSON to `k8s-deploy.json`
2. Create a file `k8s-deploy-result.jq` with:
```json
{
  "replica_count": .spec.replicas,
  "deployment_strategy": .spec.strategy.type,
  "service_environment": (.metadata.labels.service + "-" + .metadata.labels.environment)
}
```
3. Run: `jq -f k8s-deploy-result.jq k8s-deploy.json`

**Direct Command Line:**
You can also run it directly on the command line to get specific results:
```bash
# Get replica count
jq '.spec.replicas' k8s-deploy.json

# Get deployment strategy
jq '.spec.strategy.type' k8s-deploy.json

# Get service-environment
jq '.metadata.labels.service + "-" + .metadata.labels.environment' k8s-deploy.json
```

I created a jq file 

### Jira API Issue Response

To extract all issue IDs for subtasks in the issue-response.json file and use it to form an array :
```
[.fields.subtasks[].key]
```
Explanation: This pattern accesses the `subtasks` array within the `fields` object, iterates through each subtask (represented by `[]`), and extracts the `key` field from each, which contains the issue ID and put converts the result into an array. 
Run: `jq '[.fields.subtasks[].key]' issue-response.json`

## Exercise #2: Jira and GitHub Integration

This exercise demonstrates integrating Jira with GitHub via Port's platform to create relations between Jira issues and GitHub repositories.

### Implementation Steps

1. **Create a Port organization**
   - Signed up at https://app.getport.io
   - Completed the initial setup wizard

2. **Install Port's GitHub app**
   - Navigated to Data Source tab in the Builds page in Port
   - Clicked on Add Data Source
   - Selected GitHub and clicked on install Github apps
   - Authorized the app on my GitHub account
   - Selected repositories to include in Port

3. **Create a Jira account**
   - Created a free Jira Software Cloud account https://ioctec.atlassian.net/
   - Created a new project using:
     - Software development category
     - Scrum template
     - Company managed project type to access components feature

4. **Create Jira components matching GitHub repositories**
   - Created components named exactly the same as my GitHub repositories
   - Created at least two components for two repositories:
     - `tpss-api`
     - `trivia-api`

5. **Install Port's Ocean integration for Jira**
   - From the [Ocean’s Jira integration](https://docs.port.io/build-your-software-catalog/sync-data-to-catalog/project-management/jira/) link
   - Selectecd Real-time (self-hosted) setup option
   - Also setup a Kind cluster and deployed the ocean Jira integration via helm
   - Used Kubernetes deployment approach via Helm chart
   - Created a user token from Jira
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
  - After successful deployment, I was able to see the various Jira integrations on Port UI

6. **Update Port's data model**
   - Added relation from "Jira Issue" to "Repository"
   - Configured the relation in the Builder:
     - Went to the "Builder" page
     - Selected "Jira Issue" blueprint
     - Added a new relation property:
       - Type: `array`
       - Name: `related_repositories`
       - Title: `Related Repositories`
       - Format: `relation`
       - Target: `Repository`

7. **Update Jira integration mapping**
   - Updated the mapping configuration to relate Jira issues to GitHub repositories based on components
   - Created/modified the integration mapping file:

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
   - Added a new property of type "Aggregation" to the Repository blueprint:
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
 The above using the query agregates all Pull requests whose status is open as indicated in the query rules

3. **Create a scorecard on the Repository blueprint**
   - Added a new scorecard to visualize the PR status:
     - Name: `open-prs-status`
     - Title: `Open PRs Status`
     - Description: `Tracks repository health based on number of open PRs`
     - Rules:
       - Gold: `pull_request_count < 5`
       - Silver: `pull_request_count >= 5 && pull_request_count < 10`
       - Bronze: `pull_request_count >= 10 && pull_request_count < 15`

4. **Configure the scorecard in Port UI**
   - Navigated to the Builder page in Port
   - Selected the Repository blueprint
   - Added a new scorecard
   - Configured the rules with the following JSON:

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