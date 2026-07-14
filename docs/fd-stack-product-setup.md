# FD Stack product setup

Create the application in the FD Stack admin UI with these stable identifiers:

- App code: `fd_edu_system`
- Type: `web_app`
- Delivery mode: `one_click`
- Manifest repository: `https://github.com/FutureDecade/fd-edu-system-delivery`
- Manifest branch: `main`
- Manifest path: `fd-delivery.manifest.json`

Create the base Web plan with the commercial price and billing interval selected
for launch. Its `deploymentPolicy` must be:

```json
{
  "maxActiveDeployments": 1,
  "domainBindingMode": "lock_on_first_success",
  "domainBindingSource": "primaryDomain",
  "domainBindingScope": "exact_host",
  "allowMultiplePurchases": false
}
```

After syncing the manifest, configure these app-level delivery presets:

- `FD_EDU_RUNTIME_IMAGE`: immutable ACR image tag or digest
- `ACR_USERNAME`: shared pull-only delivery account
- `ACR_PASSWORD`: encrypted preset secret
- `FD_RUNTIME_IMAGE_UPDATE_POLICY`: `manual` for the initial release

The base plan should expose the Web product features only. A WeChat Mini Program
offer remains a separately fulfilled add-on and must not create another server
deployment entitlement.
