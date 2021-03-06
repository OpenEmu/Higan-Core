auto Icarus::superFamicomManifest(const string& location) -> string {
  vector<uint8_t> buffer;
  auto files = directory::files(location, "*.rom");
  concatenate(buffer, {location, "program.rom"});
  concatenate(buffer, {location, "data.rom"   });
  for(auto& file : files.match("*.boot.rom"   )) concatenate(buffer, {location, file});
  for(auto& file : files.match("*.program.rom")) concatenate(buffer, {location, file});
  for(auto& file : files.match("*.data.rom"   )) concatenate(buffer, {location, file});
  return superFamicomManifest(buffer, location);
}

auto Icarus::superFamicomManifest(vector<uint8_t>& buffer, const string& location) -> string {
  SuperFamicomCartridge cartridge{buffer.data(), buffer.size()};
  if(auto markup = cartridge.markup) {
    markup.append("\n");
    markup.append("information\n");
    markup.append("  sha256: ", Hash::SHA256(buffer.data(), buffer.size()).digest(), "\n");
    markup.append("  title:  ", prefixname(location), "\n");
    markup.append("  note:   ", "heuristically generated by icarus\n");
    return markup;
  }
  return "";
}

auto Icarus::superFamicomImport(vector<uint8_t>& buffer, const string& location) -> bool {
  auto name = prefixname(location);
  auto source = pathname(location);
  string target{settings.libraryPath, "Super Famicom/", name, ".sfc/"};
//if(directory::exists(target)) return failure("game already exists");

  string markup;
  vector<Markup::Node> roms;
  bool firmwareAppended = true;

  if(settings.useDatabase && !markup) {
    auto digest = Hash::SHA256(buffer.data(), buffer.size()).digest();
    for(auto node : database.superFamicom) {
      if(node.name() != "release") continue;
      if(node["information/sha256"].text() == digest) {
        markup.append(BML::serialize(node["cartridge"]), "\n");
        markup.append(BML::serialize(node["information"]));
        break;
      }
    }
  }

  if(settings.useHeuristics && !markup) {
    SuperFamicomCartridge cartridge{buffer.data(), buffer.size()};
    if(markup = cartridge.markup) {
      firmwareAppended = cartridge.firmware_appended;
      markup.append("\n");
      markup.append("information\n");
      markup.append("  title: ", name, "\n");
      markup.append("  note:  ", "heuristically generated by icarus\n");
    }
  }

  auto document = BML::unserialize(markup);
  superFamicomImportScanManifest(roms, document["cartridge"]);
  for(auto rom : roms) {
    auto name = rom["name"].text();
    auto size = rom["size"].decimal();
    if(name == "program.rom" || name == "data.rom" || firmwareAppended) continue;
    if(file::size({source, name}) != size) return failure({"firmware (", name, ") missing or invalid"});
  }

  if(!markup) return failure("failed to parse ROM image");
  if(!directory::create(target)) return failure("library path unwritable");

  if(settings.createManifests) file::write({target, "manifest.bml"}, markup);
  unsigned offset = (buffer.size() & 0x7fff) == 512 ? 512 : 0;  //skip header if present
  for(auto rom : roms) {
    auto name = rom["name"].text();
    auto size = rom["size"].decimal();
    if(name == "program.rom" || name == "data.rom" || firmwareAppended) {
      if(size > buffer.size() - offset) return failure("ROM image is missing data");
      file::write({target, name}, buffer.data() + offset, size);
      offset += size;
    } else {
      auto firmware = file::read({source, name});
      file::write({target, name}, firmware);
    }
  }
  return success();
}

auto Icarus::superFamicomImportScanManifest(vector<Markup::Node>& roms, Markup::Node node) -> void {
  if(node.name() == "rom") roms.append(node);
  for(auto leaf : node) superFamicomImportScanManifest(roms, leaf);
}
