#include "function.h"
#include "catch.h"

namespace xs { namespace func {

Sv::payload_marker_t out_marker;
Sv::payload_marker_t in_marker;

static bool init () {
    out_marker.svt_free = [](pTHX_ SV*, MAGIC* mg) -> int {
        auto fc = reinterpret_cast<IFunctionCaller*>(mg->mg_ptr);
        delete fc;
        return 0;
    };

    #ifdef USE_ITHREADS
        out_marker.svt_dup = [](pTHX_ MAGIC* mg, CLONE_PARAMS*) -> int {
            mg->mg_ptr = (char*)reinterpret_cast<IFunctionCaller*>(mg->mg_ptr)->clone();
            return 0;
        };

        in_marker.svt_free = [](pTHX_ SV*, MAGIC* mg) -> int {
            //printf("SVT FREE IN CALLED %p %p\n", sv, aTHX);
            auto pad = reinterpret_cast<SubPad*>(mg->mg_ptr);
            pad->remove_sub();
            pad->release();
            return 0;
        };

        in_marker.svt_dup = [](pTHX_ MAGIC* mg, CLONE_PARAMS*) -> int {
            //printf("SVT DUP IN CALLED %p %p\n", mg->mg_obj, aTHX);
            auto pad = reinterpret_cast<SubPad*>(mg->mg_ptr);
            pad->add_sub(mg->mg_obj);
            pad->retain();
            return 0;
        };
    #endif

    return true;
}
static const bool _init = init();

static void XS_function_call (pTHX_ CV* cv) { xs::throw_guard(cv, [=](){
    dVAR; dXSARGS;
    SP -= items;
    Sub sub(cv);
    auto fc = reinterpret_cast<IFunctionCaller*>(sub.payload(&out_marker).ptr);
    if (!fc) throw "invalid function->sub subroutine";
    auto ret = fc->call(&ST(0), items);
    if (!ret) XSRETURN_EMPTY;
    mXPUSHs(ret.detach());
    XSRETURN(1);
}); }

static PERL_ITHREADS_LOCAL CV* proto = (CV*)Sub::create(&XS_function_call).detach();

Sub create_sub (IFunctionCaller* fc) {
    auto ret = Sub::clone_anon_xsub(proto);
    auto mg = ret.payload_attach(fc, &out_marker);
    mg->mg_flags |= MGf_DUP;
    return ret;
}

#ifdef USE_ITHREADS
    SubPad* SubPad::get (Sub sub) {
        auto ptr = static_cast<SubPad*>(sub.payload(&in_marker).ptr);
        if (ptr) return ptr;
        ptr = new SubPad(sub);
        ptr->retain();
        auto mg = sub.payload_attach(ptr, &in_marker);
        mg->mg_flags |= MGf_DUP;
        mg->mg_obj = sub.get();
        return ptr;
    }

    SubPad::SubPad (const Sub& sub) : pad({{aTHX, sub}}) {}

    const Sub& SubPad::get_sub () const {
        std::lock_guard<std::mutex> lock(mutex);
        dTHX;
        for (auto& p : pad) if (p.first == aTHX) return p.second;
        throw "calling typemap'ed perl function from wrong thread or after perl global destroy / thread destroy";
    }

    void SubPad::add_sub (const Sub& sub) {
        std::lock_guard<std::mutex> lock(mutex);
        pad.push_back({aTHX, sub});
    }

    void SubPad::remove_sub () {
        std::lock_guard<std::mutex> lock(mutex);
        dTHX;
        for (size_t i = 0; i < pad.size(); ++i) {
            if (pad[i].first != aTHX) continue;
            pad.erase(pad.begin() + i);
            return;
        }
        throw "panic: empty typemap'ed perl function";
    }
#endif

}}
