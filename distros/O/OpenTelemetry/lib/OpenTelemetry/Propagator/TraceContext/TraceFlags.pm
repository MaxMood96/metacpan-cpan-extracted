use Object::Pad ':experimental(init_expr)';
# ABSTRACT: Represents TraceFlags in a W3C TraceContext

package OpenTelemetry::Propagator::TraceContext::TraceFlags;

our $VERSION = '0.030';

class OpenTelemetry::Propagator::TraceContext::TraceFlags {
    use OpenTelemetry::Common ();
    my $logger = OpenTelemetry::Common::internal_logger;

    field $flags :param :reader = 0;

    sub BUILDARGS ( $class, $flags = undef ) {
        $flags //= 0;

        if ( $flags !~ /^\d+$/a ) {
            $logger->warn(
                'Non-numeric value when creating TraceFlags',
                { value => $flags },
            );
            $flags = 0;
        }

        if ( 0 > $flags || $flags > 255 ) {
            $logger->warn(
                'Out-of-range value when creating TraceFlags',
                { value => $flags },
            );
            $flags = 0;
        }

        ( flags => $flags );
    }

    method to_string () { sprintf '%02x', $flags }

    method sampled () { !!( $flags & 1 ) }
}
