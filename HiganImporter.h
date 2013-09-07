//
//  HiganImporter.h
//  Higan
//
//  Created by Daniel Nagel on 07.09.13.
//  Copyright (c) 2013 OpenEmu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HiganInterface.h"

void importFamicom(string path, vector<uint8_t> buffer);
void importGameBoy(string path, vector<uint8_t> buffer);
void importGameBoyAdvance(string path, vector<uint8_t> buffer);
void importSuperFamicom(string path, string biosPath, vector<uint8_t> buffer);

void cleanupLibrary(lstring paths);

// Returns 0 for GB games, 1 for CGB/GB games, 2 for CGB exclusive games
unsigned checkGameBoyColorSupport(vector<uint8_t> buffer);