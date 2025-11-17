# Facture Helm Charts

Helm charts for the Kubernetes deployment of Facture services for the KFAI component of the GCIO/IRS document extraction project.

## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

```
$ helm repo add kfai-facture [COMING SOON!]
```

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
kfai-facture` to see the charts.

## Available Charts

- [Lander](charts/lander/README.md)
- [Worker](charts/worker/README.md)
- [Extractor](charts/extractor/README.md)

## Debugging Templates

- Use `helm lint` to ensure your chart follows best practices.
- Use `helm template --debug` to render chart templates locally
- Use `helm install --dry-run --debug` to render chart locally without installing certs in the cluster, setting `--dry-run=server` will also perform any lookups on the server.

## PGP Keys

PGP keys are used to sign helm charts with the chart releaser action. These keys are stored in GitHub secrets and the public keys can also be used to verify the helm charts have not been tampered with.

To create a PGP key pair for chart signing, follow these steps:

1. Generate a PGP Key Pair using the `gpg` command. Note that the email address `daas-support@kungfu.ai` was used to identify the RSA and RSA (default) key with keysize 3072 and an expiration of 3 years. The name and comment are optional.

    ```sh
    $ gpg --full-generate-key
    ```

    NOTE: you will be prompted to enter a secret passphrase. Make sure you use a secure passphrase and save it somewhere safe. This passphrase should be added to GitHub secrets as the `$GPG_PASSPHRASE` variable.

2. Export your PGP Secret Key

    ```sh
    $ gpg --output .secret/secring.gpg --export-secret-keys [KEYID]
    ```

    NOTE: you can get your key id with `gpg --list-secret-keys`; it may look something like:

    ```sh
    gpg --output .secret/secring.gpg --export-secret-keys A3263DC3B730792048BB51FD8D918BB4C948960E
    ```

3. Encode your PGP Secret Key

    ```sh
    $ base64 -i .secret/secring.gpg > .secret/secring.gpg.base64
    ```

    Make sure that the contents of the `.base64` file are stored in GitHub secrets as the `$GPG_KEYRING_BASE64` variable.

For more information, see: [How to sign Helm Charts using Chart Releaser Action](https://colinwilson.uk/2022/01/27/how-to-sign-helm-charts-using-chart-releaser-action/)