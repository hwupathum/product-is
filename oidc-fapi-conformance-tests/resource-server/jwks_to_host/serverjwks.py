"""
Server JWKS 1 - Dynamically generated to avoid certificate expiration.
"""

from .generate_certs import generate_server_jwks

# Generate fresh JWKS with 365 days validity
jwks = generate_server_jwks(validity_days=365)
