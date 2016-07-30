// Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details
// Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

#ifndef _CULTURE_H
#define _CULTURE_H

class Culture: {
public:
  Culture() : name("foo") {};

  void Init();

  // // Cultures, with weights. This is stolen from Factions.h
  // typedef std::pair<Polit::CultureType, Sint32> CultureWeight;
  // typedef std::vector<CultureWeight>            CultureWeightVec;
  // typedef CultureWeightVec::const_iterator      CultureWeightIterator;

  // CultureWeightVec                              culturetype_weights;
  // Sint32                                        gulturetype_weights_total;

  Uint32 idx;                   // culture index
  std::string name;             // name of culture. (can this be localized?)

};


#endif /* _CULTURE_H */
