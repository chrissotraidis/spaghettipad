#pragma once
#include <string>
namespace Ship { class Context { public: static std::string GetPathRelativeToAppDirectory(const std::string&, const std::string& = ""); static std::string LocateFileAcrossAppDirs(const std::string&, const std::string& = ""); }; }
