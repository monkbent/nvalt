#import <Foundation/Foundation.h>

#import "SimplenoteEntryDeduplication.h"

static BOOL fail(NSString *format, ...) {
	va_list arguments;
	va_start(arguments, format);
	NSString *message = [[[NSString alloc] initWithFormat:format arguments:arguments] autorelease];
	va_end(arguments);
	fprintf(stderr, "FAIL: %s\n", [message UTF8String]);
	return NO;
}

static NSDictionary *entry(NSString *key, NSInteger version, NSString *title) {
	return [NSDictionary dictionaryWithObjectsAndKeys:
		key, @"key",
		[NSNumber numberWithInteger:version], @"version",
		title, @"content",
		nil];
}

static BOOL validateRepeatedKeys(void) {
	NSArray *twice = [NSArray arrayWithObjects:
		entry(@"twice", 3, @"Repeated"),
		entry(@"twice", 1, @"Repeated"),
		nil];
	NSArray *twiceResult = SimplenoteEntriesDeduplicatedByKey(twice);
	if ([twiceResult count] != 1) return fail(@"2x key produced %lu entries", (unsigned long)[twiceResult count]);
	if ([[[twiceResult objectAtIndex:0] objectForKey:@"version"] integerValue] != 3)
		return fail(@"2x key did not retain greatest version");

	NSMutableArray *fiveTimes = [NSMutableArray array];
	NSArray *versions = [NSArray arrayWithObjects:@4, @1, @5, @3, @2, nil];
	for (NSNumber *versionNumber in versions) {
		NSInteger version = [versionNumber integerValue];
		[fiveTimes addObject:entry(@"five-times", version, @"Repeated Five Times")];
	}
	NSArray *fiveResult = SimplenoteEntriesDeduplicatedByKey(fiveTimes);
	if ([fiveResult count] != 1) return fail(@"5x key produced %lu entries", (unsigned long)[fiveResult count]);
	if ([[[fiveResult objectAtIndex:0] objectForKey:@"version"] integerValue] != 5)
		return fail(@"5x key did not retain greatest version");

	printf("PASS repeated keys at 2x and 5x retain one greatest-version entry\n");
	return YES;
}

static BOOL validateDistinctSameTitleKeys(void) {
	NSArray *entries = [NSArray arrayWithObjects:
		entry(@"same-title-a", 4, @"Shared Title\nFirst body"),
		entry(@"same-title-b", 7, @"Shared Title\nSecond body"),
		nil];
	NSArray *result = SimplenoteEntriesDeduplicatedByKey(entries);
	if ([result count] != 2) return fail(@"distinct same-title keys were collapsed");
	if (![[[result objectAtIndex:0] objectForKey:@"key"] isEqualToString:@"same-title-a"] ||
		![[[result objectAtIndex:1] objectForKey:@"key"] isEqualToString:@"same-title-b"])
		return fail(@"distinct-key ordering changed");

	printf("PASS distinct same-title notes survive key-only deduplication\n");
	return YES;
}

static BOOL validateFullPartialOverlapAndExistingMatch(void) {
	NSMutableSet *reservedKeys = [NSMutableSet setWithObject:@"existing-local-key"];
	NSArray *fullPass = [NSArray arrayWithObjects:
		entry(@"full-a", 1, @"Full A"),
		entry(@"full-a", 2, @"Full A"),
		entry(@"full-b", 1, @"Full B"),
		entry(@"existing-local-key", 9, @"Existing"),
		nil];
	NSArray *fullResult = SimplenoteEntriesToCollectByKey(fullPass, reservedKeys);
	if ([fullResult count] != 2) return fail(@"full pass reserved %lu entries instead of 2", (unsigned long)[fullResult count]);
	if (![reservedKeys containsObject:@"full-a"] || ![reservedKeys containsObject:@"full-b"])
		return fail(@"full-pass keys were not reserved");

	NSArray *partialPass = [NSArray arrayWithObjects:
		entry(@"full-a", 5, @"Full A newer"),
		entry(@"partial-c", 1, @"Partial C"),
		nil];
	NSArray *partialResult = SimplenoteEntriesToCollectByKey(partialPass, reservedKeys);
	if ([partialResult count] != 1 || ![[[partialResult objectAtIndex:0] objectForKey:@"key"] isEqualToString:@"partial-c"])
		return fail(@"full/partial overlap started a duplicate collection");

	printf("PASS full/partial overlap and existing local key cannot start duplicate collection\n");
	return YES;
}

int main(void) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	BOOL passed = validateRepeatedKeys();
	passed &= validateDistinctSameTitleKeys();
	passed &= validateFullPartialOverlapAndExistingMatch();
	printf("%s\n", passed ? "PASS Simplenote entry deduplication suite" : "FAIL Simplenote entry deduplication suite");
	[pool drain];
	return passed ? 0 : 1;
}
