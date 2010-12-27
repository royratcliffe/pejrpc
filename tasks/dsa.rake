require 'openssl'

namespace :dsa do
  desc "Generate 2048-bit DSA private and public keys"
  task :gen do
    dsa = OpenSSL::PKey::DSA.new(2048)
    print dsa.to_pem
    print dsa.public_key
  end
end
