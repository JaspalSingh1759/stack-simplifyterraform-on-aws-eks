data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks_cluster.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

resource "helm_release" "csi_driver_aws" {
  name       = "secrets-store-csi-driver-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
    set {
      name  = "syncSecret.enabled"
      value = "true"
  }
  depends_on = [aws_eks_node_group.eks_ng_private]
}

/*
What happens: Configures Kubernetes and Helm providers using the 
live EKS cluster, then deploys the CSI driver via Helm.

"Why does the Helm provider need cluster_ca_certificate = base64decode(...)?"

"The CA certificate validates that you're talking to the real EKS API server and not a MITM. It's stored base64-encoded in the EKS cluster resource, so base64decode() converts it to PEM format that the TLS library expects. Without it, the Helm provider would either reject the self-signed cert or be vulnerable to interception."

"What does depends_on = [aws_eks_node_group.eks_ng_private] do for the Helm release?"

"The CSI driver runs as a DaemonSet — it needs nodes to schedule on. If you deploy it before nodes exist, the pods stay Pending indefinitely. The depends_on ensures nodes are fully registered before Helm deploys the chart. Without it, Terraform might consider the Helm release 'done' even though the pods never became Ready."

"What does syncSecret.enabled = true enable?"

"By default the CSI driver mounts secrets as files in a volume. With syncSecret enabled, it also creates a Kubernetes Secret object from the mounted secret. This means your app can reference the RDS credentials as environment variables via envFrom: secretRef instead of reading files from a mounted volume — which is what most Node.js apps expect."
*/

/*
Great question — this is a concept that trips up a lot of people. Let me break it down from first principles.

---

## What the CSI driver does by default (without syncSecret)

The Secrets Store CSI driver mounts secrets as **files inside a volume** on the pod. Think of it like a USB drive being plugged into your pod.

```yaml
# Your pod spec would look like this
volumeMounts:
  - name: secrets-vol
    mountPath: "/mnt/secrets"   # ← secret appears as a FILE here
    readOnly: true

volumes:
  - name: secrets-vol
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "nodejs-aws-secrets"
```

Inside the pod, your app would read the secret like reading a file:
```javascript
// Node.js app would have to do this
const fs = require('fs');
const secret = JSON.parse(fs.readFileSync('/mnt/secrets/nodejs-rds-secret', 'utf8'));
const dbHost = secret.DB_HOST;
```

**The problem** — most apps, especially Node.js apps, are not written this way. They expect environment variables:

```javascript
// This is how 99% of Node.js apps actually read config
const dbHost = process.env.DB_HOST;
const dbPass = process.env.DB_PASSWORD;
```

---

## What `syncSecret.enabled = true` adds

When you enable this, the CSI driver does a **second step** after mounting the file — it automatically creates a native **Kubernetes Secret object** from the same AWS secret value.

```
AWS Secrets Manager
        │
        │  CSI driver fetches
        ▼
  File mounted in pod          ← always happens (default behaviour)
  /mnt/secrets/nodejs-rds-secret

        +

  Kubernetes Secret created    ← only happens when syncSecret = true
  kind: Secret
  name: nodejs-rds-secret
  namespace: default
  data:
    DB_HOST: <base64>
    DB_PORT: <base64>
    DB_NAME: <base64>
    DB_USERNAME: <base64>
    DB_PASSWORD: <base64>
```

Now your pod spec can use that Kubernetes Secret as environment variables the normal way:

```yaml
envFrom:
  - secretRef:
      name: nodejs-rds-secret   # ← the K8s Secret the CSI driver created
```

Or individual vars:
```yaml
env:
  - name: DB_HOST
    valueFrom:
      secretKeyRef:
        name: nodejs-rds-secret
        key: DB_HOST
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: nodejs-rds-secret
        key: DB_PASSWORD
```

Your Node.js app now reads `process.env.DB_HOST` and `process.env.DB_PASSWORD` — **zero code changes needed**.

---

## The critical catch — and why it matters in interviews

Without `syncSecret`, there is a **hard requirement**: the pod must have the CSI volume mount defined, otherwise AWS secret is never fetched at all. The secret only exists as long as the pod is running with the volume mounted.

With `syncSecret = true`, the Kubernetes Secret object is created and **lives independently** in the cluster. Other pods that don't even have the CSI volume mount can reference it via `secretKeyRef`.

```
Without syncSecret:
Pod A (has volume mount) → gets secret ✓
Pod B (no volume mount) → gets nothing ✗

With syncSecret = true:
Pod A (has volume mount) → gets secret ✓  (also triggers K8s Secret creation)
Pod B (no volume mount) → references K8s Secret via env var ✓
```

---

## Interview Q&A

**"If `syncSecret` creates a Kubernetes Secret, doesn't that defeat the purpose of using AWS Secrets Manager? K8s Secrets are just base64 encoded."**

> "That's the most common challenge on this topic. You're right that base64 is not encryption — a plain Kubernetes Secret is readable by anyone with the right RBAC. But the security model is layered. The AWS secret is the source of truth — if you rotate it in Secrets Manager, the CSI driver syncs the updated value to the K8s Secret automatically. The K8s Secret is just a projection for app convenience. You protect it using K8s RBAC to restrict which service accounts can read it, and in production you'd also enable envelope encryption on the EKS cluster using KMS, which encrypts etcd at rest — including Secrets. So the flow is: AWS Secrets Manager (encrypted, audited, rotatable) → CSI driver (IRSA authenticated fetch) → K8s Secret (RBAC protected, KMS encrypted at rest) → pod env var."

**"What happens to the Kubernetes Secret if you delete the SecretProviderClass or the pod?"**

> "The synced Kubernetes Secret is only created when at least one pod with the CSI volume mount is running. If all pods using that volume are deleted, the CSI driver deletes the synced Kubernetes Secret too. This is by design — the K8s Secret lifecycle is tied to the pod that triggered the mount. In practice this means if your deployment scales to zero, the K8s Secret disappears, and when it scales back up the CSI driver recreates it from Secrets Manager."

**"Why not just use the Kubernetes External Secrets Operator instead?"**

> "External Secrets Operator (ESO) is actually the more popular choice in production because it creates and manages the Kubernetes Secret independently of any pod lifecycle — the secret exists as long as the ExternalSecret CRD exists, regardless of pod count. The CSI driver approach is tighter on security because the secret fetch is tied to the pod's service account token at mount time. ESO requires its own operator service account with AWS permissions. The choice comes down to: CSI driver for strict pod-level secret access control, ESO for simpler management and pod-lifecycle-independent secrets."

**"How does secret rotation work with syncSecret?"**

> "The CSI driver polls AWS Secrets Manager on a configurable rotation interval (default 2 minutes via `rotationPollInterval`). When it detects the secret value has changed in Secrets Manager, it updates the mounted file AND updates the synced Kubernetes Secret. However — and this is the gotcha — the pod's environment variables are set at startup from the K8s Secret value. Updating the K8s Secret doesn't update already-running pod env vars. The pod needs to restart to pick up the new value. That's why you'd pair this with something like Reloader (a controller that watches Secrets/ConfigMaps and triggers rolling restarts when they change)."

---

## One line mental model to remember

> `syncSecret.enabled = true` = **"also create a normal Kubernetes Secret so my app can use env vars instead of reading files"** — it's a convenience bridge between the AWS-native secret and the Kubernetes-native way apps consume config.

*/