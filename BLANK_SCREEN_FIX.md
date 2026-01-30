# Blank Screen After Sign-In Fix

## Problem
After uninstalling and reinstalling the app, users who sign in are navigated to a blank screen instead of the document list.

## Root Cause
The `SignInScreen` was calling `Navigator.pop(context, true)` after successful sign-in. This worked when users navigated TO the sign-in screen from the document list, but failed when the sign-in screen was the root screen (after fresh install).

**Navigation Flow:**
1. Fresh install → `AuthenticationWrapper` checks auth status
2. User not authenticated → Shows `SignInScreen` directly (not pushed)
3. User signs in → `Navigator.pop()` called
4. No previous screen exists → **Blank screen**

## Solution
Modified `SignInScreen._handleSignIn()` to detect the navigation context:

- **If `Navigator.canPop(context)` is true:** User navigated from another screen → use `Navigator.pop()`
- **If `Navigator.canPop(context)` is false:** Sign-in screen is root → use `Navigator.pushReplacement()` to navigate to document list

## Changes Made
- Updated `lib/screens/sign_in_screen.dart`:
  - Added import for `NewDocumentListScreen`
  - Modified `_handleSignIn()` to check navigation context
  - Added conditional navigation logic

## Testing
After this fix:
1. Fresh install → Sign in → Should navigate to document list ✓
2. From document list → Settings → Sign out → Sign in → Should return to document list ✓
3. From document list → Sign in (when already signed in) → Should return to document list ✓
