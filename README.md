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

### Optional SonarQube scan

The Java scan runs when both of these are configured in the GitHub repository:

- Repository variable `SONAR_HOST_URL`: URL reachable from the GitHub Actions runner for your SonarQube server.
- Repository secret `SONAR_TOKEN`: token with permission to analyze the project.

Optionally set repository variable `SONAR_PROJECT_KEY`; otherwise the workflow derives a key from the repository name. If the URL or token is missing, the scan is skipped with a note in the workflow summary. If configured but unreachable or invalid, the scan fails visibly. For a private/self-hosted SonarQube runtime, the hosted runner must have network access to that instance.

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
