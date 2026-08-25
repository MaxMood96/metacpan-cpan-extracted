use v5.38;
use Object::Pad 0.825;

class CXC::Gnuplot::V1::Bound2 {
    method bar :common {
        say "before";
        say  __CLASS__;
        say "after";
    }
}

1;
