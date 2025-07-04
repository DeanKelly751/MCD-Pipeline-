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
    try {
        const k8s = await import('@kubernetes/client-node');

        // Kubernetes client setup
        const kc = new k8s.KubeConfig();
        kc.loadFromDefault();
        
        const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
        const k8sApiCR = kc.makeApiClient(k8s.CustomObjectsApi);
        const k8sApiExt = kc.makeApiClient(k8s.ApiextensionsV1Api);

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
            try {
                const result = await k8sApi.listNamespace();
                const namespaces = result.body.items.map((ns) => ({
                    name: ns.metadata.name,
                    uid: ns.metadata.uid,
                    labels: ns.metadata.labels || {},
                    creationTimestamp: ns.metadata.creationTimestamp,
                }));
                res.json(namespaces);
            } catch (err) {
                logger.error('Error fetching namespaces', { error: err.message });
                res.status(500).json({ error: 'Failed to fetch namespaces' });
            }
        });

        // Pods endpoint
        app.get('/api/pods', async (req, res) => {
            try {
                const response = await k8sApi.listPodForAllNamespaces();
                res.json(response.body.items);
            } catch (err) {
                logger.error('Error fetching pods', { error: err.message });
                res.status(500).json({ error: 'Failed to fetch pods' });
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
            try {
                const group = 'codeco.he-codeco.eu';
                const version = 'v1alpha1';
                const plural = 'codecoapps';

                const response = await k8sApiCR.listClusterCustomObject(group, version, plural);

                if (!response.body.items || response.body.items.length === 0) {
                    return res.status(200).json({ message: 'No microservices found.' });
                }

                const microservices = response.body.items.map((item) => ({
                    name: item.metadata?.name || 'Unknown',
                    namespace: item.metadata?.namespace || 'Unknown',
                    spec: item.spec || {}
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


