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
#import <OpenGL/gl.h>

#import "HiganGameCore.h"
#import "HiganInterface.h"
#import "HiganImporter.h"

#import "OESNESSystemResponderClient.h"
#import "OEGBASystemResponderClient.h"
#import "OEGBSystemResponderClient.h"
#import "OENESSystemResponderClient.h"

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

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error
{
    _interface = new Interface;

    _interface->bundlePath  = [[[[self owner] bundle] resourcePath] UTF8String];
    _interface->supportPath = [[self supportDirectoryPath] UTF8String];

    vector<uint8_t> buffer  = file::read([path UTF8String]);
    string romName          = [[path lastPathComponent] UTF8String];
    string biosPath         = [[self biosDirectoryPath] UTF8String];

    if([[self systemIdentifier] isEqualToString:@"openemu.system.snes"])
    {
        _interface->loadMedia(romName, "Super Famicom", OESuperFamicomSystem, SuperFamicom::ID::SuperFamicom);
        importSuperFamicom(_interface->path(SuperFamicom::ID::SuperFamicom), biosPath, buffer);
    }
    else if([[self systemIdentifier] isEqualToString:@"openemu.system.gba"])
    {
        string gbaBiosPath = {biosPath, "/bios.rom"};

        if(!file::exists(gbaBiosPath))
            return NO;

        _interface->loadMedia(romName, "Game Boy Advance", OEGameBoyAdvanceSystem, GameBoyAdvance::ID::GameBoyAdvance);
        importGameBoyAdvance(_interface->path(GameBoyAdvance::ID::GameBoyAdvance), buffer);

        file::copy(gbaBiosPath, {_interface->path(0), "bios.rom"});
    }
    else if([[self systemIdentifier] isEqualToString:@"openemu.system.gb"])
    {
        string systemName = "Game Boy";
        unsigned mediaID = GameBoy::ID::GameBoy;

        if(checkGameBoyColorSupport(buffer))
        {
            systemName = "Game Boy Color";
            mediaID = GameBoy::ID::GameBoyColor;
        }

        _interface->loadMedia(romName, systemName, OEGameBoySystem, mediaID);
        importGameBoy(_interface->path(mediaID), buffer);

        /* Super Game Boy support is broken in v094
        string sgbRomPath = {biosPath, "/Super Game Boy (World).sfc"};
        string sgbBootRomPath = {biosPath, "/sgb.rom"};
        bool sgbAvailable = file::exists(sgbRomPath) && file::exists(sgbBootRomPath);
        
        // Check for Super Game Boy header
        if(sgbAvailable && (buffer[0x0146] & 0x03) == 0x03)
        {
            buffer = file::read(sgbRomPath);
            
            _interface->loadMedia("Super Game Boy (World).sfc", "Super Famicom", OESuperFamicomSystem, SuperFamicom::ID::SuperFamicom);
            importSuperFamicom(_interface->path(SuperFamicom::ID::SuperFamicom), biosPath, buffer);
        }
        */
    }
    else if([[self systemIdentifier] isEqualToString:@"openemu.system.nes"])
    {
        _interface->loadMedia(romName, "Famicom", OEFamicomSystem, Famicom::ID::Famicom);
        importFamicom(_interface->path(Famicom::ID::Famicom), buffer);
    }

    NSLog(@"Higan: Loading game");
    _interface->load();

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

    cleanupLibrary(_interface->gamePaths);

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

- (NSData *)serializeStateWithError:(NSError **)outError
{
    serializer state = _interface->active->serialize();
    return [NSData dataWithBytes:state.data() length:state.size()];
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError
{
    const uint8_t *stateBytes = (const uint8_t *)[state bytes];
    unsigned int stateLength = [state length];
    serializer stateToLoad(stateBytes, stateLength);
    
    if(!_interface->active->unserialize(stateToLoad))
    {
        NSError *error = [NSError errorWithDomain:OEGameCoreErrorDomain
                                             code:OEGameCoreCouldNotLoadStateError
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey : @"The save state data could not be read"
                                                    }];
        if(outError)
        {
            *outError = error;
        }
        return NO;
    }
    return YES;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    serializer state = _interface->active->serialize();
    NSData *stateData = [NSData dataWithBytes:state.data() length:state.size()];
    
    __autoreleasing NSError *error = nil;
    BOOL success = [stateData writeToFile:fileName options:NSDataWritingAtomic error:&error];
    
    block(success, success ? nil : error);
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    __autoreleasing NSError *error = nil;
    NSData *state = [NSData dataWithContentsOfFile:fileName options:NSDataReadingMappedIfSafe | NSDataReadingUncached error:&error];
    
    if(state == nil)
    {
        block(NO, error);
        return;
    }
    
    serializer stateToLoad((const uint8_t *)[state bytes], [state length]);
    if(!_interface->active->unserialize(stateToLoad))
    {
        NSError *error = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotLoadStateError userInfo:@{
                                                                                                                         NSLocalizedDescriptionKey : @"The save state data could not be read",
                                                                                                                         NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"Could not read the file state in %@.", fileName]
                                                                                                                         }];
        block(NO, error);
        return;
    }
    
    block(YES, nil);
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

#pragma mark - Cheats

NSMutableDictionary *cheatList = [[NSMutableDictionary alloc] init];

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled
{
    lstring list;
    
    if (enabled)
        [cheatList setValue:@YES forKey:code];
    else
        [cheatList removeObjectForKey:code];
    
    for (id key in cheatList)
    {
        if ([[cheatList valueForKey:key] isEqual:@YES])
            list.append([key UTF8String]);
    }
    
    _interface->active->cheatSet(list);
}

@end
