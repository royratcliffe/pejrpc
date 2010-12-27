require 'openssl'

namespace :rsa do
  desc "Generate 2048-bit RSA private and public keys"
  task :gen do
    rsa = OpenSSL::PKey::RSA.new(2048)
    print rsa.to_pem
    print rsa.public_key.to_pem
    # Please note that the private key encloses the public key, since you can generate public keys from private ones. You need to keep the private key, well, private.
  end
end
