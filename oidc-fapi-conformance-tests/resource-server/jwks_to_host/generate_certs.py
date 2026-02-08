"""
Dynamic certificate and JWKS generator for OIDC FAPI conformance tests.
This script generates fresh certificates and JWKS on demand to avoid expiration issues.
"""

import json
import base64
from datetime import datetime, timedelta
from cryptography import x509
from cryptography.x509.oid import NameOID, ExtensionOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend


def generate_rsa_key_pair(key_size=2048):
    """Generate RSA key pair."""
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=key_size,
        backend=default_backend()
    )
    return private_key


def int_to_base64url(value):
    """Convert integer to base64url encoded string."""
    # Convert to bytes
    value_bytes = value.to_bytes((value.bit_length() + 7) // 8, byteorder='big')
    # Base64url encode (without padding)
    return base64.urlsafe_b64encode(value_bytes).decode('utf-8').rstrip('=')


def generate_self_signed_cert(private_key, subject_name="CN=TestServer", validity_days=365):
    """Generate a self-signed certificate."""
    subject = issuer = x509.Name([
        x509.NameAttribute(NameOID.COUNTRY_NAME, "GB"),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, "OpenBanking"),
        x509.NameAttribute(NameOID.ORGANIZATIONAL_UNIT_NAME, "0015800001HQQrZAAX"),
        x509.NameAttribute(NameOID.COMMON_NAME, subject_name),
    ])
    
    cert = x509.CertificateBuilder().subject_name(
        subject
    ).issuer_name(
        issuer
    ).public_key(
        private_key.public_key()
    ).serial_number(
        x509.random_serial_number()
    ).not_valid_before(
        datetime.utcnow()
    ).not_valid_after(
        datetime.utcnow() + timedelta(days=validity_days)
    ).add_extension(
        x509.KeyUsage(
            digital_signature=True,
            content_commitment=False,
            key_encipherment=True,
            data_encipherment=False,
            key_agreement=False,
            key_cert_sign=False,
            crl_sign=False,
            encipher_only=False,
            decipher_only=False,
        ),
        critical=True,
    ).add_extension(
        x509.ExtendedKeyUsage([
            x509.oid.ExtendedKeyUsageOID.CLIENT_AUTH,
            x509.oid.ExtendedKeyUsageOID.SERVER_AUTH,
        ]),
        critical=True,
    ).sign(private_key, hashes.SHA256(), default_backend())
    
    return cert


def cert_to_pem(cert):
    """Convert certificate to PEM format."""
    return cert.public_bytes(serialization.Encoding.PEM).decode('utf-8')


def cert_to_der_base64(cert):
    """Convert certificate to DER format and base64 encode."""
    der_bytes = cert.public_bytes(serialization.Encoding.DER)
    return base64.b64encode(der_bytes).decode('utf-8')


def compute_thumbprint(cert, algorithm=hashes.SHA256()):
    """Compute certificate thumbprint."""
    fingerprint = cert.fingerprint(algorithm)
    return base64.urlsafe_b64encode(fingerprint).decode('utf-8').rstrip('=')


def generate_kid(cert):
    """Generate a key ID from certificate thumbprint."""
    return compute_thumbprint(cert, hashes.SHA1())


def private_key_to_jwk(private_key, kid, use="sig"):
    """Convert RSA private key to JWK format."""
    public_numbers = private_key.public_key().public_numbers()
    private_numbers = private_key.private_numbers()
    
    jwk = {
        "kty": "RSA",
        "kid": kid,
        "use": use,
        "n": int_to_base64url(public_numbers.n),
        "e": int_to_base64url(public_numbers.e),
        "d": int_to_base64url(private_numbers.d),
        "p": int_to_base64url(private_numbers.p),
        "q": int_to_base64url(private_numbers.q),
        "dp": int_to_base64url(private_numbers.dmp1),
        "dq": int_to_base64url(private_numbers.dmq1),
        "qi": int_to_base64url(private_numbers.iqmp),
    }
    
    if use == "sig":
        jwk["alg"] = "PS256"
    elif use == "enc":
        jwk["alg"] = "RSA-OAEP"
    
    return jwk


def public_key_to_jwk(private_key, kid, use="sig", cert=None):
    """Convert RSA public key to JWK format with optional x5c chain."""
    public_numbers = private_key.public_key().public_numbers()
    
    jwk = {
        "kty": "RSA",
        "kid": kid,
        "use": use,
        "n": int_to_base64url(public_numbers.n),
        "e": int_to_base64url(public_numbers.e),
    }
    
    if cert:
        jwk["x5c"] = [cert_to_der_base64(cert)]
        jwk["x5t"] = compute_thumbprint(cert, hashes.SHA1())
        jwk["x5t#S256"] = compute_thumbprint(cert, hashes.SHA256())
        jwk["x5u"] = f"https://keystore.openbankingtest.org.uk/0015800001HQQrZAAX/{kid}.pem"
    
    return jwk


def generate_server_jwks(validity_days=365):
    """Generate complete server JWKS with multiple keys."""
    # Generate keys
    enc_key = generate_rsa_key_pair()
    sig_key = generate_rsa_key_pair()
    tls_key = generate_rsa_key_pair()
    
    # Generate certificates
    sig_cert = generate_self_signed_cert(sig_key, "CN=TestSigningServer", validity_days)
    tls_cert = generate_self_signed_cert(tls_key, "CN=TestTLSServer", validity_days)
    
    # Generate KIDs
    enc_kid = generate_kid(generate_self_signed_cert(enc_key, "CN=TestEncServer", validity_days))
    sig_kid = generate_kid(sig_cert)
    tls_kid = generate_kid(tls_cert)
    
    # Build JWKS
    jwks = {
        "keys": [
            public_key_to_jwk(enc_key, enc_kid, "enc"),
            public_key_to_jwk(sig_key, sig_kid, "sig", sig_cert),
            public_key_to_jwk(tls_key, tls_kid, "tls", tls_cert),
        ]
    }
    
    return jwks


def generate_client_jwks(validity_days=365):
    """Generate client JWKS with signing and encryption keys."""
    # Generate keys
    sig_key = generate_rsa_key_pair()
    enc_key = generate_rsa_key_pair()
    
    # Generate certificates
    sig_cert = generate_self_signed_cert(sig_key, "CN=TestClientSigning", validity_days)
    
    # Generate KIDs
    sig_kid = generate_kid(sig_cert)
    enc_kid = generate_kid(generate_self_signed_cert(enc_key, "CN=TestClientEnc", validity_days))
    
    # Build private JWKS (with private keys)
    private_jwks = {
        "keys": [
            private_key_to_jwk(sig_key, sig_kid, "sig"),
            private_key_to_jwk(enc_key, enc_kid, "enc"),
        ]
    }
    
    return private_jwks


def generate_mtls_cert_and_key(validity_days=365):
    """Generate mTLS certificate and private key pair."""
    private_key = generate_rsa_key_pair()
    cert = generate_self_signed_cert(private_key, "CN=TestMTLSClient", validity_days)
    
    # Convert to PEM
    cert_pem = cert_to_pem(cert)
    key_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    ).decode('utf-8')
    
    return {
        "cert": cert_pem,
        "key": key_pem
    }


if __name__ == "__main__":
    # Generate and print sample JWKS
    print("Generating Server JWKS 1...")
    jwks1 = generate_server_jwks(validity_days=365)
    print(json.dumps(jwks1, indent=4))
    
    print("\n\nGenerating Server JWKS 2...")
    jwks2 = generate_server_jwks(validity_days=365)
    print(json.dumps(jwks2, indent=4))
    
    print("\n\nGenerating Client JWKS...")
    client_jwks = generate_client_jwks(validity_days=365)
    print(json.dumps(client_jwks, indent=4))
    
    print("\n\nGenerating mTLS Certificate...")
    mtls = generate_mtls_cert_and_key(validity_days=365)
    print("Certificate:")
    print(mtls["cert"])
    print("\nPrivate Key:")
    print(mtls["key"])
