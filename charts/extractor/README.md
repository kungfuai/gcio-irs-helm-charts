# Facture Extractor

Create a minimal `values.yaml` file:

```yaml
aws:
  s3Bucket: my-bucket
secrets:
  databaseURL:
    value: postgres://localhost:5432/facture
```

Update the helm repo and install the extractor:

```sh
$ helm repo update facture
$ helm install [release-name] facture/extractor --values values.yaml
```
