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

#import <OpenEmuBase/OERingBuffer.h>

#import "HiganGameCore.h"
#import "HiganInterface.h"
#import "OESNESSystemResponderClient.h"
#import "OEGBASystemResponderClient.h"
#import "OEGBSystemResponderClient.h"
#import "OENESSystemResponderClient.h"

#include <nall/stream.hpp>
#include <nall/file.hpp>

#include "ananke/heuristics/famicom.hpp"
#include "ananke/heuristics/game-boy-advance.hpp"
#include "ananke/heuristics/game-boy.hpp"
#include "ananke/heuristics/super-famicom.hpp"

@interface HiganGameCore () <OESNESSystemResponderClient, OEGBASystemResponderClient, OEGBSystemResponderClient, OENESSystemResponderClient>
{
    Interface *_interface;
}
@end

@implementation HiganGameCore

- (void)dealloc
{
    delete _interface;
}

#pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path
{
    _interface = new Interface;

    _interface->bundlePath  = [[[[self owner] bundle] resourcePath] UTF8String];
    _interface->supportPath = [[self supportDirectoryPath] UTF8String];
    _interface->biosPath    = [[self biosDirectoryPath] UTF8String];

    vector<uint8_t> buffer  = file::read([path UTF8String]);
    string romName          = [[path lastPathComponent] UTF8String];
    unsigned systemID;

    if([[self systemIdentifier] isEqualToString:@"openemu.system.snes"])
    {
        systemID = SuperFamicom::ID::SuperFamicom;
        _interface->activeSystem = OESuperFamicomSystem;
        _interface->loadMedia(romName, "Super Famicom", _interface->activeSystem, systemID);

        if((buffer.size() & 0x7fff) == 512) buffer.remove(0, 512);  //strip copier header, if present

        SuperFamicomCartridge manifest(buffer.data(), buffer.size());

        file::write({_interface->path(systemID), "manifest.bml"}, manifest.markup);

        if(!manifest.markup.find("spc7110"))
            file::write({_interface->path(systemID), "program.rom"}, buffer.data(), manifest.rom_size);
        else
        {
            file::write({_interface->path(systemID), "program.rom"}, buffer.data(), 0x100000);
            file::write({_interface->path(systemID), "data.rom"}, buffer.data() + 0x100000, manifest.rom_size - 0x100000);
        }
    }
    else if([[self systemIdentifier] isEqualToString:@"openemu.system.gba"])
    {
        systemID = GameBoyAdvance::ID::GameBoyAdvance;
        _interface->activeSystem = OEGameBoyAdvanceSystem;
        _interface->loadMedia(romName, "Game Boy Advance", _interface->activeSystem, systemID);

        GameBoyAdvanceCartridge manifest(buffer.data(), buffer.size());

        file::write({_interface->path(systemID), "manifest.bml"}, manifest.markup);
        file::write({_interface->path(systemID), "program.rom"}, buffer);
    }
    else if([[self systemIdentifier] isEqualToString:@"openemu.system.gb"])
    {
        GameBoyCartridge manifest(buffer.data(), buffer.size());
        string systemName = "Game Boy";
        systemID = GameBoy::ID::GameBoy;
        _interface->activeSystem = OEGameBoySystem;

        if(manifest.info.cgb || manifest.info.cgbonly)
        {
            systemID = GameBoy::ID::GameBoyColor;
            systemName = "Game Boy Color";
        }

        _interface->loadMedia(romName, systemName, _interface->activeSystem, systemID);

        file::write({_interface->path(systemID), "manifest.bml"}, manifest.markup);
        file::write({_interface->path(systemID), "program.rom"}, buffer);

        string sgbRomPath = {_interface->biosPath, "/Super Game Boy (World).sfc"};
        string sgbBootRomPath = {_interface->biosPath, "/sgb.boot.rom"};
        bool sgbAvailable = file::exists(sgbRomPath) && file::exists(sgbBootRomPath);
        
        // Check for Super Game Boy header
        if(sgbAvailable && (buffer[0x0146] & 0x03) == 0x03)
        {
            buffer = file::read(sgbRomPath);
            systemID = SuperFamicom::ID::SuperFamicom;
            systemName = "Super Famicom";
            _interface->activeSystem = OESuperFamicomSystem;

            SuperFamicomCartridge sgbManifest(buffer.data(), buffer.size());
            _interface->loadMedia("Super Game Boy (World).sfc", systemName, _interface->activeSystem, systemID);

            file::write({_interface->path(systemID), "manifest.bml"}, sgbManifest.markup);
            file::write({_interface->path(systemID), "program.rom"}, buffer);
            file::copy(sgbBootRomPath, {_interface->path(systemID), "sgb.boot.rom"});
        }
    }
    else if([[self systemIdentifier] isEqualToString:@"openemu.system.nes"])
    {
        systemID = Famicom::ID::Famicom;
        _interface->activeSystem = OEFamicomSystem;
        _interface->loadMedia(romName, "Famicom", _interface->activeSystem, systemID);

        FamicomCartridge manifest(buffer.data(), buffer.size());

        file::write({_interface->path(systemID), "manifest.bml"}, manifest.markup);
        file::write({_interface->path(systemID), "program.rom"}, buffer.data() + 16, manifest.prgrom);
        if(manifest.chrrom > 0)
            file::write({_interface->path(systemID), "character.rom"}, buffer.data() + 16 + manifest.prgrom, manifest.chrrom);
    }

    NSLog(@"Higan: Loading game");

    _interface->load(systemID);

    return YES;
}

- (void)executeFrame
{
    [self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
    _interface->run();

    signed samples[2];
    while(_interface->resampler.pending())
    {
        _interface->resampler.read(samples);
        [[self ringBufferAtIndex:0] write:&samples[0] maxLength:2];
        [[self ringBufferAtIndex:0] write:&samples[1] maxLength:2];
    }
}

- (void)resetEmulation
{
    _interface->active->reset();
}

- (void)stopEmulation
{
    _interface->active->save();

    // Clean-up
    for(auto &path : _interface->pathname)
    {
        file::remove({path, "manifest.bml"});
        file::remove({path, "program.rom"});
        file::remove({path, "data.rom"});
        file::remove({path, "sgb.boot.rom"});
        file::remove({path, "character.rom"});

        lstring contents = directory::contents(path);
        if(contents.empty())
            directory::remove(path);
    }

    [super stopEmulation];
}

#pragma mark - Video

- (OEIntSize)aspectSize
{
    switch(_interface->activeSystem)
    {
        case OEGameBoyAdvanceSystem:
            return OEIntSizeMake(3, 2);
        case OEGameBoySystem:
            return OEIntSizeMake(10, 9);
        default:
            return OEIntSizeMake(4, 3);
    }
}

- (OEIntRect)screenRect
{
    return OEIntRectMake(0, 0, _interface->width, _interface->height);
}

- (OEIntSize)bufferSize
{
    return OEIntSizeMake(512, 480);
}

- (const void *)videoBuffer
{
    return _interface->videoBuffer;
}

- (GLenum)pixelFormat
{
    return GL_BGRA;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_INT_8_8_8_8_REV;
}

- (GLenum)internalPixelFormat
{
    return GL_RGB8;
}

- (NSTimeInterval)frameInterval
{
    return _interface->active->videoFrequency();
}

#pragma mark - Audio

- (NSUInteger)channelCount
{
    return 2;
}

- (double)audioSampleRate
{
    return 44100;
}

#pragma mark - Save State

- (BOOL)saveStateToFileAtPath:(NSString *)fileName
{
    serializer state = _interface->active->serialize();

    FILE  *saveStateFile = fopen([fileName UTF8String], "wb");
    size_t bytesWritten  = fwrite(state.data(), sizeof(uint8_t), state.size(), saveStateFile);

    if(bytesWritten != state.size())
    {
        NSLog(@"Couldn't write save state");
        return NO;
    }

    fclose(saveStateFile);
    return YES;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName
{
    NSData *state = [NSData dataWithContentsOfFile:fileName];
    serializer stateToLoad((const uint8_t *)[state bytes], [state length]);

    _interface->active->unserialize(stateToLoad);

    return YES;
}

#pragma mark - Input

static const int inputMapSuperFamicom [] = {4, 5, 6, 7, 8, 0, 9, 1,10, 11, 3, 2};

- (oneway void)didPushSNESButton:(OESNESButton)button forPlayer:(NSUInteger)player
{
    _interface->inputState[player - 1][inputMapSuperFamicom[button]] = 1;
}

- (oneway void)didReleaseSNESButton:(OESNESButton)button forPlayer:(NSUInteger)player
{
    _interface->inputState[player - 1][inputMapSuperFamicom[button]] = 0;
}

static const int inputMapGameBoyAdvance [] = {6, 7, 5, 4, 0, 1, 9, 8, 3, 2};

- (oneway void)didPushGBAButton:(OEGBAButton)button forPlayer:(NSUInteger)player
{
    _interface->inputState[player - 1][inputMapGameBoyAdvance[button]] = 1;
}

- (oneway void)didReleaseGBAButton:(OEGBAButton)button forPlayer:(NSUInteger)player
{
    _interface->inputState[player - 1][inputMapGameBoyAdvance[button]] = 0;
}

static const int inputMapGameBoy [] = {0, 1, 2, 3, 5, 4, 7, 6};
static const int inputMapSuperGameBoy [] = {4, 5, 6, 7, 8, 0, 3, 2};

- (oneway void)didPushGBButton:(OEGBButton)button
{
    if(_interface->activeSystem == OEGameBoySystem)
        _interface->inputState[0][inputMapGameBoy[button]] = 1;
    else
        _interface->inputState[0][inputMapSuperGameBoy[button]] = 1;
}

- (oneway void)didReleaseGBButton:(OEGBButton)button
{
    if(_interface->activeSystem == OEGameBoySystem)
        _interface->inputState[0][inputMapGameBoy[button]] = 0;
    else
        _interface->inputState[0][inputMapSuperGameBoy[button]] = 0;
}

static const int inputMapFamicom [] = {4, 5, 6, 7, 0, 1, 3, 2};

- (oneway void)didPushNESButton:(OENESButton)button forPlayer:(NSUInteger)player
{
    _interface->inputState[player - 1][inputMapFamicom[button]] = 1;
}

- (oneway void)didReleaseNESButton:(OENESButton)button forPlayer:(NSUInteger)player
{
    _interface->inputState[player - 1][inputMapFamicom[button]] = 0;
}

@end
