#include "spvm_native.h"

#include "uv.h"


int32_t SPVM__TestCase__Resource__UV__test(SPVM_ENV* env, SPVM_VALUE* stack) {
  
  int32_t status = 0l;
  
  char uv_strerror[512];
  uv_strerror_r(status, uv_strerror, sizeof(uv_strerror));
  
  stack[0].ival = 1;
  
  return 0;
}


