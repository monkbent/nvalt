//
//  SimplenoteEntryDeduplication.h
//  Notation
//

#import <Foundation/Foundation.h>

// Return at most one entry for each Simplenote key while preserving the
// first-seen key order. If a key occurs more than once, retain the entry with
// the greatest version. Entries without a key are retained so their existing
// validation/error path remains observable.
static inline NSArray *SimplenoteEntriesDeduplicatedByKey(NSArray *entries) {
	NSMutableArray *deduplicatedEntries = [NSMutableArray arrayWithCapacity:[entries count]];
	NSMutableDictionary *indexesByKey = [NSMutableDictionary dictionaryWithCapacity:[entries count]];

	for (NSDictionary *entry in entries) {
		NSString *key = [entry objectForKey:@"key"];
		if (![key length]) {
			[deduplicatedEntries addObject:entry];
			continue;
		}

		NSNumber *existingIndex = [indexesByKey objectForKey:key];
		if (!existingIndex) {
			[indexesByKey setObject:[NSNumber numberWithUnsignedInteger:[deduplicatedEntries count]] forKey:key];
			[deduplicatedEntries addObject:entry];
			continue;
		}

		NSUInteger index = [existingIndex unsignedIntegerValue];
		NSDictionary *existingEntry = [deduplicatedEntries objectAtIndex:index];
		if ([[entry objectForKey:@"version"] compare:[existingEntry objectForKey:@"version"]] == NSOrderedDescending) {
			[deduplicatedEntries replaceObjectAtIndex:index withObject:entry];
		}
	}

	return deduplicatedEntries;
}

// Reserve keys for an in-flight collection. A later full or partial pass that
// overlaps an already-reserved key must not start a second collector for it.
static inline NSArray *SimplenoteEntriesToCollectByKey(NSArray *entries, NSMutableSet *reservedKeys) {
	NSArray *deduplicatedEntries = SimplenoteEntriesDeduplicatedByKey(entries);
	NSMutableArray *entriesToCollect = [NSMutableArray arrayWithCapacity:[deduplicatedEntries count]];

	for (NSDictionary *entry in deduplicatedEntries) {
		NSString *key = [entry objectForKey:@"key"];
		if ([key length] && [reservedKeys containsObject:key]) {
			continue;
		}
		[entriesToCollect addObject:entry];
		if ([key length]) [reservedKeys addObject:key];
	}

	return entriesToCollect;
}
