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

#import "HiganGameCore.h"
#import "HiganInterface.h"
#import "OESNESSystemResponderClient.h"
#import "OEGBASystemResponderClient.h"

#include <sfc/interface/interface.hpp>
#include <gba/interface/interface.hpp>

typedef enum OERunningSystem : NSUInteger
{
    OESuperFamicomSystem,
    OEGameBoyAdvanceSystem,
    OESystemCount,
    OESystemUnknown = NSNotFound,
} OERunningSystem;

@interface HiganGameCore () <OESNESSystemResponderClient, OEGBASystemResponderClient>
{
    Interface *_interface;
    Emulator::Interface *_emulator;
}
@property OERunningSystem runningSystem;
@end

@implementation HiganGameCore

- (id)init
{
    self = [super init];

    if(self != nil)
    {
        _buffer = new uint32_t[512 * 480];
    }

    return self;
}

- (void)dealloc
{
    delete [] _buffer;
    delete _interface;
}

#pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path
{
    _romPath = [path copy];

    NSString *suffix;
    unsigned id;

    if([[self systemIdentifier] isEqualToString:@"openemu.system.snes"])
    {
        suffix = @"Super Famicom.sys";
        _emulator  = new SuperFamicom::Interface;
        id = SuperFamicom::ID::ROM;
        _runningSystem = OESuperFamicomSystem;
    }
    else if([[self systemIdentifier] isEqualToString:@"openemu.system.gba"])
    {
        suffix = @"Game Boy Advance.sys";
        _emulator  = new GameBoyAdvance::Interface;
        id = GameBoyAdvance::ID::ROM;
        _runningSystem = OEGameBoyAdvanceSystem;
    }
    else
    {
        return NO;
    }
    
    NSString *resourceDirectory = [[[[self owner] bundle] resourcePath] stringByAppendingPathComponent:suffix];
    NSString *supportDirectory = [[self supportDirectoryPath] stringByAppendingFormat:@"/%@/%@", suffix, [path lastPathComponent]];

    NSLog(@"Higan: Loading game");

    _interface = new Interface;
    
    _interface->core = self;
    _interface->emulator = _emulator;
    
    _interface->paths.append([resourceDirectory UTF8String]);
    _interface->paths.append([[self biosDirectoryPath] UTF8String]);
    _interface->paths.append([supportDirectory UTF8String]);

    for(auto& path : _interface->paths) path.append("/");

    _emulator->bind = _interface;
    _emulator->load(id);

    if(!_emulator->loaded())
    {
        NSLog(@"Higan: ROM did not load correctly");
        return NO;
    }

    _emulator->power();
    _emulator->paletteUpdate();

    _emulator->run();

    return YES;
}

- (void)executeFrame
{
    [self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
    _emulator->run();
}

- (void)resetEmulation
{
    _emulator->reset();
}

- (void)stopEmulation
{
    _emulator->save();

    [super stopEmulation];
}

#pragma mark - Video

- (OEIntSize)aspectSize
{
    if(_runningSystem == OESuperFamicomSystem)
        return OEIntSizeMake(8, 7);
    else
        return OEIntSizeMake(3, 2);
}

- (OEIntRect)screenRect
{
    return OEIntRectMake(0, 0, _width, _height);
}

- (OEIntSize)bufferSize
{
    return OEIntSizeMake(512, 480);
}

- (const void *)videoBuffer
{
    return _buffer;
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
    return _emulator->videoFrequency();
}

#pragma mark - Audio

- (NSUInteger)channelCount
{
    return 2;
}

- (double)audioSampleRate
{
    return _emulator->audioFrequency();
}

#pragma mark - Save State

- (BOOL)saveStateToFileAtPath:(NSString *)fileName
{
    serializer state = _emulator->serialize();

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

    _emulator->unserialize(stateToLoad);

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

@end
