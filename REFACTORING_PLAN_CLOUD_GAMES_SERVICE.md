# Refactoring Plan: `cloud_games_service_instance.dart`

**File:** `lib/features/games/services/cloud_games_service_instance.dart`  
**Current Size:** 2,646 lines  
**Target:** Split into 4-5 focused services, each <800 lines  
**Priority:** 🔴 **CRITICAL**  
**Estimated Effort:** 2-3 days

---

## Current Structure Analysis

### Responsibilities Identified

1. **Game CRUD Operations** (~400 lines)
   - `createGame()` - Complex slot claiming logic
   - `updateGame()` - Update with notifications
   - `deleteGame()` - Soft delete with cleanup
   - `getGameById()` - Simple fetch

2. **Query Operations** (~600 lines)
   - `getMyGames()` - User's games with caching
   - `getJoinableGames()` - Public games query
   - `getInvitedGamesForCurrentUser()` - Invited games
   - Stream transformers for distinct updates

3. **Player Management** (~300 lines)
   - `joinGame()` - Join with index updates
   - `leaveGame()` - Leave with cleanup
   - Player list management

4. **Invite Management** (~400 lines)
   - `sendGameInvitesToFriends()` - Send invites
   - `acceptGameInvite()` - Accept invite
   - `declineGameInvite()` - Decline invite
   - `getGameInviteStatuses()` - Get all invite statuses
   - `getUserInviteStatusForGame()` - Get single status
   - `_ensurePendingInviteIndexForUser()` - Index management

5. **Index Management** (~500 lines)
   - `validateUserGameIndexes()` - Validate consistency
   - `fixSimpleInconsistencies()` - Fix issues
   - `removeFromMyCreated()` - Remove from index
   - `removeFromMyJoined()` - Remove from index

6. **Slot Management** (~300 lines)
   - `getBookedSlots()` - Get booked time slots
   - `_isSlotOccupiedByActiveGame()` - Check availability
   - Slot transaction logic

7. **Validation** (~100 lines)
   - `_validateGameData()` - Game data validation

8. **Cache Management** (~50 lines)
   - `_invalidateCache()` - Invalidate specific cache
   - `invalidateAllCache()` - Invalidate all
   - `clearExpiredCache()` - Clean expired entries

9. **Helper Methods** (~200 lines)
   - `_dateKey()` - Date key formatting
   - `_timeKey()` - Time key formatting
   - `_fieldKeyForGame()` - Field key generation
   - `_fieldKeyFromMap()` - Field key from map
   - `_isSameField()` - Field comparison
   - `_timeSlotsOverlap()` - Slot overlap check
   - `_ensureUserProfile()` - Profile creation
   - `_requireCurrentUserId()` - Auth check

---

## Proposed Refactoring Strategy

### Phase 1: Extract Validation Layer

**Create:** `lib/features/games/services/game_validator.dart`

**Extract:**
- `_validateGameData()` → `GameValidator.validate()`

**Benefits:**
- Reusable validation logic
- Testable in isolation
- Clear separation of concerns

**Estimated Lines:** ~100 lines

---

### Phase 2: Extract Cache Manager

**Create:** `lib/features/games/services/game_cache_manager.dart`

**Extract:**
- `_invalidateCache()` → `GameCacheManager.invalidate()`
- `invalidateAllCache()` → `GameCacheManager.invalidateAll()`
- `clearExpiredCache()` → `GameCacheManager.clearExpired()`
- Cache storage logic

**Benefits:**
- Centralized cache management
- Easy to swap cache implementation
- Testable cache logic

**Estimated Lines:** ~150 lines

---

### Phase 3: Extract Slot Service

**Create:** `lib/features/games/services/game_slot_service.dart`

**Extract:**
- `getBookedSlots()` → `GameSlotService.getBookedSlots()`
- `_isSlotOccupiedByActiveGame()` → `GameSlotService.isSlotOccupied()`
- Slot transaction logic
- Slot key generation helpers (`_dateKey`, `_timeKey`, `_fieldKeyForGame`)

**Dependencies:**
- `FirebaseDatabase`
- `IGamesService` (for querying games)

**Benefits:**
- Focused slot management
- Reusable slot checking
- Clear slot-related operations

**Estimated Lines:** ~400 lines

---

### Phase 4: Extract Invite Service

**Create:** `lib/features/games/services/game_invite_service.dart`

**Extract:**
- `sendGameInvitesToFriends()` → `GameInviteService.sendInvites()`
- `acceptGameInvite()` → `GameInviteService.accept()`
- `declineGameInvite()` → `GameInviteService.decline()`
- `getGameInviteStatuses()` → `GameInviteService.getStatuses()`
- `getUserInviteStatusForGame()` → `GameInviteService.getUserStatus()`
- `_ensurePendingInviteIndexForUser()` → `GameInviteService._ensureIndex()`

**Dependencies:**
- `FirebaseDatabase`
- `FirebaseAuth`
- `IFriendsService` (for friend list)

**Benefits:**
- Focused invite management
- Clear invite operations
- Easier to test invite logic

**Estimated Lines:** ~500 lines

---

### Phase 5: Extract Player Service

**Create:** `lib/features/games/services/game_player_service.dart`

**Extract:**
- `joinGame()` → `GamePlayerService.join()`
- `leaveGame()` → `GamePlayerService.leave()`
- Player list management logic

**Dependencies:**
- `FirebaseDatabase`
- `FirebaseAuth`
- `IGamesService` (for game fetching)

**Benefits:**
- Focused player management
- Clear join/leave operations
- Easier to test player logic

**Estimated Lines:** ~300 lines

---

### Phase 6: Extract Index Service

**Create:** `lib/features/games/services/game_index_service.dart`

**Extract:**
- `validateUserGameIndexes()` → `GameIndexService.validate()`
- `fixSimpleInconsistencies()` → `GameIndexService.fixInconsistencies()`
- `removeFromMyCreated()` → `GameIndexService.removeFromCreated()`
- `removeFromMyJoined()` → `GameIndexService.removeFromJoined()`

**Dependencies:**
- `FirebaseDatabase`
- `FirebaseAuth`

**Benefits:**
- Focused index management
- Clear index operations
- Easier to test index logic

**Estimated Lines:** ~600 lines

---

### Phase 7: Refactor Main Service

**Refactor:** `lib/features/games/services/cloud_games_service_instance.dart`

**Keep:**
- Game CRUD operations (create, update, delete, getById)
- Query operations (getMyGames, getJoinableGames, getInvitedGames)
- Stream transformers
- Core game data management

**Use Extracted Services:**
- `GameValidator` for validation
- `GameCacheManager` for caching
- `GameSlotService` for slot management
- `GameInviteService` for invites
- `GamePlayerService` for player operations
- `GameIndexService` for index operations

**Estimated Lines After Refactoring:** ~800 lines

---

## File Structure After Refactoring

```
lib/features/games/services/
├── games_service.dart                    # Interface (existing)
├── games_service_instance.dart            # Wrapper (existing)
├── cloud_games_service_instance.dart     # Main service (~800 lines)
├── game_validator.dart                   # NEW (~100 lines)
├── game_cache_manager.dart               # NEW (~150 lines)
├── game_slot_service.dart                # NEW (~400 lines)
├── game_invite_service.dart              # NEW (~500 lines)
├── game_player_service.dart               # NEW (~300 lines)
└── game_index_service.dart                # NEW (~600 lines)
```

**Total Lines:** ~2,850 lines (slightly more due to interfaces/imports, but much better organized)

---

## Implementation Order

### Step 1: Extract Validator (Low Risk)
1. Create `GameValidator` class
2. Move validation logic
3. Update `CloudGamesServiceInstance` to use validator
4. Test validation still works

### Step 2: Extract Cache Manager (Low Risk)
1. Create `GameCacheManager` class
2. Move cache logic
3. Update `CloudGamesServiceInstance` to use cache manager
4. Test caching still works

### Step 3: Extract Slot Service (Medium Risk)
1. Create `GameSlotService` class
2. Move slot-related methods
3. Update `CloudGamesServiceInstance` to use slot service
4. Test slot checking and booking still works

### Step 4: Extract Invite Service (Medium Risk)
1. Create `GameInviteService` class
2. Move invite-related methods
3. Update `CloudGamesServiceInstance` to use invite service
4. Test invite operations still work

### Step 5: Extract Player Service (Medium Risk)
1. Create `GamePlayerService` class
2. Move player-related methods
3. Update `CloudGamesServiceInstance` to use player service
4. Test join/leave operations still work

### Step 6: Extract Index Service (High Risk - Complex)
1. Create `GameIndexService` class
2. Move index-related methods
3. Update `CloudGamesServiceInstance` to use index service
4. Test index operations still work

### Step 7: Clean Up Main Service (Low Risk)
1. Remove unused helper methods
2. Update imports
3. Add documentation
4. Final testing

---

## Dependencies Between Services

```
CloudGamesServiceInstance
├── GameValidator (no dependencies)
├── GameCacheManager (no dependencies)
├── GameSlotService
│   └── IGamesService (for querying games)
├── GameInviteService
│   ├── IFriendsService (for friend list)
│   └── IGamesService (for game fetching)
├── GamePlayerService
│   └── IGamesService (for game fetching)
└── GameIndexService (no dependencies)
```

**Note:** To avoid circular dependencies, extracted services should depend on `IGamesService` interface, not `CloudGamesServiceInstance` directly.

---

## Testing Strategy

### Unit Tests
- Test each extracted service in isolation
- Mock dependencies (Firebase, other services)
- Test edge cases and error handling

### Integration Tests
- Test service interactions
- Test end-to-end game operations
- Verify cache invalidation works

### Manual Testing Checklist
- [ ] Create game with slot checking
- [ ] Update game
- [ ] Delete game
- [ ] Join game
- [ ] Leave game
- [ ] Send invites
- [ ] Accept/decline invites
- [ ] Query games (my games, joinable, invited)
- [ ] Index validation and fixes
- [ ] Cache invalidation

---

## Benefits of Refactoring

1. **Maintainability:** Each service has a single, clear responsibility
2. **Testability:** Services can be tested in isolation
3. **Readability:** Smaller files are easier to understand
4. **Reusability:** Services can be reused in other contexts
5. **Parallel Development:** Multiple developers can work on different services
6. **Easier Code Reviews:** Smaller files are easier to review

---

## Risks & Mitigation

### Risk 1: Breaking Changes
**Mitigation:**
- Extract services incrementally
- Maintain interface compatibility
- Comprehensive testing after each extraction

### Risk 2: Circular Dependencies
**Mitigation:**
- Use interfaces (`IGamesService`) instead of concrete classes
- Dependency injection pattern
- Clear dependency graph

### Risk 3: Performance Impact
**Mitigation:**
- Keep service calls efficient
- Avoid unnecessary service instantiations
- Profile performance after refactoring

### Risk 4: Increased Complexity
**Mitigation:**
- Clear documentation for each service
- Well-defined interfaces
- Consistent naming patterns

---

## Success Criteria

✅ **File Size:** Main service <800 lines  
✅ **Service Count:** 4-6 focused services  
✅ **Test Coverage:** All services have unit tests  
✅ **Functionality:** All existing features work  
✅ **Performance:** No performance regression  
✅ **Code Quality:** Improved maintainability score  

---

## Next Steps

1. **Review this plan** with the team
2. **Start with Phase 1** (Validator - lowest risk)
3. **Incremental extraction** - one service at a time
4. **Test thoroughly** after each phase
5. **Update documentation** as services are extracted

---

**Created:** December 2024  
**Status:** Ready for implementation  
**Estimated Completion:** 2-3 days (incremental, can be done over multiple sprints)

