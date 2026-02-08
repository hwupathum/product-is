"""
Client configurations with dynamically generated certificates to avoid expiration.
"""

import sys
import os

# Add parent directory to path to import generate_certs
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'resource-server', 'jwks_to_host'))
from generate_certs import generate_client_jwks, generate_mtls_cert_and_key

# Generate fresh client JWKS and mTLS certificates
_client1_jwks = generate_client_jwks(validity_days=365)
_client2_jwks = generate_client_jwks(validity_days=365)
_mtls1 = generate_mtls_cert_and_key(validity_days=365)
_mtls2 = generate_mtls_cert_and_key(validity_days=365)

client_configs = {
    "client": {
        "jwks": _client1_jwks
    },
    "client2": {
        "jwks": _client2_jwks
    },
    "mtls": _mtls1,
    "mtls2": _mtls2
}
