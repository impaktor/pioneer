// Copyright © 2008-2024 Pioneer Developers. See AUTHORS.txt for details
// Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

#include "GalaxyConfig.h"
#include "FileSystem.h"
#include "core/OS.h"

GalaxyConfig::GalaxyConfig()
{
	// set defaults
	std::map<std::string, std::string> &map = m_map[""];
	map["Lang"] = OS::GetUserLangCode();
	map["GalaxyExploredMin"] = "65";
	map["GalaxyExploredMax"] = "90";

	Read(FileSystem::userFiles, "galaxy.ini");

	// for (auto i = override_.begin(); i != override_.end(); ++i) {
	//	const std::string &key = (*i).first;
	//	const std::string &val = (*i).second;
	//	map[key] = val;
	// }
}
