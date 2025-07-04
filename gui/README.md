# CODECO ACM GUI

Web-based interface for the CODECO ACM (Adaptive Configuration Manager) operator.

## Overview

This GUI provides a user-friendly interface for managing CodecoApp resources and monitoring the ACM operator. It consists of:

- **Frontend**: React application with PatternFly UI components
- **Backend**: Node.js API server with Kubernetes integration

## Features

### ✅ Implemented
- **YAML Generator**: Create CodecoApp custom resources with guided forms
- **YAML Upload**: Deploy YAML configurations directly to Kubernetes
- **Resource Monitoring**: View pods, namespaces, and custom resources
- **CRD Management**: List and inspect custom resource definitions
- **Error Handling**: Comprehensive error boundaries and logging
- **Health Checks**: Built-in health monitoring endpoints

## Quick Start

### Prerequisites
- ACM operator deployed and running
- Node.js 18+ (for development)
- Docker (for containerized deployment)
- kubectl access to the cluster

### Development Mode

1. **Start the Backend**:
   ```bash
   cd gui/backend
   npm install
   npm start
   ```

2. **Start the Frontend**:
   ```bash
   cd gui/frontend
   npm install
   npm start
   ```

3. **Access the GUI**: http://localhost:3000

### Cluster Deployment

Deploy alongside the ACM operator:

```bash
# From the ACM root directory
kubectl apply -f gui/backend/deployment/
kubectl apply -f gui/frontend/deployment/
```

## Configuration

### Environment Variables

#### Backend (`gui/backend`)
- `NODE_ENV`: Environment (development/production)
- `PORT`: Server port (default: 5000)
- `ALLOWED_ORIGINS`: Comma-separated list of allowed frontend origins

#### Frontend (`gui/frontend`)
- `REACT_APP_API_URL`: Backend API URL
- `NODE_ENV`: Environment (development/production)

### Kubernetes Integration

The GUI backend automatically connects to Kubernetes using:
- In-cluster service account (when deployed in Kubernetes)
- Local kubeconfig (when running in development)

## API Endpoints

### Backend API
- `GET /health` - Health check endpoint
- `POST /apply-yaml` - Deploy YAML to Kubernetes
- `GET /get-status` - Get resource status
- `GET /api/namespaces` - List namespaces
- `GET /api/pods` - List pods
- `GET /crds` - List custom resource definitions
- `GET /crds/microservices` - List CodecoApp resources

### Frontend Routes
- `/` - Landing page and YAML generator
- `/yaml` - YAML generator form
- `/upload` - YAML upload interface
- `/docs` - Documentation

## Integration with ACM Operator

### Namespace Configuration
The GUI automatically uses the ACM operator's namespace configuration:
- Default namespace: `he-codeco-acm`
- Respects ACM operator's RBAC policies
- Uses the same service account permissions

### CodecoApp CRD Integration
- Full support for CodecoApp custom resources
- Schema-aware YAML generation
- Real-time status monitoring
- Integration with ACM controller reconciliation

### Monitoring Integration
The GUI integrates with ACM's monitoring stack:
- Prometheus metrics collection
- Grafana dashboard compatibility
- Health check integration with ACM operator

### Testing

```bash
# Backend tests
cd gui/backend
npm test

# Frontend tests
cd gui/frontend
npm test
```


## Security

### Implemented Security Measures
- **Container Security**: Non-root user, read-only filesystem
- **Network Security**: CORS restrictions, rate limiting
- **Input Validation**: All user inputs validated
- **RBAC Integration**: Uses ACM operator's service account
- **Security Headers**: Comprehensive HTTP security headers

### Debugging

# Check GUI backend logs
kubectl logs -l app=codeco-gui-backend

# Check GUI frontend logs
kubectl logs -l app=codeco-gui-frontend
