/*
 Copyright (c) 2013, OpenEmu Team


 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <hiro/cocoa/header.hpp>
#include <emulator/emulator.hpp>
#include <nall/dsp.hpp>

#include <fc/interface/interface.hpp>
#include <sfc/interface/interface.hpp>
#include <gb/interface/interface.hpp>
#include <gba/interface/interface.hpp>

typedef enum OESystemIndex : NSUInteger
{
    OESuperFamicomSystem,
    OEGameBoySystem,
    OEGameBoyAdvanceSystem,
    OEFamicomSystem,
    OESystemCount,
    OESystemUnknown = NSNotFound,
} OESystemIndex;

struct Interface : Emulator::Interface::Bind {
    void loadRequest(unsigned id, string name, string type, bool required);
    void loadRequest(unsigned id, string path, bool required);
    void saveRequest(unsigned id, string path);
    uint32_t videoColor(unsigned source, uint16_t alpha, uint16_t red, uint16_t green, uint16_t blue);
    void videoRefresh(const uint32_t* palette, const uint32_t* data, unsigned pitch, unsigned width, unsigned height);
    void audioSample(int16_t lsample, int16_t rsample);
    int16_t inputPoll(unsigned port, unsigned device, unsigned input);
    unsigned dipSettings(const Markup::Node& node);
    string path(unsigned group);
    string server();
    void notify(string text);

    void loadMedia(string path, string systemName, OESystemIndex emulatorIndex, unsigned mediaID);
    void load();
    void run();

    vector<Emulator::Interface*> emulator;
    Emulator::Interface* active = nullptr;
    OESystemIndex activeSystem;
    unsigned mediaID;

    lstring paths;
    lstring gamePaths;
    string supportPath;
    string bundlePath;
    string biosPath;
    BOOL inputState[2][12] = { 0 };
    
    int width, height;
    uint32_t *videoBuffer;
        
    DSP resampler;
    void initializeResampler();

    Interface();
    ~Interface();
};
