#include <openssl/opensslv.h>
#include <openssl/ssl.h>

#if OPENSSL_VERSION_NUMBER < 0x10101000L
#error Linux::Event::TLS requires OpenSSL 1.1.1 or newer
#endif

int
main(void)
{
    SSL_CTX *ctx = SSL_CTX_new(TLS_method());
    if (ctx)
        SSL_CTX_free(ctx);
    return ctx ? 0 : 1;
}
