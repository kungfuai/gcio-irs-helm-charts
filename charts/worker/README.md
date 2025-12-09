# Facture Worker

Create a minimal `values.yaml` file:

```yaml
aws:
  s3Bucket: my-bucket
secrets:
  databaseURL:
    value: postgres://localhost:5432/facture
```

Update the helm repo and install the worker:

```sh
$ helm repo update facture
$ helm install [release-name] facture/worker --values values.yaml
```
