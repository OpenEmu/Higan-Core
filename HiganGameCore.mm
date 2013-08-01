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
#import "OESNESSystemResponderClient.h"
#import "HiganInterface.h"

#include <sfc/interface/interface.hpp>
#include <nall/stream/mmap.hpp>

@interface HiganGameCore () <OESNESSystemResponderClient>
{
    Interface *_interface;
}

@end

@implementation HiganGameCore

- (id)init
{
    self = [super init];

    if(self != nil)
    {
        _buffer = new uint32_t[512 * 480];
        //_buffer = (uint32_t *)malloc(512 * 480 * sizeof(uint32_t));
        
        //current = self;
    }

    return self;
}

- (void)dealloc
{
    delete [] _buffer;
    delete _interface;
}

- (BOOL)loadFileAtPath:(NSString *)path
{
    _romPath = [path copy];

    _interface = new Interface;
    _emulator  = new SuperFamicom::Interface;
    _interface->core = self;

    _emulator->bind = _interface;
    //_interface->audioCallback = audioCallback;


    //mmapstream stream([path UTF8String]);

    //_emulator->load(SuperFamicom::ID::ROM, stream);
    _emulator->load(SuperFamicom::ID::SuperFamicom);
    _emulator->power();

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
    return GL_RGBA;
}

- (NSTimeInterval)frameInterval
{
    return _emulator->videoFrequency();
}

- (NSUInteger)channelCount
{
    return 2;
}

- (double)audioSampleRate
{
    return _emulator->audioFrequency();
}

- (oneway void)didPushSNESButton:(OESNESButton)button forPlayer:(NSUInteger)player
{

}

- (oneway void)didReleaseSNESButton:(OESNESButton)button forPlayer:(NSUInteger)player
{
    
}

@end
