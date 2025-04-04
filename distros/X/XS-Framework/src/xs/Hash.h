#pragma once
#include <xs/Sv.h>
#include <iterator>
#include <xs/Scalar.h>
#include <xs/KeyProxy.h>
#include <xs/HashEntry.h>
#include <panda/string_view.h>

namespace xs {

struct Hash : Sv {
    static Hash create () { return Hash(newHV(), NONE); }

    static Hash create (size_t cap) {
        auto ret = create();
        ret.reserve(cap);
        return ret;
    }

    static Hash create (const std::initializer_list<std::pair<panda::string_view, Scalar>>& l) { return Hash(l); }

    static Hash noinc  (SV* val) { return Hash(val, NONE); }
    static Hash noinc  (HV* val) { return Hash(val, NONE); }

    Hash (std::nullptr_t = nullptr) {}
    Hash (SV* sv, bool policy = INCREMENT) : Sv(sv, policy) { _validate(); }
    Hash (HV* sv, bool policy = INCREMENT) : Sv(sv, policy) {}

    Hash (const Hash& oth) : Sv(oth)            {}
    Hash (Hash&&      oth) : Sv(std::move(oth)) {}
    Hash (const Sv&   oth) : Hash(oth.get())    {}
    Hash (Sv&&        oth) : Sv(std::move(oth)) { _validate(); }

    Hash (const Simple&) = delete;
    Hash (const Array&)  = delete;
    Hash (const Sub&)    = delete;
    Hash (const Glob&)   = delete;
    Hash (const Io&)     = delete;

    Hash (const std::initializer_list<std::pair<panda::string_view, Scalar>>&);

    Hash& operator= (SV* val)         { Sv::operator=(val); _validate(); return *this; }
    Hash& operator= (HV* val)         { Sv::operator=(val); return *this; }
    Hash& operator= (std::nullptr_t)  { Sv::operator=(nullptr); return *this; }
    Hash& operator= (const Hash& oth) { Sv::operator=(oth); return *this; }
    Hash& operator= (Hash&& oth)      { Sv::operator=(std::move(oth)); return *this; }
    Hash& operator= (const Sv& oth)   { return operator=(oth.get()); }
    Hash& operator= (Sv&& oth)        { Sv::operator=(std::move(oth)); _validate(); return *this; }
    Hash& operator= (const Simple&)   = delete;
    Hash& operator= (const Array&)    = delete;
    Hash& operator= (const Sub&)      = delete;
    Hash& operator= (const Glob&)     = delete;
    Hash& operator= (const Io&)       = delete;

    void set (SV* val) { Sv::operator=(val); }

    operator AV* () const = delete;
    operator HV* () const { return (HV*)sv; }
    operator CV* () const = delete;
    operator GV* () const = delete;
    operator IO* () const = delete;

    HV* operator-> () const { return (HV*)sv; }

    template <typename T = SV> panda::enable_if_one_of_t<T,SV,HV>* get () const { return (T*)sv; }

    Scalar fetch (const panda::string_view& key) const {
        if (!sv) return Scalar();
        SV** ref = hv_fetch((HV*)sv, key.data(), key.length(), 0);
        Scalar ret;
        if (ref) ret.set(*ref);
        return ret;
    }

    Scalar at (const panda::string_view& key) const {
        Scalar ret = fetch(key);
        if (!ret) throw std::out_of_range("at: no key");
        return ret;
    }

    Scalar operator[] (const panda::string_view& key) const { return fetch(key); }

    void store (const panda::string_view& key, const Scalar& val, U32 hash = 0);
    void store (const panda::string_view& key, std::nullptr_t,    U32 hash = 0) { store(key, Scalar(), hash); }
    void store (const panda::string_view& key, SV* v,             U32 hash = 0) { store(key, Scalar(v), hash); }
    void store (const panda::string_view& key, const Sv& v,       U32 hash = 0) { store(key, Scalar(v), hash); }
    void store (const panda::string_view& key, const Array&,      U32 hash = 0) = delete;
    void store (const panda::string_view& key, const Hash&,       U32 hash = 0) = delete;
    void store (const panda::string_view& key, const Sub&,        U32 hash = 0) = delete;
    void store (const panda::string_view& key, const Io&,         U32 hash = 0) = delete;

    KeyProxy operator[] (const panda::string_view& key) { return KeyProxy(hv_fetch((HV*)sv, key.data(), key.length(), 1), false); }

    Scalar erase (const panda::string_view& key) {
        Scalar ret;
        ret.set(hv_delete((HV*)sv, key.data(), key.length(), 0));
        return ret;
    }

    bool contains (const panda::string_view& key) const { return exists(key); }
    bool exists   (const panda::string_view& key) const {
        if (!sv) return false;
        return hv_exists((HV*)sv, key.data(), key.length());
    }

    size_t size     () const { return sv ? HvUSEDKEYS(sv) : 0; }
    size_t capacity () const { return sv ? HvMAX(sv)+1 : 0; }

    void reserve (size_t newcap) { hv_ksplit((HV*)sv, newcap); }

    void undef () { if (sv) hv_undef((HV*)sv); }
    void clear () { if (sv) hv_clear((HV*)sv); }

    struct const_iterator {
        using difference_type = std::ptrdiff_t;
        using value_type = const HashEntry;
        using pointer = value_type*;
        using reference = value_type&;
        using iterator_category = std::forward_iterator_tag;

        const_iterator () : arr(NULL), end(NULL), cur(HashEntry()) {}

        const_iterator (HV* hv) : arr(HvARRAY(hv)), end(arr ? arr + HvMAX(hv) + 1 : nullptr), cur(HashEntry()) {
            if (HvUSEDKEYS(hv)) operator++();
        }

        const_iterator (const const_iterator& oth) : arr(oth.arr), end(oth.end), cur(oth.cur) {}

        const_iterator& operator++ () {
            if (cur) {
                cur = HeNEXT(cur);
                if (cur) return *this;
            }
            while (!cur && arr != end) cur = *arr++;
            return *this;
        }

        const_iterator operator++ (int) {
            const_iterator ret = *this;
            operator++();
            return ret;
        }

        bool operator== (const const_iterator& oth) const { return cur == oth.cur; }
        bool operator!= (const const_iterator& oth) const { return cur != oth.cur; }

        const HashEntry* operator-> () { return &cur; }
        const HashEntry& operator*  () { return cur; }

        const_iterator& operator= (const const_iterator& oth) {
            arr = oth.arr;
            end = oth.end;
            cur = oth.cur;
            return *this;
        }

    protected:
        HE**      arr;
        HE**      end;
        HashEntry cur;
    };

    struct iterator : const_iterator {
        using const_iterator::const_iterator;

        using value_type = HashEntry;
        using pointer = value_type*;
        using reference = value_type&;

        HashEntry* operator-> () { return &cur; }
        HashEntry& operator*  () { return cur; }
    };

    const_iterator cbegin () const { return sv ? const_iterator((HV*)sv) : const_iterator(); }
    const_iterator cend   () const { return const_iterator(); }
    const_iterator begin  () const { return cbegin(); }
    const_iterator end    () const { return cend(); }
    iterator       begin  ()       { return sv ? iterator((HV*)sv) : iterator(); }
    iterator       end    ()       { return iterator(); }

    U32 push_on_stack (SV** sp) const;

private:
    void _validate () {
        if (!sv) return;
        if (SvTYPE(sv) == SVt_PVHV) return;
        if (SvROK(sv)) {           // reference to hash?
            SV* val = SvRV(sv);
            if (SvTYPE(val) == SVt_PVHV) {
                Sv::operator=(val);
                return;
            }
        }
        if (is_undef()) return reset();
        reset();
        throw std::invalid_argument("SV is not a Hash or Hash reference");
    }
};

}

