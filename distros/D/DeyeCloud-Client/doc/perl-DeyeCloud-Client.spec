Name:           perl-DeyeCloud-Client
Version:        0.0.2
Release:        1%{?dist}
Summary:        Deye Cloud API perl client
License:        Distributable, see LICENSE
Group:          Development/Libraries
URL:            https://github.com/kornix/perl-DeyeCloud-Client
Source0:        DeyeCloud-Client-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch
BuildRequires:  perl(ExtUtils::MakeMaker)
Requires:       perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))
Requires:	perl(Class::Accessor)
Requires:	perl(Class::XSAccessor)
Requires:	perl(HTTP::Request)
Requires:	perl(JSON)
Requires:	perl(LWP::UserAgent)
Requires:	perl(URI::Escape)
Provides:	perl(DeyeCloud::Client)

%description
Ningbo Deye Technology Co., Ltd. Cloud service API perl client
to retrieve information about Deye devices powered solar power
stations.

%prep
%setup -q -n DeyeCloud-Client-%{version}

rm -f pm_to_blib

%build
%{__perl} Makefile.PL INSTALLDIRS=vendor
make %{?_smp_mflags}

%install
rm -rf $RPM_BUILD_ROOT

make pure_install PERL_INSTALL_ROOT=$RPM_BUILD_ROOT

find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} \;
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null \;

%{_fixperms} $RPM_BUILD_ROOT/*

%check
make test

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc Changes LICENSE MYMETA.json MYMETA.yml README.md doc/perl-DeyeCloud-Client.spec
%dir %{perl_vendorlib}/DeyeCloud
%{perl_vendorlib}/DeyeCloud/*
%{_mandir}/man3/DeyeCloud*

%changelog

* Mon Feb 23 2026 Volodymyr Pidgornyi <vp@dtel-ix.net> 0.0.2-1
- Added readable and predictable aliases to device parameters names;
- Minor documentation updates.

* Thu Feb 19 2026 Volodymyr Pidgornyi <vp@dtel-ix.net> 0.0.1-1
- Initial release.
