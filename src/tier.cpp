///////////////////////////////////////////////////////////////////////////////
// Authors: Ilgweon Kang and Lutong Wang
//          (respective Ph.D. advisors: Chung-Kuan Cheng, Andrew B. Kahng),
//          based on Dr. Jingwei Lu with ePlace and ePlace-MS
//
//          Many subsequent improvements were made by Mingyu Woo
//          leading up to the initial release.
//
// BSD 3-Clause License
//
// Copyright (c) 2018, The Regents of the University of California
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.
//
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
//
// * Neither the name of the copyright holder nor the names of its
//   contributors may be used to endorse or promote products derived from
//   this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
///////////////////////////////////////////////////////////////////////////////

#include <climits>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>

#include "bookShelfIO.h"
#include "bin.h"
#include "global.h"
#include "macro.h"
#include "mkl.h"
#include "opt.h"

void tier_init_2D(int STAGE) {
  int i = 0;
  int min_idx = moduleCNT, max_idx = 0;
  struct TIER *tier = NULL;
  struct MODULE *modu = NULL;
  struct CELL *cell = NULL;

  for(int z = 0; z < numLayer; z++) {
    tier = &tier_st[z];
    tier->cell_st = (struct CELL **)mkl_malloc(
        sizeof(struct CELL *) * (tier->modu_cnt + gfiller_cnt), 64);
    tier->cell_cnt = 0;
  }

  cout << "tier->modu_cnt:" << tier->modu_cnt << endl;
  cout << "gfiller_cnt: " << gfiller_cnt << endl;

  for(i = 0; i < moduleCNT; i++) {
    modu = &moduleInstance[i];
    if(STAGE == cGP2D) {
      if(modu->flg == Macro)
        continue;
    }
    cell = &gcell_st[i];
    modu->tier = cell->tier = 0;
    tier = &tier_st[0];
    tier->cell_st[tier->cell_cnt] = cell;
    tier->cell_cnt++;
  }

  for(int z = 0; z < numLayer; z++) {
    tier = &tier_st[z];

    tier->filler_area =
        (tier->area - tier->virt_area - tier->term_area) * target_cell_den -
        tier->modu_area;

    // renewed calculation..!!
    //        tier->filler_area =
    //            (tier->area - tier->virt_area) * target_cell_den -
    //            tier->modu_area;

    printf("INFO: (tier %d) area: %.f\n", z, tier->area);
    printf("INFO: (tier %d) virt_area: %.f\n", z, tier->virt_area);
    printf("INFO: (tier %d) term_area: %.f\n", z, tier->term_area);
    printf("INFO: (tier %d) modu_area: %.f\n", z, tier->modu_area);
    printf("INFO: (tier %d) filler_area: %.f\n", z, tier->filler_area);
    fflush(stdout);

    tier->filler_cnt = (int)(tier->filler_area / filler_area + 0.5);

    max_idx = min_idx + tier->filler_cnt > gcell_cnt
                  ? gcell_cnt
                  : min_idx + tier->filler_cnt;
    cout << "min_idx: " << min_idx << endl;
    cout << "max_idx: " << max_idx << endl;
    cout << "gcell_cnt: " <<gcell_cnt << endl;
    cout << "tier->filler_cnt: " <<tier->filler_cnt<< endl;

    for(i = min_idx; i < max_idx; i++) {
      CELL *filler = &gcell_st[i];
      filler->tier = 0;
      tier->cell_st[tier->cell_cnt] = filler;
      tier->cell_cnt++;
    }

    min_idx = max_idx;
  }

  for(int z = 0; z < numLayer; z++) {
    tier = &tier_st[z];
    if(tier->cell_cnt == 0)
      mkl_free(tier->cell_st);
    else {
      // igkang:  replace realloc to mkl
      tier->cell_st_tmp = (CELL **)mkl_malloc(
          sizeof(struct CELL *) * (tier->modu_cnt + gfiller_cnt), 64);
      memcpy(tier->cell_st_tmp, tier->cell_st,
             sizeof(struct CELL *) * (tier->modu_cnt + gfiller_cnt));
      mkl_free(tier->cell_st);
      tier->cell_st =
          (CELL **)mkl_malloc(sizeof(struct CELL *) * tier->cell_cnt, 64);
      memcpy(tier->cell_st, tier->cell_st_tmp,
             sizeof(struct CELL *) * tier->cell_cnt);
      mkl_free(tier->cell_st_tmp);
      // tier->cell_st = (CELL**)realloc(tier->cell_st, sizeof(struct
      // CELL*)*tier->cell_cnt);
    }
  }
}

void tier_delete_mGP2D(void) {
  int z = 0;
  struct TIER *tier = NULL;

  for(z = 0; z < numLayer; z++) {
    tier = &tier_st[z];
    if(tier->cell_cnt > 0 && tier->cell_st)
      mkl_free(tier->cell_st);
    tier->cell_cnt = 0;
    tier->cell_st = NULL;

    if(tier->modu_cnt > 0 && tier->modu_st)
      free(tier->modu_st);
    tier->modu_cnt = 0;
    tier->modu_st = NULL;
  }
}

// 1: MIXED  0: CellOnly
void tier_assign(int mode) {  
  struct MODULE **modu_st =
      (struct MODULE **)malloc(sizeof(struct MODULE *) * moduleCNT);
  struct TIER *tier = NULL;

  int currTier = 0;
  tier = &tier_st[currTier];
  tier->modu_cnt = 0;
  if(moduleCNT > 0)
    tier->modu_st =
      (struct MODULE **)malloc(sizeof(struct MODULE *) * moduleCNT);
  else
    tier->modu_st = NULL;
  tier->modu_area = 0;

  for(int i = 0; i < moduleCNT; i++) {
    modu_st[i] = &moduleInstance[i];
  }

  MODULE *modu = NULL;
  for(int i = 0; i < moduleCNT; i++) {
    if(mode == STDCELLonly) {
      if(modu_st[i]->flg == Macro)
        continue;
      else
        modu = modu_st[i];
    }
    else {
      modu = modu_st[i];
    }

    tier = &tier_st[currTier];

    prec moduleArea = 0;
    if(mode == MIXED) {
      if(modu->flg == Macro)
        moduleArea = modu->size.GetProduct()* target_cell_den;
      else
        moduleArea = modu->size.GetProduct();
    }
    else if(mode == STDCELLonly) {
      moduleArea = modu->size.GetProduct();
    }
//     cout << modu->name << endl;
//     modu->size.Dump("Module Size");

//     cout << "tier's modu_area: " << tier->modu_area << endl;
//     cout << "modu_area: " << modu_area << endl;
//     cout << "tier's ws_area: " << tier->ws_area << endl;
//     cout << "target_cell_den: " << target_cell_den << endl;

    if((tier->modu_area + moduleArea) / tier->ws_area > target_cell_den) {
      cout << "** Warning: Exceed the placement Area" << endl;
      cout << "   ModuleArea     : " << tier->modu_area + moduleArea << endl; 
      cout << "   WhiteSpaceArea : " << tier->ws_area << endl;
      cout << "   TargetDensity  : " << target_cell_den << endl;
    }

    modu->tier = currTier;

    tier->modu_st[tier->modu_cnt++] = modu;
    tier->modu_area += moduleArea;

    for(int k = 0; k < modu->pinCNTinObject; k++) {
      PIN *pin = modu->pin[k];
      pin->tier = currTier;
    }
  }


  for(int i = 0; i < numLayer; i++) {
    tier = &tier_st[i];
    if(mode == MIXED) {
      if(tier->modu_cnt > 0 && tier->modu_st)
        tier->modu_st = (MODULE **)realloc(
            tier->modu_st, sizeof(struct MODULE *) * (tier->modu_cnt));
      else if(tier->modu_cnt == 0 && tier->modu_st) {
        free(tier->modu_st);
        tier->modu_st = NULL;
      }
    }
    else if(mode == STDCELLonly) {
      tier->modu_st = (MODULE **)realloc(
          tier->modu_st, sizeof(struct MODULE *) * (tier->modu_cnt));
    }
    // tier->modu_den = tier->modu_area / tier->ws_area;
    prec moduleDensity = tier->modu_area / tier->ws_area;

    printf("INFO:  Tier %d, Density is %.6lf\n", i, moduleDensity);
  }
//  cout << "Final module count: " << tier->modu_cnt << endl;
//  exit(1);
  free(modu_st);
}

//void find_close_tier(prec z, struct T0 *st, int *z_st) {
//  prec tier_center_z = 0;

//  for(int i = 0; i < numLayer; i++) {
//    tier_center_z = TIER_DEP * ((prec)i + 0.5);
//    st[i].dis = fabs(tier_center_z - z);
//    st[i].z = i;
//  }

//  qsort(st, numLayer, sizeof(struct T0), prec_cmp);

//  for(int i = 0; i < numLayer; i++) {
//    z_st[i] = st[i].z;
//  }

//  return;
//}

void init_tier(void) {
  prec pl_area = 0;
  struct TIER *tier = NULL;
  struct PLACE *pl = NULL;

  for(int i = 0; i < numLayer; i++) {
    tier = &tier_st[i];
    tier->mac_cnt = 0;
    tier->modu_cnt = 0;
    tier->filler_cnt = 0;
    tier->cell_cnt = 0;
    tier->cell_st = NULL;
    tier->modu_area = 0;
    tier->filler_area = 0;
    tier->virt_area = 0;
    tier->pl_area = 0;
    tier->temp_mac_area = 0;
    tier->max_mac = NULL;

    for(int j = 0; j < place_st_cnt; j++) {
      pl = &place_st[j];
      pl_area = pGetCommonAreaXY(pl->org, pl->end, tier->pmin, tier->pmax);
      tier->pl_area += pl_area;
    }
    tier->virt_area = tier->area - tier->pl_area;

    // this terminal Area calculation can be Wrong!!!
    tier->ws_area = tier->area - tier->term_area - tier->virt_area;

    // renewed!!
    //        tier->ws_area = tier->area - tier->virt_area;
    //        cout << "renewed WS_AREA: " << tier->ws_area << endl;
  }
  //    exit(1);
}

void calc_tier_WS(void) {
  struct TIER *tier = NULL;

  for(int i = 0; i < numLayer; i++) {
    tier = &tier_st[i];
    tier->ws_area = tier->area - tier->virt_area - tier->term_area;
  }
}

void pre_mac_tier(void) {
  int z = 0;
  struct TIER *tier = NULL;

  for(z = 0; z < numLayer; z++) {
    tier = &tier_st[z];
    tier->mac_cnt = 0;

    if(placementMacroCNT > 0)
      tier->mac_st =
          (struct MODULE **)malloc(sizeof(struct MODULE *) * placementMacroCNT);
    else
      tier->mac_st = NULL;
    tier->temp_mac_area = 0;
  }
}

void post_mac_tier(void) {
  int z = 0;
  prec bin_term_ovlp_area = 0;
  prec tot_term_area = 0;
  struct MODULE *mac = NULL;
  struct FPOS pmin = zeroFPoint;
  struct FPOS pmax = zeroFPoint;
  struct POS bin_pmin = zeroPoint;
  struct POS bin_pmax = zeroPoint;
  struct BIN *binp = NULL;
  struct PLACE *pl = NULL;
  struct TIER *tier = NULL;
  struct RECT rect;
  struct POS p = zeroPoint;

  for(int i = 0; i < macro_cnt; i++) {
    mac = macro_st[i];
    z = mac->tier;
    tier = &tier_st[z];
    tier->mac_st[tier->mac_cnt++] = mac;
    tier->term_area += mac->area;

    pmin = mac->pmin;
    pmax = mac->pmax;

    for(int j = 0; j < place_st_cnt; j++) {
      pl = &place_st[j];

      get_common_rect(pmin, pmax, pl->org, pl->end, &rect.pmin, &rect.pmax);

      if(rect.pmin.x < 0.0 || rect.pmin.y < 0.0 || rect.pmax.x < 0.0 ||
         rect.pmax.y < 0.0)
        continue;

      bin_pmin = get_bin_pt_from_point(rect.pmin);
      bin_pmax = get_bin_pt_from_point(rect.pmax);

      p.Set(-1);

      while(idx_in_bin_rect(&p, bin_pmin, bin_pmax)) {
        binp = get_bin_from_idx(p);

        bin_term_ovlp_area =
            get_common_area(rect.pmin, rect.pmax, binp->pmin, binp->pmax);

        //              binp->term_area2 += bin_term_ovlp_area ;
        binp->term_area += bin_term_ovlp_area * global_macro_area_scale;
      }
    }
  }

  for(int i = 0; i < numLayer; i++) {
    tier = &tier_st[i];
    tot_term_area += tier->term_area;
    if(tier->mac_cnt > 0) {
      tier->mac_st = (MODULE **)realloc(
          tier->mac_st, sizeof(struct MODULE *) * tier->mac_cnt);
    }
    else if(tier->mac_st) {
      free(tier->mac_st);
      tier->mac_st = NULL;
    }

    tier->ws_area = tier->area - tier->virt_area - tier->term_area;
  }
  printf("tot_term_area before tier_assign is %.6lf\n", tot_term_area);
}
