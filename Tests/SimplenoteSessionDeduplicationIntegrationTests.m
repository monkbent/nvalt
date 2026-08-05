#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

#import "SimplenoteSession.h"
#import "SimplenoteEntryCollector.h"
#import "NoteObject.h"
#import "GlobalPrefs.h"

static NSMutableArray *capturedCollectionBatches;

static BOOL fail(NSString *format, ...) {
	va_list arguments;
	va_start(arguments, format);
	NSString *message = [[[NSString alloc] initWithFormat:format arguments:arguments] autorelease];
	va_end(arguments);
	fprintf(stderr, "FAIL: %s\n", [message UTF8String]);
	return NO;
}

static NSDictionary *entry(NSString *key, NSInteger version) {
	return [NSDictionary dictionaryWithObjectsAndKeys:
		key, @"key",
		[NSNumber numberWithInteger:version], @"version",
		[NSNumber numberWithDouble:1000.0 + version], @"modify",
		[NSNumber numberWithDouble:900.0], @"create",
		[NSString stringWithFormat:@"%@\nBody version %ld", key, (long)version], @"content",
		[NSArray array], @"tags",
		[NSArray array], @"systemtags",
		nil];
}

@interface SimplenoteEntryCollector (OfflineIntegrationTest)
- (void)nvalt_test_startCollectingWithCallback:(SEL)aSEL collectionDelegate:(id)aDelegate;
@end

@implementation SimplenoteEntryCollector (OfflineIntegrationTest)
- (void)nvalt_test_startCollectingWithCallback:(SEL)aSEL collectionDelegate:(id)aDelegate {
	[capturedCollectionBatches addObject:[NSArray arrayWithArray:[self entriesToCollect]]];
}
@end

@interface GlobalPrefs (OfflineIntegrationTest)
- (NSDictionary *)nvalt_test_noteBodyAttributes;
@end

@implementation GlobalPrefs (OfflineIntegrationTest)
- (NSDictionary *)nvalt_test_noteBodyAttributes {
	return [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:13.0] forKey:NSFontAttributeName];
}
@end

@interface TestExistingNote : NSObject {
	NSDictionary *syncServicesMD;
}
- (id)initWithVersion:(NSInteger)version key:(NSString *)key;
@end

@implementation TestExistingNote
- (id)initWithVersion:(NSInteger)version key:(NSString *)key {
	if ((self = [super init])) {
		NSDictionary *entryMetadata = [NSDictionary dictionaryWithObjectsAndKeys:
			key, @"key", [NSNumber numberWithInteger:version], @"version", nil];
		syncServicesMD = [[NSDictionary alloc] initWithObjectsAndKeys:entryMetadata, SimplenoteServiceName, nil];
	}
	return self;
}
- (NSDictionary *)syncServicesMD { return syncServicesMD; }
- (void)dealloc { [syncServicesMD release]; [super dealloc]; }
@end

@interface TestSyncDelegate : NSObject {
	NSDictionary *notesByKey;
}
- (id)initWithNotesByKey:(NSDictionary *)notes;
@end

@implementation TestSyncDelegate
- (id)initWithNotesByKey:(NSDictionary *)notes {
	if ((self = [super init])) notesByKey = [notes copy];
	return self;
}
- (id)noteForKey:(NSString *)key ofServiceClass:(Class)serviceClass { return [notesByKey objectForKey:key]; }
- (void)syncSessionProgressStarted:(id)session {}
- (NSInteger)currentNoteStorageFormat { return 0; }
- (NSString *)uniqueFilenameForTitle:(NSString *)title fromNote:(id)note { return title; }
- (CGFloat)titleColumnWidth { return 400.0; }
- (void)dealloc { [notesByKey release]; [super dealloc]; }
@end

@interface TestSimplenoteSession : SimplenoteSession {
	NSMutableArray *changedBatches;
	NSMutableArray *metadataUpdateKeys;
}
- (NSArray *)changedBatches;
- (NSArray *)metadataUpdateKeys;
@end

@implementation TestSimplenoteSession
- (id)init {
	if ((self = [super initWithUsername:@"offline@example.invalid" andPassword:@"unused"])) {
		simperiumToken = [@"offline-test-token" retain];
		changedBatches = [[NSMutableArray alloc] init];
		metadataUpdateKeys = [[NSMutableArray alloc] init];
	}
	return self;
}
- (void)startCollectingChangedNotesWithEntries:(NSArray *)entries {
	[changedBatches addObject:[NSArray arrayWithArray:entries]];
}
- (void)applyMetadataUpdatesToNote:(id)note localEntry:(NSDictionary *)localEntry remoteEntry:(NSDictionary *)remoteEntry {
	[metadataUpdateKeys addObject:[remoteEntry objectForKey:@"key"]];
}
- (NSArray *)changedBatches { return changedBatches; }
- (NSArray *)metadataUpdateKeys { return metadataUpdateKeys; }
- (void)dealloc {
	[changedBatches release];
	[metadataUpdateKeys release];
	[super dealloc];
}
@end

static NSDictionary *entryByKey(NSArray *entries, NSString *wantedKey) {
	for (NSDictionary *candidate in entries) {
		if ([[candidate objectForKey:@"key"] isEqualToString:wantedKey]) return candidate;
	}
	return nil;
}

static BOOL validateRealCollectionRouting(void) {
	TestExistingNote *olderLocal = [[[TestExistingNote alloc] initWithVersion:6 key:@"existing-older"] autorelease];
	TestExistingNote *newerLocal = [[[TestExistingNote alloc] initWithVersion:20 key:@"existing-newer"] autorelease];
	TestSyncDelegate *delegate = [[[TestSyncDelegate alloc] initWithNotesByKey:
		[NSDictionary dictionaryWithObjectsAndKeys:olderLocal, @"existing-older", newerLocal, @"existing-newer", nil]] autorelease];
	TestSimplenoteSession *session = [[[TestSimplenoteSession alloc] init] autorelease];
	[session setDelegate:delegate];

	NSArray *fullIndex = [NSArray arrayWithObjects:
		entry(@"twice", 1), entry(@"twice", 7),
		entry(@"five-times", 1), entry(@"five-times", 5), entry(@"five-times", 3),
		entry(@"five-times", 9), entry(@"five-times", 2),
		entry(@"existing-older", 4), entry(@"existing-older", 8),
		entry(@"existing-newer", 6), nil];
	[session startCollectingAddedNotesWithEntries:fullIndex mergingWithNotes:[NSArray array]];

	if ([capturedCollectionBatches count] != 1) return fail(@"full index started %lu collectors", (unsigned long)[capturedCollectionBatches count]);
	NSArray *firstBatch = [capturedCollectionBatches objectAtIndex:0];
	if ([firstBatch count] != 2) return fail(@"full index produced %lu collection candidates instead of 2", (unsigned long)[firstBatch count]);
	if ([[entryByKey(firstBatch, @"twice") objectForKey:@"version"] integerValue] != 7)
		return fail(@"2x duplicate did not retain greatest version");
	if ([[entryByKey(firstBatch, @"five-times") objectForKey:@"version"] integerValue] != 9)
		return fail(@"5x duplicate did not retain greatest version");

	if ([[session changedBatches] count] != 1 || [[[session changedBatches] objectAtIndex:0] count] != 1)
		return fail(@"older existing key did not route exactly once to changed-note update");
	id changedNote = [[[session changedBatches] objectAtIndex:0] objectAtIndex:0];
	if (changedNote != olderLocal)
		return fail(@"existing key did not route its original local object to update");
	if (![[session metadataUpdateKeys] isEqualToArray:[NSArray arrayWithObject:@"existing-newer"]])
		return fail(@"newer existing key did not route to metadata update");

	NSArray *partialIndex = [NSArray arrayWithObjects:
		entry(@"twice", 11), entry(@"five-times", 12),
		entry(@"partial-only", 2), entry(@"partial-only", 6), nil];
	[session startCollectingAddedNotesWithEntries:partialIndex mergingWithNotes:[NSArray array]];
	if ([capturedCollectionBatches count] != 2) return fail(@"partial index did not start its one new collector");
	NSArray *secondBatch = [capturedCollectionBatches objectAtIndex:1];
	if ([secondBatch count] != 1 || ![[[secondBatch objectAtIndex:0] objectForKey:@"key"] isEqualToString:@"partial-only"])
		return fail(@"full/partial overlap started a duplicate collection");
	if ([[[secondBatch objectAtIndex:0] objectForKey:@"version"] integerValue] != 6)
		return fail(@"partial duplicate did not retain greatest version");

	NSArray *createdNotes = [session _notesWithEntries:
		[NSArray arrayWithObjects:[firstBatch objectAtIndex:0], [firstBatch objectAtIndex:1], [secondBatch objectAtIndex:0], nil]];
	if ([createdNotes count] != 3) return fail(@"unique collector candidates produced %lu NoteObjects instead of 3", (unsigned long)[createdNotes count]);
	NSMutableSet *createdKeys = [NSMutableSet set];
	for (NoteObject *note in createdNotes) {
		NSString *key = [[[note syncServicesMD] objectForKey:SimplenoteServiceName] objectForKey:@"key"];
		if (![key length] || [createdKeys containsObject:key]) return fail(@"duplicate or missing key reached NoteObject creation");
		[createdKeys addObject:key];
	}

	printf("PASS real Simplenote collection routing deduplicates full and partial index entries offline\n");
	printf("PASS existing local keys route to update paths and never create second objects\n");
	printf("PASS unique candidates satisfy _notesWithEntries one-object-per-key assertion\n");
	return YES;
}

int main(void) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	capturedCollectionBatches = [[NSMutableArray alloc] init];
	Method original = class_getInstanceMethod([SimplenoteEntryCollector class], @selector(startCollectingWithCallback:collectionDelegate:));
	Method replacement = class_getInstanceMethod([SimplenoteEntryCollector class], @selector(nvalt_test_startCollectingWithCallback:collectionDelegate:));
	method_exchangeImplementations(original, replacement);
	Method bodyAttributes = class_getInstanceMethod([GlobalPrefs class], @selector(noteBodyAttributes));
	Method testBodyAttributes = class_getInstanceMethod([GlobalPrefs class], @selector(nvalt_test_noteBodyAttributes));
	method_exchangeImplementations(bodyAttributes, testBodyAttributes);

	BOOL passed = validateRealCollectionRouting();
	printf("%s\n", passed ? "PASS Simplenote session deduplication integration suite" : "FAIL Simplenote session deduplication integration suite");

	method_exchangeImplementations(original, replacement);
	method_exchangeImplementations(bodyAttributes, testBodyAttributes);
	[capturedCollectionBatches release];
	[pool drain];
	return passed ? 0 : 1;
}
