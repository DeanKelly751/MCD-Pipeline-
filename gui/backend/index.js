const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const winston = require('winston');
const Joi = require('joi');

// Configure logging
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    transports: [
        new winston.transports.File({ filename: 'error.log', level: 'error' }),
        new winston.transports.File({ filename: 'combined.log' }),
        new winston.transports.Console({
            format: winston.format.simple()
        })
    ]
});

const app = express();

// Security middleware
app.use(helmet());

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.'
});
app.use(limiter);

// CORS configuration - restrict in production
const corsOptions = {
    origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : 'http://localhost:3000',
    credentials: true,
    optionsSuccessStatus: 200
};
app.use(cors(corsOptions));

app.use(express.json({ limit: '10mb' }));

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({ 
        status: 'healthy', 
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// YAML validation schema
const yamlSchema = Joi.object({
    yaml: Joi.string().required().min(1).max(1000000) // 1MB limit
});

async function setupK8sAndStartServer() {
    let k8sApi, k8sApiCR, k8sApiExt, k8s, kc;
    let k8sAvailable = false;

    try {
        k8s = await import('@kubernetes/client-node');
        kc = new k8s.KubeConfig();
        
        // Load just the current context to avoid multi-context issues
        const { exec } = require('child_process');
        const { promisify } = require('util');
        const execAsync = promisify(exec);
        
        try {
            // Get current context and cluster info from kubectl
            const { stdout: contextName } = await execAsync('kubectl config current-context');
            const { stdout: clusterServer } = await execAsync('kubectl config view -o jsonpath="{.clusters[?(@.name==\\"kind-codeco-gui\\")].cluster.server}"');
            
            logger.info('Connecting to Kubernetes', { 
                context: contextName.trim(), 
                server: clusterServer.trim() 
            });
            
            // Create a minimal kubeconfig to avoid parsing issues
            await execAsync('kubectl config view --minify --flatten > /tmp/minimal-kubeconfig.yaml');
            kc.loadFromFile('/tmp/minimal-kubeconfig.yaml');
            
        } catch (cmdError) {
            logger.info('Fallback to standard kubeconfig loading', { error: cmdError.message });
            kc.loadFromDefault();
        }
        
        k8sApi = kc.makeApiClient(k8s.CoreV1Api);
        k8sApiCR = kc.makeApiClient(k8s.CustomObjectsApi);
        k8sApiExt = kc.makeApiClient(k8s.ApiextensionsV1Api);
        
        // Test the connection with a simple call
        try {
            const testResult = await k8sApi.listNamespace();
            if (testResult && testResult.body && testResult.body.items) {
                k8sAvailable = true;
                logger.info('Kubernetes client initialized successfully', { 
                    namespacesFound: testResult.body.items.length,
                    currentContext: kc.getCurrentContext()
                });
            } else {
                throw new Error('Invalid response format from Kubernetes API');
            }
        } catch (testError) {
            logger.warn('Kubernetes API test failed, but proceeding with initialization', { 
                error: testError.message 
            });
            // Try to set k8sAvailable = true anyway and let individual endpoint calls handle errors
            k8sAvailable = true;
            logger.info('Kubernetes client initialized (bypassing test)', { 
                currentContext: kc.getCurrentContext()
            });
        }
    } catch (error) {
        logger.warn('Kubernetes client initialization failed, starting server without K8s functionality', { error: error.message });
        k8sAvailable = false;
    }

    // Helper function to check if K8s is available
    const requireK8s = (res, action) => {
        if (!k8sAvailable) {
            return res.status(503).json({ 
                error: 'Kubernetes cluster not available', 
                message: 'The monitoring features require a connected Kubernetes cluster'
            });
        }
        return false;
    };

    try {
        // Apply YAML endpoint with validation
        app.post('/apply-yaml', async (req, res) => {
            try {
                // Validate request body
                const { error, value } = yamlSchema.validate(req.body);
                if (error) {
                    logger.warn('Invalid YAML request', { error: error.details[0].message });
                    return res.status(400).json({ error: error.details[0].message });
                }

                const { yaml } = value;
                const yamlSpec = k8s.loadYaml(yaml);
                const namespace = yamlSpec.metadata?.namespace || 'he-codeco-acm';

                if (yamlSpec.kind === 'CodecoApp') {
                    logger.info('Applying CodecoApp', { 
                        name: yamlSpec.metadata?.name,
                        namespace 
                    });

                    const response = await k8sApiCR.createNamespacedCustomObject(
                        'codeco.he-codeco.eu',
                        'v1alpha1',
                        namespace,
                        'codecoapps',
                        yamlSpec
                    );

                    logger.info('CodecoApp applied successfully', { 
                        name: yamlSpec.metadata?.name 
                    });

                    return res.status(200).json({
                        message: 'CodecoApp applied successfully',
                        response: response.body
                    });
                } else {
                    logger.warn('Unsupported kind', { kind: yamlSpec.kind });
                    return res.status(400).json({ error: `Unsupported kind: ${yamlSpec.kind}` });
                }
            } catch (err) {
                logger.error('Error applying YAML', { error: err.message, stack: err.stack });
                const errorMessage = err.response?.body?.message || err.message || 'Failed to apply YAML';
                return res.status(500).json({ error: errorMessage });
            }
        });

        // Get status endpoint
        app.get('/get-status', async (req, res) => {
            try {
                const { error, value } = yamlSchema.validate(req.body);
                if (error) {
                    return res.status(400).json({ error: error.details[0].message });
                }

                const { yaml } = value;
                const yamlSpec = k8s.loadYaml(yaml);
                const namespace = yamlSpec.metadata?.namespace || 'he-codeco-acm';

                if (yamlSpec.kind === 'CodecoApp') {
                    const response = await k8sApiCR.getNamespacedCustomObject(
                        'codeco.he-codeco.eu',
                        'v1alpha1',
                        namespace,
                        'codecoapps',
                        yamlSpec.metadata.name
                    );

                    return res.status(200).json({
                        message: 'CodecoApp status fetched successfully',
                        response: response.body
                    });
                } else {
                    return res.status(400).json({ error: `Unsupported kind: ${yamlSpec.kind}` });
                }
            } catch (err) {
                logger.error('Error fetching status', { error: err.message });
                const errorMessage = err.response?.body?.message || err.message || 'Failed to fetch status';
                return res.status(500).json({ error: errorMessage });
            }
        });

        // Namespaces endpoint
        app.get('/api/namespaces', async (req, res) => {
            if (requireK8s(res)) return;
            try {
                const result = await k8sApi.listNamespace();
                logger.info('Namespaces API response', { 
                    hasResult: !!result, 
                    hasBody: !!result?.body, 
                    hasItems: !!result?.body?.items,
                    itemCount: result?.body?.items?.length,
                    bodyKeys: result?.body ? Object.keys(result.body) : [],
                    resultKeys: result ? Object.keys(result) : [],
                    directItems: !!result?.items,
                    directItemCount: result?.items?.length,
                    firstItem: result?.body?.items?.[0]?.metadata?.name || result?.items?.[0]?.metadata?.name
                });
                // Try different response formats
                let items = result?.body?.items || result?.items || [];
                if (items && items.length > 0) {
                    const namespaces = items.map((ns) => ({
                        name: ns.metadata?.name,
                        uid: ns.metadata?.uid,
                        labels: ns.metadata?.labels || {},
                        creationTimestamp: ns.metadata?.creationTimestamp,
                    }));
                    res.json(namespaces);
                } else {
                    logger.warn('Invalid namespaces response format', { response: result?.body });
                    res.json([]);
                }
            } catch (err) {
                logger.error('Error fetching namespaces', { error: err.message });
                res.status(500).json({ error: 'Failed to fetch namespaces' });
            }
        });

        // Pods endpoint
        app.get('/api/pods', async (req, res) => {
            if (requireK8s(res)) return;
            try {
                const response = await k8sApi.listPodForAllNamespaces();
                logger.info('Pods API response', { 
                    hasResult: !!response, 
                    hasBody: !!response?.body, 
                    hasItems: !!response?.body?.items,
                    itemCount: response?.body?.items?.length,
                    directItems: !!response?.items,
                    directItemCount: response?.items?.length
                });
                // Try different response formats
                const items = response?.body?.items || response?.items || [];
                const pods = items.map((pod) => ({
                    metadata: pod.metadata,
                    spec: pod.spec,
                    status: pod.status,
                    ready: pod.status?.conditions?.find(c => c.type === 'Ready')?.status === 'True',
                    restartCount: pod.status?.containerStatuses?.[0]?.restartCount || 0,
                    phase: pod.status?.phase || 'Unknown',
                    nodeName: pod.spec?.nodeName
                }));
                res.json(pods);
            } catch (err) {
                logger.error('Error fetching pods', { error: err.message });
                res.status(500).json({ error: 'Failed to fetch pods' });
            }
        });

        // Services endpoint
        app.get('/api/services', async (req, res) => {
            if (requireK8s(res)) return;
            try {
                const response = await k8sApi.listServiceForAllNamespaces();
                if (response && response.body && response.body.items) {
                    const services = response.body.items.map((service) => ({
                        metadata: service.metadata,
                        spec: service.spec,
                        status: service.status,
                        type: service.spec?.type,
                        clusterIP: service.spec?.clusterIP,
                        ports: service.spec?.ports
                    }));
                    res.json(services);
                } else {
                    logger.warn('Invalid services response format', { response: response?.body });
                    res.json([]);
                }
            } catch (err) {
                logger.error('Error fetching services', { error: err.message });
                res.status(500).json({ error: 'Failed to fetch services' });
            }
        });

        // Deployments endpoint
        app.get('/api/deployments', async (req, res) => {
            if (requireK8s(res)) return;
            try {
                if (!kc) {
                    throw new Error('Kubernetes client not initialized');
                }
                const k8sAppsApi = kc.makeApiClient(k8s.AppsV1Api);
                const response = await k8sAppsApi.listDeploymentForAllNamespaces();
                const items = response?.body?.items || response?.items || [];
                const deployments = items.map((deployment) => ({
                    metadata: deployment.metadata,
                    spec: deployment.spec,
                    status: deployment.status,
                    replicas: deployment.status?.replicas || 0,
                    readyReplicas: deployment.status?.readyReplicas || 0,
                    availableReplicas: deployment.status?.availableReplicas || 0
                }));
                res.json(deployments);
            } catch (err) {
                logger.error('Error fetching deployments', { error: err.message });
                res.status(500).json({ error: 'Failed to fetch deployments' });
            }
        });

        // Nodes endpoint
        app.get('/api/nodes', async (req, res) => {
            if (requireK8s(res)) return;
            try {
                const response = await k8sApi.listNode();
                const items = response?.body?.items || response?.items || [];
                const nodes = items.map((node) => ({
                    metadata: node.metadata,
                    spec: node.spec,
                    status: node.status,
                    ready: node.status?.conditions?.find(c => c.type === 'Ready')?.status === 'True',
                    nodeInfo: node.status?.nodeInfo,
                    capacity: node.status?.capacity,
                    allocatable: node.status?.allocatable
                }));
                res.json(nodes);
            } catch (err) {
                logger.error('Error fetching nodes', { error: err.message });
                res.status(500).json({ error: 'Failed to fetch nodes' });
            }
        });

        // Helper function to format timestamp
        const formatTimestamp = (date) => {
            return date.toISOString();
        };

        // CRDs endpoint
        app.get('/crds', async (req, res) => {
            try {
                logger.info('Fetching CRDs');
                const response = await k8sApiExt.listCustomResourceDefinition();

                if (!response || !response.body || !response.body.items) {
                    logger.info('No CRDs found');
                    const output = 'NAME                  CREATED AT\n';
                    res.set('Content-Type', 'text/plain');
                    res.send(output);
                    return;
                }

                let output = 'NAME                  CREATED AT\n';
                response.body.items.forEach(crd => {
                    const name = crd.metadata.name;
                    const createdAt = formatTimestamp(new Date(crd.metadata.creationTimestamp));
                    output += `${name.padEnd(22)} ${createdAt}\n`;
                });

                res.set('Content-Type', 'text/plain');
                res.send(output);
            } catch (err) {
                logger.error('Error fetching CRDs', { error: err.message });
                res.status(500).set('Content-Type', 'text/plain').send(`Error fetching CRDs: ${err.message || err}`);
            }
        });

        // Microservices endpoint - Fixed the bug
        app.get('/crds/microservices', async (req, res) => {
            if (requireK8s(res)) return;
            try {
                if (!k8sApiCR) {
                    throw new Error('Kubernetes Custom Resource API client not initialized');
                }
                
                const group = 'codeco.he-codeco.eu';
                const version = 'v1alpha1';
                const plural = 'codecoapps';

                const response = await k8sApiCR.listClusterCustomObject(group, version, plural);
                const items = response?.body?.items || response?.items || [];

                if (items.length === 0) {
                    return res.status(200).json([]);
                }

                const microservices = items.map((item) => ({
                    name: item.metadata?.name || 'Unknown',
                    namespace: item.metadata?.namespace || 'Unknown',
                    spec: item.spec || {},
                    status: item.status || {}
                }));

                res.status(200).json(microservices);
            } catch (err) {
                logger.error('Error fetching microservices', { error: err.message });
                res.status(500).json({ error: 'Failed to fetch microservices' });
            }
        });

        // Error handling middleware
        app.use((err, req, res, next) => {
            logger.error('Unhandled error', { error: err.message, stack: err.stack });
            res.status(500).json({ error: 'Internal server error' });
        });

        // 404 handler
        app.use((req, res) => {
            res.status(404).json({ error: 'Not found' });
        });

        const PORT = process.env.PORT || 5000;
        app.listen(PORT, () => {
            logger.info(`Server running on port ${PORT}`);
        });

    } catch (error) {
        logger.error('Failed to start server', { error: error.message });
        process.exit(1);
    }
}

// Handle graceful shutdown
process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    logger.info('SIGINT received, shutting down gracefully');
    process.exit(0);
});

setupK8sAndStartServer().catch(error => {
    logger.error('Failed to setup K8s and start server', { error: error.message });
    process.exit(1);
});


