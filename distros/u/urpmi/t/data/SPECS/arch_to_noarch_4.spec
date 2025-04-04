# For CPAN testers that run FreeBSD:
%global __brp_strip_static_archive %nil
# Fix build with rpm-4.20:
%global debug_package %{nil}

Summary: arch_to_noarch
Name: arch_to_noarch
Version: 4
Release: 1
License: x

%prep

%build

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/usr/lib/test-%{name}
cp /sbin/ldconfig $RPM_BUILD_ROOT/usr/lib/test-%{name}

%clean
rm -rf $RPM_BUILD_ROOT

%description
this pkg is now a binary again

%files
%defattr(-,root,root)
%config(noreplace) /usr/lib/test-%{name}

