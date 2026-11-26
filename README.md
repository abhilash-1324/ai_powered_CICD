# Todo List app with AKS build pipeline

This repository contains a Java 21 / Spring Boot Todo List app, a Docker image build, an AKS-ready Helm chart, and the existing GitHub Actions SRE analysis demo. The Todo app has no login or authentication. Its in-memory data is cleared whenever the app restarts, including when AKS replaces its pod.

## Run locally

Prerequisites: Java 21 and Maven 3.9+.

```powershell
mvn -f todo-app/pom.xml spring-boot:run
```

Open <http://localhost:8080>. The REST API is available at `/api/todos`:

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/todos` | List todos |
| GET | `/api/todos/{id}` | Get one todo |
| POST | `/api/todos` | Create a todo |
| PUT | `/api/todos/{id}` | Update title/completion |
| DELETE | `/api/todos/{id}` | Delete a todo |

Create/update JSON requires a non-blank title of at most 200 characters, for example:

```json
{"title":"Try the Todo app","completed":false}
```

Run the Java tests with `mvn -f todo-app/pom.xml test`. The repository's existing Node SDK tests run with `npm ci` followed by `npm test`.

## GitHub Actions

Push to `main`, open a pull request, or run **Actions -> SRE Autopilot Copilot SDK MVP** manually. The workflow tests the Java app and existing SDK, builds the Docker image, and lints/renders the Helm chart. It does not publish an image or deploy to a cluster.

### SonarQube Java static analysis

Every workflow run compiles the Java application and runs SonarScanner CLI against a temporary SonarQube Community Build container on the runner. No SonarQube account, server, repository variable, or repository secret is required. The job starts the server bound to localhost, changes its initial administrator password, and generates a temporary analysis token; the container and its credentials are discarded at the end of the run. The job needs Docker and internet access to download the container images and Java dependencies. On the GitHub-hosted Linux runner it raises `vm.max_map_count` if necessary for SonarQube's embedded Elasticsearch.

The scanner analyzes the Java application and tests using the compiled classes and dependencies. A failed scan or failed SonarQube quality gate fails the job. Download the `sonarqube-report-RUN_ID-ATTEMPT` artifact for issue details and the quality gate result. Reports can contain source paths and issue messages, so treat them as repository-sensitive. Only a short scan summary is passed to the existing SRE analysis job.

The server is fresh on each run: results and quality profiles aren't retained between runs, and the default quality gate has no historical baseline. This is static analysis, not monitoring of the running Java application.

The workflow also keeps the existing Copilot SDK SRE analysis job. It needs GitHub Actions Copilot request access; if Copilot isn't available, the analyzer publishes its deterministic fallback report.

## Build and deploy to AKS

The root `Dockerfile` builds the Spring Boot application into a non-root Java 21 container. The chart at `helm/todo-app` defaults to an internal `ClusterIP` service and includes health probes and resource requests/limits.

Build and push the image to an Azure Container Registry (ACR):

```powershell
az acr build --registry <ACR_NAME> --image todo-app:<TAG> .
```

If the AKS cluster does not already have pull permission for the registry, grant it:

```powershell
az aks update --resource-group <AKS_RESOURCE_GROUP> --name <AKS_CLUSTER> --attach-acr <ACR_NAME>
az aks get-credentials --resource-group <AKS_RESOURCE_GROUP> --name <AKS_CLUSTER>
```

Install or update the app, substituting your ACR login server (for example `myregistry.azurecr.io`) and image tag:

```powershell
helm upgrade --install todo-app helm/todo-app `
  --namespace todo-app --create-namespace `
  --set image.repository=<ACR_LOGIN_SERVER>/todo-app `
  --set image.tag=<TAG>

kubectl port-forward --namespace todo-app service/todo-app 8080:80
```

Open <http://localhost:8080>. Port-forwarding keeps this unauthenticated demo private. If you choose a public `LoadBalancer` service instead, configure network restrictions before exposing it; anyone who can reach the app can view and change its todos.

## Existing SRE analyzer

The workflow gathers bounded test/build evidence and runs the existing read-only Copilot SDK analyzer. It does not apply fixes or deploy workloads. Its analysis can fall back deterministically when Copilot Actions access is unavailable.
