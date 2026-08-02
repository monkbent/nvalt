#import <Cocoa/Cocoa.h>

#import "AttributedPlainText.h"

// AttributedPlainText references GlobalPrefs from unrelated category methods.
// The link tests exercise only addLinkAttributesForRange:, so a class symbol is sufficient.
@interface GlobalPrefs : NSObject
@end
@implementation GlobalPrefs
@end

@interface NSString (LinkDetectionTestEscapes)
- (NSString *)stringWithPercentEscapes;
@end
@implementation NSString (LinkDetectionTestEscapes)
- (NSString *)stringWithPercentEscapes {
    return [self stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
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

static BOOL linkAtSubstring(NSMutableAttributedString *text, NSString *substring,
                            NSString *expectedURLPrefix) {
    NSRange expectedRange = [[text string] rangeOfString:substring];
    if (expectedRange.location == NSNotFound) return fail(@"Missing test substring %@", substring);

    NSRange effectiveRange = NSMakeRange(0, 0);
    NSURL *URL = [text attribute:NSLinkAttributeName atIndex:expectedRange.location
                  effectiveRange:&effectiveRange];
    if (!URL) return fail(@"No link attribute for %@", substring);
    if (!NSEqualRanges(effectiveRange, expectedRange))
        return fail(@"Link range %@ does not match expected %@ for %@",
                    NSStringFromRange(effectiveRange), NSStringFromRange(expectedRange), substring);
    if (![[URL absoluteString] hasPrefix:expectedURLPrefix])
        return fail(@"Unexpected URL %@ for %@", URL, substring);
    return YES;
}

static BOOL validateFullRangeDetection(void) {
    NSString *source = @"Visit https://example.com/path?q=1, email test@example.com, "
                        "Unicode https://example.com/東京 and hidden file:///.file/id=123. "
                        "Open [[Fixture Alpha]].";
    NSMutableAttributedString *text = [[[NSMutableAttributedString alloc] initWithString:source] autorelease];
    [text addAttribute:@"TestSentinel" value:@"preserved" range:NSMakeRange(0, [text length])];
    [text addLinkAttributesForRange:NSMakeRange(0, [text length])];

    BOOL passed = YES;
    passed &= linkAtSubstring(text, @"https://example.com/path?q=1", @"https://example.com/path?q=1");
    passed &= linkAtSubstring(text, @"test@example.com", @"mailto:test@example.com");
    passed &= linkAtSubstring(text, @"https://example.com/東京", @"https://example.com/");
    passed &= linkAtSubstring(text, @"Fixture Alpha", @"nvalt://find/Fixture%20Alpha");

    NSRange hiddenFileRange = [source rangeOfString:@"file:///.file/id=123"];
    if ([text attribute:NSLinkAttributeName atIndex:hiddenFileRange.location effectiveRange:NULL])
        passed &= fail(@"Hidden /.file/ URL was linked");
    if (![[text attribute:@"TestSentinel" atIndex:0 effectiveRange:NULL] isEqual:@"preserved"])
        passed &= fail(@"Existing attributed-text metadata was removed");

    if (passed) printf("PASS full-range links, punctuation, Unicode, email, wiki, and /.file/ filter\n");
    return passed;
}

static BOOL validateIncrementalRangeDetection(void) {
    NSString *source = @"Keep https://first.example unchanged; add https://second.example/path now.";
    NSMutableAttributedString *text = [[[NSMutableAttributedString alloc] initWithString:source] autorelease];
    NSRange changedRange = [source rangeOfString:@"https://second.example/path"];
    [text addLinkAttributesForRange:changedRange];

    NSRange firstRange = [source rangeOfString:@"https://first.example"];
    if ([text attribute:NSLinkAttributeName atIndex:firstRange.location effectiveRange:NULL])
        return fail(@"Incremental scan linked text outside the changed range");
    if (!linkAtSubstring(text, @"https://second.example/path", @"https://second.example/path"))
        return NO;

    printf("PASS incremental link range\n");
    return YES;
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BOOL passed = validateFullRangeDetection();
    passed &= validateIncrementalRangeDetection();
    printf("%s\n", passed ? "PASS link detection suite" : "FAIL link detection suite");
    [pool drain];
    return passed ? 0 : 1;
}
