package DeyeCloud::Client::Device;
use strict;
use warnings 'FATAL' => 'all';
no warnings qw(experimental::signatures);
use feature qw(signatures);
use parent qw(DeyeCloud::Client::Common Class::Accessor);

our $VERSION = $DeyeCloud::Client::Common::VERSION;

use constant {
    BASEURL => 'https://www.deyecloud.com/device-s',
    METHOD  => 'GET'
};

use POSIX qw();

BEGIN {
    require Exporter;
    our @ISA = qw(Class::Accessor Exporter);
    our @EXPORT = qw();
}

sub new :prototype($%) ($class, %options) {
    map { $_ = 0 unless defined $_ } values %options;
    __PACKAGE__->mk_ro_accessors(keys %options);
    return bless { %options }, __PACKAGE__;
}

sub updateTime :prototype($) ($self) {
    return POSIX::strftime('%F %T %Z', (localtime $self->updateTimestamp)[0 .. 5]);
}

*batteryI = \&BATC1;

*batteryP = \&B_P1;

*batteryT = \&B_T1;

*batteryV = \&B_V1;

*bmsSOC = \&B_left_cap1;

*bmsChrgILimit = \&BMS_C_C_L;

*bmsDschILimit = \&BMS_D_C_L;

*gridI1 = \&G_C_L1;

*gridI2 = \&G_C_L2;

*gridI3 = \&G_C_L3;

*gridF = \&A_Fo1;

*gridP1 = \&G_P_L1;

*gridP2 = \&G_P_L2;

*gridP3 = \&G_P_L3;

*gridV1 = \&G_V_L1;

*gridV2 = \&G_V_L2;

*gridV3 = \&G_V_L3;

*loadF = \&L_F;

*loadP1 = \&C_P_L1;

*loadP2 = \&C_P_L2;

*loadP3 = \&C_P_L3;

*loadV1 = \&C_V_L1;

*loadV2 = \&C_V_L2;

*loadV3 = \&C_V_L3;

*updateTimestamp = \&zd;

1;
