"""
Simple Flask application for Cloud Run training.

This app demonstrates:
- Reading the PORT environment variable (required by Cloud Run)
- Basic HTTP endpoints
- Environment variable usage
- Health checks
"""

from flask import Flask, request, jsonify
import os
import sys
import json
from datetime import datetime

app = Flask(__name__)

# Configuration from environment variables
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'development')
VERSION = os.environ.get('VERSION', '1.0.0')
PORT = int(os.environ.get('PORT', 8080))


def log(message, severity='INFO'):
    """
    Write structured logs for Cloud Logging.
    """
    entry = {
        'severity': severity,
        'message': message,
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    }
    print(json.dumps(entry), file=sys.stdout, flush=True)


@app.route('/')
def hello():
    """
    Main endpoint - says hello!
    """
    name = request.args.get('name', 'World')
    return f'Hello {name}! Welcome to the Cloud Run training app.\n'


@app.route('/health')
def health():
    """
    Health check endpoint.
    Returns 200 OK if the service is healthy.
    """
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    }), 200


@app.route('/info')
def info():
    """
    Returns information about the service.
    """
    return jsonify({
        'service': 'cloud-run-training-app',
        'version': VERSION,
        'environment': ENVIRONMENT,
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'revision': os.environ.get('K_REVISION', 'unknown'),
        'service_name': os.environ.get('K_SERVICE', 'unknown')
    })


@app.route('/echo', methods=['GET', 'POST'])
def echo():
    """
    Echo endpoint - returns request details.
    """
    return jsonify({
        'method': request.method,
        'path': request.path,
        'args': dict(request.args),
        'headers': dict(request.headers),
        'data': request.get_data(as_text=True) if request.data else None
    })


@app.errorhandler(404)
def not_found(error):
    """
    Custom 404 handler.
    """
    return jsonify({
        'error': 'Not Found',
        'message': 'The requested endpoint does not exist',
        'path': request.path
    }), 404


@app.errorhandler(500)
def internal_error(error):
    """
    Custom 500 handler.
    """
    log(f'Internal error: {str(error)}', severity='ERROR')
    return jsonify({
        'error': 'Internal Server Error',
        'message': 'An unexpected error occurred'
    }), 500


if __name__ == '__main__':
    log(f'Starting Flask app on port {PORT}')
    log(f'Environment: {ENVIRONMENT}, Version: {VERSION}')

    # Cloud Run requires listening on 0.0.0.0
    app.run(host='0.0.0.0', port=PORT, debug=False)
