#ifndef __REPLACE_IOPLACE__
#define __REPLACE_IOPLACE__ 0

#include "global.h"
#include "IOPlacement.h"

class IoPlacementInst : IOPlacement {
public:
  IoPlacementInst(NET* nets, int netCnt);
  void Init();

  void SetScaleFactor();
  void SetCircuitInst();

  void SetHorizonMetal(int hzMetal);
  void SetVerticalMetal(int vtMetal);

private:
  Replace::Circuit* ckt_;
  NET* nets_;
  int netCnt_;

  int hzMetal_;
  int vtMetal_;
  
  float unitX_;
  float unitY_; 
  float offsetX_;
  float offsetY_;
  float defDbu_;
};


#endif
