use lib '.';
use inc::Module::Install;

RTx     'RT-Extension-AuditLog';
license 'gpl_2';
repository 'https://github.com/certat/rt-extension-auditlog';

requires_rt '4.0.0';
rt_too_new '5.2.0';

sign;
WriteAll;
