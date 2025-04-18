#pragma once
#include <xs/Sv.h>
#include <panda/string.h>

namespace xs {

using xs::my_perl;

namespace detail {
    template <typename T> inline panda::enable_if_signed_integral_t<T>   _getnum (SV* sv) { return SvIV(sv); }
    template <typename T> inline panda::enable_if_unsigned_integral_t<T> _getnum (SV* sv) { return SvUV(sv); }
    template <typename T> inline panda::enable_if_floatp_t<T>            _getnum (SV* sv) { return SvNV(sv); }

    struct AutoNumber {
        AutoNumber(SV* sv) : sv(sv) {}

        template <class T, typename = panda::enable_if_arithmetic_t<T>>
        operator T () const { return sv ? _getnum<T>(sv) : T(); }

    private:
        SV* sv;
    };
}

struct Scalar : Sv {
    static const Scalar undef;
    static const Scalar yes;
    static const Scalar no;

    static Scalar create () { return Scalar(newSV(0), NONE); }

    static Scalar noinc (SV* val) { return Scalar(val, NONE); }
    static Scalar noinc (GV* val) { return Scalar(val, NONE); }

    Scalar (std::nullptr_t = nullptr) {}

    Scalar (SV* sv, bool policy = INCREMENT) : Sv(sv, policy) { _validate(); }
    Scalar (GV* sv, bool policy = INCREMENT) : Sv(sv, policy) {}

    Scalar (const Scalar& oth) : Sv(oth)            {}
    Scalar (Scalar&&      oth) : Sv(std::move(oth)) {}
    Scalar (const Sv&     oth) : Scalar(oth.get())  {}
    Scalar (Sv&&          oth) : Sv(std::move(oth)) { _validate(); }

    Scalar (const Array&) = delete;
    Scalar (const Hash&)  = delete;
    Scalar (const Sub&)   = delete;
    Scalar (const Io&)    = delete;

    Scalar& operator= (SV* val) {
        Sv::operator=(val);
        _validate();
        return *this;
    }

    Scalar& operator= (GV* val) {
        Sv::operator=(val);
        return *this;
    }

    Scalar& operator= (const Scalar& oth) {
        Sv::operator=(oth.sv);
        return *this;
    }

    Scalar& operator= (Scalar&& oth) {
        Sv::operator=(std::move(oth));
        return *this;
    }

    Scalar& operator= (const Sv& oth) { return operator=(oth.get()); }

    Scalar& operator= (Sv&& oth) {
        Sv::operator=(std::move(oth));
        _validate();
        return *this;
    }

    Scalar& operator= (const Array&) = delete;
    Scalar& operator= (const Hash&)  = delete;
    Scalar& operator= (const Sub&)   = delete;
    Scalar& operator= (const Io&)    = delete;

    void set (SV* val) { Sv::operator=(val); }
    void set (GV* val) { Sv::operator=(val); }

    operator AV* () const = delete;
    operator HV* () const = delete;
    operator CV* () const = delete;
    operator IO* () const = delete;

    template <class T = SV> panda::enable_if_one_of_t<T,SV,GV>* get () const { return (T*)sv; }

    void upgrade (svtype type) {
        if (type > SVt_PVMG && type != SVt_PVGV) throw std::logic_error("can't upgrade Scalar to something bigger than PVMG (and != PVGV)");
        Sv::upgrade(type);
    }

    template <class T = panda::string>
    T as_string () const {
        if (!sv) return T();
        STRLEN len;
        const char* buf = SvPV_const(sv, len);
        return T(buf, len);
    }

    template <class T = int> T as_number () const { return sv ? detail::_getnum<T>(sv) : T(); }

    detail::AutoNumber number () const { return detail::AutoNumber(sv); }

    static void __at_perl_destroy ();

private:
    void _validate_rest();

    void _validate () {
        if (!sv || SvTYPE(sv) <= SVt_PVMG || SvTYPE(sv) == SVt_PVGV) return;
        _validate_rest();
    }
};

}
