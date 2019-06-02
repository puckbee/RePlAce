#include "pinPlace.h"


IoPlacementInst::IOPlacementInst( 
    NET* nets, int netCnt,
    int hzMetal, int vtMetal)

  : IOPlacement(), ckt_(0), net(nets_), netCnt(netCnt_),
  hzMetal_(hzMetal), vtMetal_(vtMetal),
  unitX_(FLT_MAX), unitY_(FLT_MAX), 
  offsetX_(FLT_MAX), offsetY_(FLT_MAX),
  defDbu_(FLT_MAX) {

  Init();  
};


void 
IoPlacementInst::Init() {

  // Set variables
  SetScaleDownParam();
  SetCircuitInst();

  IOPlacement* io_ = this;

  // CoreArea Update
  DieRect corerArea = GetCoreFromRow();

  io_->initCore( 
      point(coreArea.llx, coreArea.lly), 
      point(coreArea.urx, coreArea.ury), 
      spacingX, spacingY, 
      coreArea.llx, coreArea.lly ); 

  io_->setMetalLayers(hzMetal_, vtMetal_);



  for(int i=0; i<netCnt_; i++) {
    NET* curNet = &nets_[i];
    io_->addIOPin()

  }

}
