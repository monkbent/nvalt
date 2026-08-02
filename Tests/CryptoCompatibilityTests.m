#import <Cocoa/Cocoa.h>

#import "NSData_transformations.h"
#include "idea_ossl.h"

static NSString * const TestPassphrase = @"fixture-passphrase";
static const char VerifySalt[] = "Salt for verifying master key in a single iteration";

@interface HarnessNotationPrefs : NSObject <NSCoding> {
@public
    NSUInteger hashIterationCount;
    NSUInteger keyLengthInBits;
    NSData *masterSalt;
    NSData *dataSessionSalt;
    NSData *verifierKey;
}
@end

@implementation HarnessNotationPrefs

- (id)initWithCoder:(NSCoder *)decoder {
    if ((self = [super init])) {
        hashIterationCount = [decoder decodeIntForKey:@"hashIterationCount"];
        keyLengthInBits = [decoder decodeIntForKey:@"keyLengthInBits"];
        masterSalt = [[decoder decodeObjectForKey:@"masterSalt"] retain];
        dataSessionSalt = [[decoder decodeObjectForKey:@"dataSessionSalt"] retain];
        verifierKey = [[decoder decodeObjectForKey:@"verifierKey"] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    (void)coder;
    [NSException raise:NSInternalInconsistencyException format:@"Test decoder is read-only"];
}

- (void)dealloc {
    [masterSalt release];
    [dataSessionSalt release];
    [verifierKey release];
    [super dealloc];
}

@end

@interface HarnessFrozenNotation : NSObject <NSCoding> {
@public
    HarnessNotationPrefs *prefs;
    NSMutableData *notesData;
}
@end

@implementation HarnessFrozenNotation

- (id)initWithCoder:(NSCoder *)decoder {
    if ((self = [super init])) {
        prefs = [[decoder decodeObjectForKey:@"prefs"] retain];
        notesData = [[decoder decodeObjectForKey:@"notesData"] mutableCopy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    (void)coder;
    [NSException raise:NSInternalInconsistencyException format:@"Test decoder is read-only"];
}

- (void)dealloc {
    [prefs release];
    [notesData release];
    [super dealloc];
}

@end

static BOOL fail(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString *message = [[[NSString alloc] initWithFormat:format arguments:arguments] autorelease];
    va_end(arguments);
    fprintf(stderr, "FAIL: %s\n", [message UTF8String]);
    return NO;
}

static uint32_t readBigEndianUInt32(const uint8_t *bytes) {
    uint32_t value;
    memcpy(&value, bytes, sizeof(value));
    return CFSwapInt32BigToHost(value);
}

static BOOL objectContainsString(id object, NSString *needle) {
    if ([object isKindOfClass:[NSString class]])
        return [(NSString *)object rangeOfString:needle].location != NSNotFound;
    if ([object isKindOfClass:[NSArray class]]) {
        for (id child in (NSArray *)object)
            if (objectContainsString(child, needle)) return YES;
    } else if ([object isKindOfClass:[NSDictionary class]]) {
        for (id key in (NSDictionary *)object) {
            if (objectContainsString(key, needle) ||
                objectContainsString([(NSDictionary *)object objectForKey:key], needle)) return YES;
        }
    }
    return NO;
}

static BOOL validateDatabaseFixture(NSString *path, NSUInteger expectedIterations) {
    NSData *archiveData = [NSData dataWithContentsOfFile:path];
    if (!archiveData) return fail(@"Could not read %@", path);

    [NSKeyedUnarchiver setClass:[HarnessFrozenNotation class] forClassName:@"FrozenNotation"];
    [NSKeyedUnarchiver setClass:[HarnessNotationPrefs class] forClassName:@"NotationPrefs"];

    HarnessFrozenNotation *archive = nil;
    @try {
        archive = [NSKeyedUnarchiver unarchiveObjectWithData:archiveData];
    } @catch (NSException *exception) {
        return fail(@"Could not decode outer archive %@: %@", path, exception);
    }
    if (![archive isKindOfClass:[HarnessFrozenNotation class]])
        return fail(@"Unexpected outer archive class in %@", path);
    if (archive->prefs->hashIterationCount != expectedIterations)
        return fail(@"%@ uses %lu iterations, expected %lu", path,
                    (unsigned long)archive->prefs->hashIterationCount,
                    (unsigned long)expectedIterations);
    if (archive->prefs->keyLengthInBits != 256 ||
        [archive->prefs->masterSalt length] != 256 ||
        [archive->prefs->dataSessionSalt length] != 256 ||
        [archive->prefs->verifierKey length] != 32)
        return fail(@"Invalid encryption metadata in %@", path);

    NSData *passwordData = [TestPassphrase dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger keyLength = archive->prefs->keyLengthInBits / 8;
    NSData *masterKey = [passwordData derivedKeyOfLength:(int)keyLength
                                                   salt:archive->prefs->masterSalt
                                             iterations:(int)archive->prefs->hashIterationCount];
    NSData *verifySalt = [NSData dataWithBytes:VerifySalt length:sizeof(VerifySalt)];
    NSData *computedVerifier = [masterKey derivedKeyOfLength:(int)keyLength
                                                       salt:verifySalt
                                                 iterations:1];
    if (![computedVerifier isEqualToData:archive->prefs->verifierKey])
        return fail(@"Passphrase verifier mismatch in %@", path);

    NSData *sessionKey = [masterKey derivedKeyOfLength:(int)keyLength
                                                 salt:archive->prefs->dataSessionSalt
                                           iterations:1];
    NSData *iv = [archive->prefs->dataSessionSalt subdataWithRange:NSMakeRange(0, 16)];
    if (![archive->notesData decryptAESDataWithKey:sessionKey iv:iv])
        return fail(@"AES decryption failed for %@", path);

    NSData *uncompressed = [archive->notesData uncompressedData];
    if (!uncompressed) return fail(@"Decrypted payload did not decompress for %@", path);

    NSError *plistError = nil;
    id innerArchive = [NSPropertyListSerialization propertyListWithData:uncompressed
                                                                 options:NSPropertyListImmutable
                                                                  format:NULL
                                                                   error:&plistError];
    if (!innerArchive)
        return fail(@"Decrypted payload is not a keyed archive for %@: %@", path, plistError);

    NSArray *requiredText = [NSArray arrayWithObjects:@"Fixture Alpha", @"Fixture Beta",
                              @"Café", @"東京", @"📝", nil];
    for (NSString *text in requiredText)
        if (!objectContainsString(innerArchive, text))
            return fail(@"Decrypted payload %@ does not contain '%@'", path, text);

    printf("PASS database: %s (%lu iterations)\n", [path UTF8String],
           (unsigned long)expectedIterations);
    return YES;
}

static BOOL validateBlorFixture(NSString *path) {
    NSData *fileData = [NSData dataWithContentsOfFile:path];
    if ([fileData length] < 24) return fail(@"BLOR fixture is too short: %@", path);

    NSData *passwordData = [TestPassphrase dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSData *passwordDigest = [passwordData SHA1Digest];
    const uint8_t *bytes = [fileData bytes];
    if (memcmp(bytes, [passwordDigest bytes], 20) != 0)
        return fail(@"BLOR password digest mismatch: %@", path);

    uint32_t noteCount = readBigEndianUInt32(bytes + 20);
    if (noteCount != 2) return fail(@"BLOR note count is %u, expected 2", noteCount);

    NSData *keyData = [passwordData BrokenMD5Digest];
    NSArray *expectedTitles = [NSArray arrayWithObjects:@"Legacy Fixture One",
                                @"Legacy Fixture Two – Café 東京", nil];
    NSArray *expectedBodies = [NSArray arrayWithObjects:@"https://example.com/legacy",
                                @"naïve, 東京, emoji 📝", nil];
    NSUInteger offset = 24;

    for (NSUInteger noteIndex = 0; noteIndex < noteCount; noteIndex++) {
        if (offset + 4 > [fileData length]) return fail(@"Truncated BLOR title length");
        uint32_t titleLength = readBigEndianUInt32(bytes + offset);
        offset += 4;
        if (offset + titleLength + 8 > [fileData length]) return fail(@"Truncated BLOR title");

        NSMutableData *titleData = [NSMutableData dataWithBytes:bytes + offset length:titleLength];
        unsigned char titleIV[] = {0x50, 0x7E, 0x4C, 0x17, 0x99, 0x3A, 0x07, 0x01};
        int titleNum = 0;
        IDEA_KEY_SCHEDULE titleSchedule;
        idea_set_encrypt_key([keyData bytes], &titleSchedule);
        idea_cfb64_encrypt([titleData bytes], [titleData mutableBytes], titleLength,
                           &titleSchedule, titleIV, &titleNum, IDEA_DECRYPT);
        NSString *title = [[[NSString alloc] initWithData:titleData
                                                 encoding:NSUnicodeStringEncoding] autorelease];
        offset += titleLength;

        uint32_t bodyBufferLength = readBigEndianUInt32(bytes + offset);
        offset += 4;
        uint32_t bodyLength = readBigEndianUInt32(bytes + offset);
        offset += 4;
        if (bodyLength > bodyBufferLength || offset + bodyBufferLength > [fileData length])
            return fail(@"Invalid BLOR body lengths for note %lu", (unsigned long)noteIndex);

        NSMutableData *bodyData = [NSMutableData dataWithBytes:bytes + offset length:bodyLength];
        unsigned char bodyIV[] = {0x50, 0x7E, 0x4C, 0x17, 0x99, 0x3A, 0x07, 0x01};
        int bodyNum = 0;
        IDEA_KEY_SCHEDULE bodySchedule;
        idea_set_encrypt_key([keyData bytes], &bodySchedule);
        idea_cfb64_encrypt([bodyData bytes], [bodyData mutableBytes], bodyLength,
                           &bodySchedule, bodyIV, &bodyNum, IDEA_DECRYPT);
        NSString *body = [[[NSString alloc] initWithData:bodyData
                                                encoding:NSUnicodeStringEncoding] autorelease];
        offset += bodyBufferLength;

        if (![title isEqualToString:[expectedTitles objectAtIndex:noteIndex]])
            return fail(@"Unexpected BLOR title %lu: %@", (unsigned long)noteIndex, title);
        if ([body rangeOfString:[expectedBodies objectAtIndex:noteIndex]].location == NSNotFound)
            return fail(@"Unexpected BLOR body %lu: %@", (unsigned long)noteIndex, body);
        printf("PASS blor note: %s\n", [title UTF8String]);
    }

    if (offset != [fileData length])
        return fail(@"BLOR parser stopped at %lu of %lu bytes", (unsigned long)offset,
                    (unsigned long)[fileData length]);
    return YES;
}

static BOOL validateAESRoundTrip(void) {
    const uint8_t keyBytes[32] = {
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
        0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f
    };
    const uint8_t ivBytes[16] = {
        0xf0, 0xe1, 0xd2, 0xc3, 0xb4, 0xa5, 0x96, 0x87,
        0x78, 0x69, 0x5a, 0x4b, 0x3c, 0x2d, 0x1e, 0x0f
    };
    NSData *key = [NSData dataWithBytes:keyBytes length:sizeof(keyBytes)];
    NSData *iv = [NSData dataWithBytes:ivBytes length:sizeof(ivBytes)];
    NSData *plaintext = [@"nvALT AES compatibility: Café 東京 📝\n"
                         dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *ciphertext = [[plaintext mutableCopy] autorelease];

    if (![ciphertext encryptAESDataWithKey:key iv:iv]) return fail(@"AES encryption failed");
    if ([ciphertext isEqualToData:plaintext]) return fail(@"AES ciphertext equals plaintext");
    if (![ciphertext decryptAESDataWithKey:key iv:iv]) return fail(@"AES decryption failed");
    if (![ciphertext isEqualToData:plaintext]) return fail(@"AES round-trip changed plaintext");

    printf("PASS AES-256-CBC round trip\n");
    return YES;
}

int main(int argc, const char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (argc != 2) {
        fprintf(stderr, "usage: crypto-compatibility-tests REPOSITORY_ROOT\n");
        return 64;
    }

    NSString *root = [NSString stringWithUTF8String:argv[1]];
    NSString *fixtures = [root stringByAppendingPathComponent:@"Tests/Fixtures/m1"];
    BOOL passed = YES;
    passed &= validateDatabaseFixture(
        [fixtures stringByAppendingPathComponent:@"encrypted/low-iterations/Notes & Settings"], 8000);
    passed &= validateDatabaseFixture(
        [fixtures stringByAppendingPathComponent:@"encrypted/high-iterations/Notes & Settings"], 2558477);
    passed &= validateBlorFixture(
        [fixtures stringByAppendingPathComponent:@"legacy-blor/NotationalDatabase.blor"]);
    passed &= validateAESRoundTrip();

    printf("%s\n", passed ? "PASS crypto compatibility suite" : "FAIL crypto compatibility suite");
    [pool drain];
    return passed ? 0 : 1;
}
