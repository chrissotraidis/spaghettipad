#include "ModCatalog.h"
#include "ship/Context.h"
#include <cassert>
#include <iostream>
#include <map>
#include <algorithm>
std::string root;
std::map<std::string,int> values;
std::string Ship::Context::GetPathRelativeToAppDirectory(const std::string& p, const std::string&) { return root + "/" + p; }
std::string Ship::Context::LocateFileAcrossAppDirs(const std::string& p, const std::string&) { return root + "/" + p; }
int CVarGetInteger(const char* k,int d) { auto i=values.find(k);return i==values.end()?d:i->second; }
void CVarSetInteger(const char* k,int v) {values[k]=v;}
void CVarSave() {}
int main(int argc,char**argv) {
 root=argv[1]; ScanImportedMods(true);
 auto index=[](const std::string& name){const auto& m=GetImportedMods(); for(size_t i=0;i<m.size();++i)if(m[i].filename==name)return i;throw name;};
 const auto hd=index("hd.o2r"),npc=index("roster.o2r"),link=index("link.o2r"),kris=index("kris.o2r"),ralsei=index("ralsei.o2r"),bad=index("broken.zip");
 for (auto name : {"invalid.o2r", "future.o2r", "dependent.o2r"}) { auto i=index(name); assert(!ImportedModBlockReason(i).empty()); assert(!SetImportedModEnabled(i,true)); }
 assert(GetImportedMods()[hd].requested); assert(!GetImportedMods()[npc].requested);
 assert(!ImportedModBlockReason(bad).empty()); assert(!SetImportedModEnabled(bad,true));
 assert(SetImportedModEnabled(npc,true)); assert(!SetImportedModEnabled(link,true));
 assert(!SetImportedModEnabled(kris,true)); assert(!SetImportedModEnabled(ralsei,true));
 auto paths=SelectedImportedModPaths();assert(paths.size()==2&&paths[0].find("hd.o2r")!=std::string::npos);
 MarkImportedModsActive();assert(!ImportedModsNeedRestart());
 assert(SetImportedModEnabled(npc,false));assert(ImportedModsNeedRestart());
 assert(SetImportedModEnabled(link,true)&&SetImportedModEnabled(kris,true)&&SetImportedModEnabled(ralsei,true));
 ScanImportedMods();assert(GetImportedMods()[npc].active&&!GetImportedMods()[npc].requested);
 ScanImportedMods(true);assert(GetImportedMods()[link].requested);assert(!GetImportedMods()[npc].requested);
 assert(!SetImportedModEnabled(npc,true));
 assert(SetImportedModEnabled(hd,false)); ScanImportedMods(true);assert(!GetImportedMods()[hd].requested);
 std::cout<<"Actual catalog: scan, manifests, conflicts, persistence, legacy HD migration and mount order passed.\n";
}
