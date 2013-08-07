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

#import "HiganInterface.h"
#import <OpenEmuBase/OERingBuffer.h>

#include "ananke/heuristics/super-famicom.hpp"
#include "ananke/heuristics/game-boy-advance.hpp"

#include <nall/stream.hpp>

#include <sfc/interface/interface.hpp>

void Interface::loadRequest(unsigned id, string name, string type)
{
    NSLog(@"loadRequest(unsigned id, string name, string type) not implemented");
}

void Interface::loadRequest(unsigned id, string path)
{
    NSLog(@"Loading file \"%s\"", path.data());

    if(path.equals("manifest.bml"))
    {
        NSData *rom = [NSData dataWithContentsOfFile:[[core romPath] stringByStandardizingPath]];
        string markup;
        if([[[core romPath] pathExtension] isEqualToString:@"gba"])
            markup = GameBoyAdvanceCartridge((const uint8_t *)[rom bytes], [rom length]).markup;
        else
            markup = SuperFamicomCartridge((const uint8_t *)[rom bytes], [rom length]).markup;
        memorystream stream((const uint8_t *)markup.data(), markup.size());
        return emulator->load(id, stream);
    }
    else if(path.equals("program.rom"))
    {
        mmapstream stream([[core romPath] UTF8String]);
        return emulator->load(id, stream);
    }

    for(auto& prefix : paths)
    {
        string filePath = {prefix, path};
        if(file::exists(filePath))
        {
            mmapstream stream(filePath);
            return emulator->load(id, stream);
        }
    }

    NSLog(@"Higan: Wasn't able to load file \"%s\"", path.data());
}

void Interface::saveRequest(unsigned id, string path)
{
    directory::create(paths(2));
    string pathname = {paths(2), path};
    filestream stream(pathname, file::mode::write);
    return emulator->save(id, stream);
}

uint32_t Interface::videoColor(unsigned source, uint16_t r, uint16_t g, uint16_t b)
{
    r >>= 8, g >>= 8, b >>= 8;
    return r << 16 | g << 8 | b << 0;
}

void Interface::videoRefresh(const uint32_t* data, unsigned pitch, unsigned width, unsigned height)
{
    pitch >>= 2;
/*
    // Remove overscan
    data += 8 * pitch;
    if(height == 240)
        height = 224;
    else if(height == 480)
        height = 448;
*/
    core.width  = width;
    core.height = height;

    dispatch_queue_t the_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    dispatch_apply(height, the_queue, ^(size_t y)
    {
        const uint32_t *src = (uint32_t*)data + y * pitch;
        uint32_t *dst = core.buffer + y * 512;

        memcpy(dst, src, sizeof(uint32_t)*width);
    });
}

void Interface::audioSample(int16_t lsample, int16_t rsample)
{
    [[core ringBufferAtIndex:0] write:&lsample maxLength:2];
    [[core ringBufferAtIndex:0] write:&rsample maxLength:2];
}

int16_t Interface::inputPoll(unsigned port, unsigned device, unsigned input)
{
    return inputState[port][input];
}

unsigned Interface::dipSettings(const Markup::Node& node)
{
    NSLog(@"dipSettings(const Markup::Node& node) not implemented");
}

string Interface::path(unsigned group)
{
    if(group == 0)
        // resource path
        return paths(0);
    else
        // support path
        return paths(2);
}

string Interface::server()
{
    return "";
}

void Interface::notify(string text)
{
    NSLog(@"Higan: %s", text.data());
}

