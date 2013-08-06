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

#include <sfc/interface/interface.hpp>

@interface HiganGameCore () <OESNESSystemResponderClient>
{
    Interface *_interface;
    Emulator::Interface *_emulator;
}
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

    NSLog(@"Higan: Loading game");

    _interface = new Interface;
    _emulator  = new SuperFamicom::Interface;
    
    _interface->core = self;
    _interface->emulator = _emulator;

    _emulator->bind = _interface;
    _emulator->load(SuperFamicom::ID::SuperFamicom);

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

#pragma mark - Video

- (OEIntSize)aspectSize
{
    return OEIntSizeMake(8, 7);
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

- (oneway void)didPushSNESButton:(OESNESButton)button forPlayer:(NSUInteger)player
{
    _interface->inputState[player - 1][button] = 1;
}

- (oneway void)didReleaseSNESButton:(OESNESButton)button forPlayer:(NSUInteger)player
{
    _interface->inputState[player - 1][button] = 0;
}

@end
