//
//  HiganImporter.m
//  Higan
//
//  Created by Daniel Nagel on 07.09.13.
//  Copyright (c) 2013 OpenEmu. All rights reserved.
//

#import "HiganImporter.h"

#include <nall/file.hpp>

#include "ananke/heuristics/famicom.hpp"
#include "ananke/heuristics/game-boy-advance.hpp"
#include "ananke/heuristics/game-boy.hpp"
#include "ananke/heuristics/super-famicom.hpp"

void importFamicom(string path, vector<uint8_t> buffer)
{
    FamicomCartridge manifest(buffer.data(), buffer.size());

    file::write({path, "manifest.bml"}, manifest.markup);
    file::write({path, "program.rom"}, buffer.data() + 16, manifest.prgrom);
    
    if(manifest.chrrom > 0)
        file::write({path, "character.rom"}, buffer.data() + 16 + manifest.prgrom, manifest.chrrom);
}

void importGameBoy(string path, vector<uint8_t> buffer)
{
    GameBoyCartridge manifest(buffer.data(), buffer.size());

    file::write({path, "manifest.bml"}, manifest.markup);
    file::write({path, "program.rom"}, buffer);
}

void importGameBoyAdvance(string path, vector<uint8_t> buffer)
{
    GameBoyAdvanceCartridge manifest(buffer.data(), buffer.size());

    file::write({path, "manifest.bml"}, manifest.markup);
    file::write({path, "program.rom"}, buffer);
}

void importSuperFamicom(string path, string biosPath, vector<uint8_t> buffer)
{
    //strip copier header, if present
    if((buffer.size() & 0x7fff) == 512) buffer.remove(0, 512);

    SuperFamicomCartridge manifest(buffer.data(), buffer.size());

    file::write({path, "manifest.bml"}, manifest.markup);
    if(!manifest.markup.find("spc7110"))
    {
        file::write({path, "program.rom"}, buffer.data(), manifest.rom_size);
    }
    else
    {
        file::write({path, "program.rom"}, buffer.data(), 0x100000);
        file::write({path, "data.rom"}, buffer.data() + 0x100000, manifest.rom_size - 0x100000);
    }

    void (^copyFirmwareInternal)(const string &, unsigned, unsigned, unsigned) =
    ^(const string &name, unsigned programSize, unsigned dataSize, unsigned bootSize)
    {
        //firmware appended directly onto .sfc file
        string basename = nall::basename(name);
        if(programSize) file::write({path, basename, ".program.rom"}, buffer.data() + buffer.size() - programSize - dataSize - bootSize, programSize);
        if(dataSize) file::write({path, basename, ".data.rom"}, buffer.data() + buffer.size() - dataSize - bootSize, dataSize);
        if(bootSize) file::write({path, basename, ".boot.rom"}, buffer.data() + buffer.size() - bootSize, bootSize);
    };

    void (^copyFirmwareExternal)(const string &, unsigned, unsigned, unsigned) =
    ^(const string &name, unsigned programSize, unsigned dataSize, unsigned bootSize)
    {
        //firmware stored in external file
        auto buffer = file::read({biosPath, "/", name});
        string basename = nall::basename(name);
        if(programSize) file::write({path, basename, ".program.rom"}, buffer.data(), programSize);
        if(dataSize) file::write({path, basename, ".data.rom"}, buffer.data() + programSize, dataSize);
        if(bootSize) file::write({path, basename, ".boot.rom"}, buffer.data() + programSize + dataSize, bootSize);
    };

    void (^copyFirmware)(const string &, unsigned, unsigned, unsigned) =
    ^(const string &name, unsigned programSize, unsigned dataSize, unsigned bootSize)
    {
        if(manifest.firmware_appended == 1) copyFirmwareInternal(name, programSize, dataSize, bootSize);
        if(manifest.firmware_appended == 0) copyFirmwareExternal(name, programSize, dataSize, bootSize);
    };

    string markup = manifest.markup;
    if(markup.find("dsp1.program.rom" )) copyFirmware("dsp1.rom",  0x001800, 0x000800, 0x000000);
    if(markup.find("dsp1b.program.rom")) copyFirmware("dsp1b.rom", 0x001800, 0x000800, 0x000000);
    if(markup.find("dsp2.program.rom" )) copyFirmware("dsp2.rom",  0x001800, 0x000800, 0x000000);
    if(markup.find("dsp3.program.rom" )) copyFirmware("dsp3.rom",  0x001800, 0x000800, 0x000000);
    if(markup.find("dsp4.program.rom" )) copyFirmware("dsp4.rom",  0x001800, 0x000800, 0x000000);
    if(markup.find("st010.program.rom")) copyFirmware("st010.rom", 0x00c000, 0x001000, 0x000000);
    if(markup.find("st011.program.rom")) copyFirmware("st011.rom", 0x00c000, 0x001000, 0x000000);
    if(markup.find("st018.program.rom")) copyFirmware("st018.rom", 0x020000, 0x008000, 0x000000);
    if(markup.find("cx4.data.rom"     )) copyFirmware("cx4.rom",   0x000000, 0x000c00, 0x000000);
    if(markup.find("sgb.boot.rom"     )) copyFirmware("sgb.rom",   0x000000, 0x000000, 0x000100);
}

void cleanupLibrary(lstring paths)
{
    // Clean-up non-save files
    for(auto &path : paths)
    {
        file::remove({path, "manifest.bml"});
        file::remove({path, "program.rom"});
        file::remove({path, "data.rom"});

        file::remove({path, "dsp1.program.rom"});
        file::remove({path, "dsp1b.program.rom"});
        file::remove({path, "dsp2.program.rom"});
        file::remove({path, "dsp3.program.rom"});
        file::remove({path, "dsp4.program.rom"});
        file::remove({path, "st010.program.rom"});
        file::remove({path, "st011.program.rom"});
        file::remove({path, "st018.program.rom"});
        file::remove({path, "cx4.data.rom"});
        file::remove({path, "sgb.boot.rom"});

        file::remove({path, "character.rom"});

        lstring contents = directory::contents(path);
        if(contents.empty())
            directory::remove(path);
    }
}

unsigned checkGameBoyColorSupport(vector<uint8_t> buffer)
{
    // CGB exclusive
    if((buffer[0x0143] & 0xc0) == 0xc0) return 2;
    // CGB enhanced
    if((buffer[0x0143] & 0x80) == 0x80) return 1;
    // GB vanilla
    return 0;
}
