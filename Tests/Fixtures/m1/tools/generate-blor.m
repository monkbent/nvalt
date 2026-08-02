#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

#include "../../../../broken_md5.h"
#include "../../../../idea_ossl.h"

static void appendBigEndianUInt32(NSMutableData *data, uint32_t value) {
    uint32_t bigEndianValue = CFSwapInt32HostToBig(value);
    [data appendBytes:&bigEndianValue length:sizeof(bigEndianValue)];
}

static NSData *legacyPasswordKey(NSData *passwordData) {
    unsigned char digest[16];
    BrokenMD5_CTX context;
    BrokenMD5Init(&context);
    BrokenMD5Update(&context, [passwordData bytes], (unsigned)[passwordData length]);
    BrokenMD5Final(digest, &context);
    return [NSData dataWithBytes:digest length:sizeof(digest)];
}

static NSData *encryptedUTF16Data(NSString *string, NSData *keyData) {
    NSMutableData *data = [[string dataUsingEncoding:NSUnicodeStringEncoding] mutableCopy];
    unsigned char iv[] = {0x50, 0x7E, 0x4C, 0x17, 0x99, 0x3A, 0x07, 0x01};
    int num = 0;
    IDEA_KEY_SCHEDULE schedule;
    idea_set_encrypt_key([keyData bytes], &schedule);
    idea_cfb64_encrypt([data bytes], [data mutableBytes], (long)[data length],
                       &schedule, iv, &num, IDEA_ENCRYPT);
    return [data autorelease];
}

static void appendNote(NSMutableData *blor, NSData *keyData,
                       NSString *title, NSString *body) {
    NSData *titleData = encryptedUTF16Data(title, keyData);
    NSData *bodyData = encryptedUTF16Data(body, keyData);
    appendBigEndianUInt32(blor, (uint32_t)[titleData length]);
    [blor appendData:titleData];
    appendBigEndianUInt32(blor, (uint32_t)[bodyData length]);
    appendBigEndianUInt32(blor, (uint32_t)[bodyData length]);
    [blor appendData:bodyData];
}

int main(int argc, const char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (argc != 2) {
        fprintf(stderr, "usage: generate-blor OUTPUT\n");
        return 64;
    }

    NSString *passphrase = @"fixture-passphrase";
    NSData *passwordData = [passphrase dataUsingEncoding:[NSString defaultCStringEncoding]];
    unsigned char passwordSHA1[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([passwordData bytes], (CC_LONG)[passwordData length], passwordSHA1);

    NSMutableData *blor = [NSMutableData data];
    [blor appendBytes:passwordSHA1 length:sizeof(passwordSHA1)];
    appendBigEndianUInt32(blor, 2);

    NSData *keyData = legacyPasswordKey(passwordData);
    appendNote(blor, keyData, @"Legacy Fixture One",
               @"Legacy BLOR body one.\n\nLink: https://example.com/legacy");
    appendNote(blor, keyData, @"Legacy Fixture Two – Café 東京",
               @"Second legacy note with Unicode: naïve, 東京, emoji 📝.");

    NSString *outputPath = [NSString stringWithUTF8String:argv[1]];
    BOOL wrote = [blor writeToFile:outputPath atomically:YES];
    [pool drain];
    return wrote ? 0 : 1;
}
