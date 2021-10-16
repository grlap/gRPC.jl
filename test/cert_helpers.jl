using Dates
using OpenSSL

"""
function create_self_signed_certificate2()
# Create a root certificate.
x509_certificate = X509Certificate()

evp_pkey_ca = EvpPKey(rsa_generate_key())
x509_certificate.public_key = evp_pkey_ca

x509_name = X509Name()
add_entry(x509_name, "C", "US")
add_entry(x509_name, "ST", "Isles of Redmond")
add_entry(x509_name, "CN", "www.redmond.com")

x509_certificate.subject_name = x509_name
x509_certificate.issuer_name = x509_name

adjust(x509_certificate.time_not_before, Second(0))
adjust(x509_certificate.time_not_after, Year(1))

add_extension(x509_certificate, X509Extension("basicConstraints", "CA:TRUE"))
add_extension(x509_certificate, X509Extension("keyUsage", "keyCertSign"))

sign_certificate(x509_certificate, evp_pkey_ca)

root_certificate = x509_certificate

# Create a certificate sign request.
x509_request = X509Request()

evp_pkey = EvpPKey(rsa_generate_key())

x509_name = X509Name()
add_entry(x509_name, "C", "US")
add_entry(x509_name, "ST", "Isles of Redmond")
add_entry(x509_name, "CN", "www.redmond.com")

x509_request.subject_name = x509_name

x509_exts = StackOf{X509Extension}()

ext = X509Extension("subjectAltName", "DNS:localhost")
OpenSSL.push(x509_exts, ext)
add_extensions(x509_request, x509_exts)
finalize(ext)

finalize(x509_exts)

sign_request(x509_request, evp_pkey)

# Create a certificate.
x509_certificate = X509Certificate()
x509_certificate.version = 2

# Set issuer and subject name of the cert from the req and CA.
x509_certificate.subject_name = x509_request.subject_name
x509_certificate.issuer_name = root_certificate.subject_name

x509_exts = x509_request.extensions

ext = OpenSSL.pop(x509_exts)

add_extension(x509_certificate, ext)
add_extension(x509_certificate, X509Extension("keyUsage", "digitalSignature, nonRepudiation, keyEncipherment"))
add_extension(x509_certificate, X509Extension("basicConstraints", "CA:FALSE"))

# Set public key
x509_certificate.public_key = x509_request.public_key

adjust(x509_certificate.time_not_before, Second(0))
adjust(x509_certificate.time_not_after, Year(1))

sign_certificate(x509_certificate, evp_pkey_ca)

##sign_certificate
#p12_object = P12Object(evp_pkey, root_certificate)

#return p12_object

private_key_io = IOBuffer()
write(private_key_io, evp_pkey)

public_key_io = IOBuffer()
write(public_key_io, root_certificate)

private_key_pem = String(take!(private_key_io))
public_key_pem = String(take!(public_key_io))

return private_key_pem, public_key_pem

end
"""

"""
    Creates a self signed certificate.
"""
function create_self_signed_certificate()
    x509_certificate = X509Certificate()

    evp_pkey = EvpPKey(rsa_generate_key())
    x509_certificate.public_key = evp_pkey

    x509_name = X509Name()
    add_entry(x509_name, "C", "US")
    add_entry(x509_name, "ST", "Isles of Redmond")
    add_entry(x509_name, "CN", "www.redmond.com")

    x509_certificate.subject_name = x509_name
    x509_certificate.issuer_name = x509_name

    adjust(x509_certificate.time_not_before, Second(0))
    adjust(x509_certificate.time_not_after, Year(1))

    add_extension(x509_certificate, X509Extension("basicConstraints", "CA:TRUE"))
    add_extension(x509_certificate, X509Extension("keyUsage", "keyCertSign"))

    sign_certificate(x509_certificate, evp_pkey)

    private_key_io = IOBuffer()
    write(private_key_io, evp_pkey)
    
    public_key_io = IOBuffer()
    write(public_key_io, x509_certificate)
    
    private_key_pem = String(take!(private_key_io))
    public_key_pem = String(take!(public_key_io))
    
    return private_key_pem, public_key_pem
    end
