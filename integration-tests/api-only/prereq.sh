#!/bin/bash
set -e
set -o pipefail

echo "Deploying standalone MongoDB..."
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: standalone-mongo
  labels:
    app: standalone-mongo
spec:
  containers:
    - name: mongo
      image: mongo:5.0
      ports:
        - containerPort: 27017
      env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: "hyperdx"
        - name: MONGO_INITDB_ROOT_PASSWORD
          value: "testpass"
---
apiVersion: v1
kind: Service
metadata:
  name: standalone-mongo
spec:
  selector:
    app: standalone-mongo
  ports:
    - port: 27017
      targetPort: 27017
EOF

echo "Waiting for standalone MongoDB to be ready..."
kubectl wait --for=condition=Ready pod/standalone-mongo --timeout=120s
echo "Standalone MongoDB is ready."
