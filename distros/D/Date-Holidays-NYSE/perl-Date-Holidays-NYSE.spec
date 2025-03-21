Name:           perl-Date-Holidays-NYSE
Version:        0.04
Release:        1%{?dist}
Summary:        Date::Holidays Adapter for New York Stock Exchange (NYSE) holidays
License:        mit
Group:          Development/Libraries
URL:            http://search.cpan.org/dist/Date-Holidays-NYSE/
Source0:        http://www.cpan.org/modules/by-module/Date/Date-Holidays-NYSE-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch
BuildRequires:  perl(Date::Calc) >= 5
BuildRequires:  perl(Exporter)
BuildRequires:  perl(ExtUtils::MakeMaker)
Requires:       perl(Date::Calc) >= 5
Requires:       perl(Exporter)
Requires:       perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))

%description
Date::Holidays Adapter for New York Stock Exchange (NYSE) holidays

%prep
%setup -q -n Date-Holidays-NYSE-%{version}

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
%doc Changes LICENSE README.md
%{perl_vendorlib}/*
%{_mandir}/man3/*

%changelog
* Wed Dec 27 2023 Michael R. Davis <mrdvt@cpan.org> 0.01-1
- Specfile autogenerated by cpanspec 1.78.
