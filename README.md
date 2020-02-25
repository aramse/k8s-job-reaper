# k8s-job-reaper
A simple tool to clean up old Job resources in Kubernetes

## Motivation
As it currently stands in `alpha`, the [TTL feature gate](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/#clean-up-finished-jobs-automatically), which offers the ability to automatically clean up Job resources in Kubernetes based on a configured TTL, is weakly supported in managed Kubernetes offerings. For example, it's [not supported](https://github.com/aws/containers-roadmap/issues/255) at all in EKS. As a result, Job resources can quickly pile up and waste cluster resources.

This tool aims to deliver the same functionality via a script that looks for an annotation on Job resources called `ttl`.

> Note that setting `restartPolicy: OnFailure` is another possible solution for cleanup, but it deletes the underlying pod (including its logs) immediately after Job completion, as documented [here](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/#pod-backoff-failure-policy). Therefore it is not considered a viable approach for many use cases.


## Example
```YAML
apiVersion: batch/v1
kind: Job
metadata:
  generateName: example-job-ttl-
  annotations:
    ttl: "2 hours"
spec:
  template:
    spec:
      containers:
      - name: example
        image: centos
        command: ["sleep", "90"]
      restartPolicy: Never
  backoffLimit: 0
  ```
The `ttl` annotation can be specified with any value supported by [GNU relative dates](https://www.gnu.org/software/coreutils/manual/html_node/Relative-items-in-date-strings.html#Relative-items-in-date-strings).

> Note that this example Job is deployed with `kubectl create` rather than `kubectl apply` due to its usage of `generateName`.

## Deployment
### Prerequisites
- `docker`
- `kubectl`

Deploying this tool is as simple as running:
```sh
./build.sh [IMAGE_URL]
```
where `[IMAGE_URL]` is the full URL of the container image you want to build/push/deploy. For example, if your container registry is hosted on `gcr.io/acme-123`, you may run:
```sh
./build.sh gcr.io/acme-123/k8s-job-reaper
```

## Configuration
This tool also supports the following configurations.
| Field        | Location    | Description  | Default 
| ------------- |---------| -------|-----
| `DEFAULT_TTL`  | Environment variable in [cronjob.yaml](k8s/cronjob.yaml) |  An optional global default TTL for all Jobs | `""`
| `NS_BLACKLIST` | Environment variable in [cronjob.yaml](k8s/cronjob.yaml) |   A list of Kubernetes Namespaces (**space-delimited**) to ignore when looking for Jobs | `"kube-system"`
| `schedule` | Field in [cronjob.yaml](k8s/cronjob.yaml) | The cron schedule at which to look for Jobs to delete | `"0 */1 * * *"` (once an hour)

