const config = {
  apiUrl: process.env.REACT_APP_API_URL || 'http://localhost:5000',
  environment: process.env.NODE_ENV || 'development',
  endpoints: {
    applyYaml: '/apply-yaml',
    getStatus: '/get-status',
    namespaces: '/api/namespaces',
    pods: '/api/pods',
    crds: '/crds'
  }
};

export default config; 