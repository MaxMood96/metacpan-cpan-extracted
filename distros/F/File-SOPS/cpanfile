requires 'perl', '5.014';

requires 'Crypt::Age', '0.003';
requires 'CryptX';
requires 'YAML::XS';
# Only used to recover document key order for MAC verification; YAML::XS stays
# the parser and emitter. See the MAC section of File::SOPS.
requires 'YAML::PP';
# JSON::MaybeXS is used for JSON::PP::Boolean (JSON->true/false), which every
# one of its backends agrees on. It is NOT what emits or parses documents:
# it binds a backend once per process by load order, so the calling program
# decided our wire bytes, and the backends disagree on floats in ways that
# break MAC verification in both directions. Format::JSON names
# Cpanel::JSON::XS instead -- see docs/adr/0005. The version is the one
# JSON::MaybeXS itself asks for, so this is usually already installed.
requires 'JSON::MaybeXS';
requires 'Cpanel::JSON::XS', '4.38';
requires 'Moo';
requires 'namespace::clean';

# Core, but declared explicitly because this distribution has no AutoPrereqs
# B is used to read a scalar's IOK/NOK flags, which is how a value's SOPS type
# is determined -- see File::SOPS::Encrypted::detect_type and docs/adr/0002.
requires 'B';
requires 'Carp';
requires 'Cwd';
requires 'Digest::SHA';
requires 'Fcntl';
requires 'File::Basename';
requires 'File::Spec';
# In-place writes go to a temporary file next to the target and are renamed
# over it, and File::SOPS::edit puts the decrypted document in a temporary
# directory of its own -- see the edit method.
requires 'File::Temp';
# The carrier that gets a 16-17 digit double into JSON as a bare number.
# Cpanel::JSON::XS renders an NV through %.15g and quotes every other wrapper
# tried, so a Math::BigFloat under allow_bignum is the only measured way to
# write the decimal the MAC digest covers. See docs/adr/0006.
requires 'Math::BigFloat';
requires 'MIME::Base64';
requires 'POSIX';
requires 'Scalar::Util';
# $EDITOR is split into words the way a shell would, as sops splits it too.
requires 'Text::ParseWords';

on test => sub {
    requires 'Test::More';
    requires 'File::Slurp';
    requires 'File::Temp';
    # t/22-creation-rules.t builds .sops.yaml fixture trees several levels deep.
    requires 'File::Path';
};

on develop => sub {
    # xt/author/pod-links.t checks L<> resolution over the WOVEN pod (Test::Pod,
    # a separate develop-phase prereq registered by [PodSyntaxTests] itself,
    # only checks syntax) -- see k98.
    requires 'Pod::Checker';
};
