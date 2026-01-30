# Implementation Plan

- [x] 1. Extend AuthenticationService with verification methods





  - Add `confirmSignUp()` method to call AWS Amplify's confirmSignUp
  - Add `resendSignUpCode()` method to call AWS Amplify's resendSignUpCode
  - Implement error handling and mapping for all AWS Cognito exceptions
  - Return appropriate AuthResult for successful verification
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [x] 1.1 Write property test for confirmSignUp AWS invocation


  - **Property 2: AWS Cognito confirmation invocation**
  - **Validates: Requirements 3.1, 7.1**

- [x] 1.2 Write property test for error exception handling


  - **Property 7.3: Error handling throws AuthenticationException**
  - **Validates: Requirements 7.3**

- [x] 2. Create VerificationScreen widget




  - Create new StatefulWidget for email verification
  - Add email parameter passed via constructor
  - Set up TextEditingController for verification code input
  - Initialize state variables (isLoading, isResending, errorMessage)
  - Implement dispose method to clean up controllers
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 8.1, 8.2_

- [x] 3. Implement verification code input field with validation





  - Create TextField with numeric keyboard type
  - Add input formatter to restrict to numeric characters only
  - Add maxLength constraint of 6 characters
  - Implement real-time validation to enable/disable verify button
  - Add listener to update button state on text changes
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [x] 3.1 Write property test for numeric input restriction


  - **Property 7: Numeric input restriction**
  - **Validates: Requirements 2.1, 2.2**

- [x] 3.2 Write property test for button enable state


  - **Property 1: Verification code validation**
  - **Validates: Requirements 2.3, 2.4, 2.5**

- [x] 4. Implement verification submission logic





  - Create `_handleVerification()` method
  - Call AuthenticationService.confirmSignUp() with email and code
  - Show loading indicator during verification
  - Disable verify button while loading
  - Handle successful verification with navigation to document list
  - Handle errors with appropriate error messages
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 4.1 Write property test for navigation after successful verification


  - **Property 3: Navigation after successful verification**
  - **Validates: Requirements 3.2**

- [x] 4.2 Write property test for loading state during verification

  - **Property 8: Loading state during verification**
  - **Validates: Requirements 3.5**

- [x] 5. Implement resend code functionality





  - Create `_handleResendCode()` method
  - Call AuthenticationService.resendSignUpCode() with email
  - Show loading indicator during resend operation
  - Disable resend button while loading
  - Clear verification code input field on success
  - Display success message when code is resent
  - Handle errors with appropriate error messages
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 5.1 Write property test for input field clearing after resend


  - **Property 5: Resend code clears input**
  - **Validates: Requirements 4.3**

- [x] 6. Build VerificationScreen UI layout





  - Add AppBar with back button
  - Add email verification icon
  - Display "Verify Your Email" title
  - Show instructional text with user's email address
  - Add verification code input field
  - Add verify button (styled consistently with other auth screens)
  - Add "Didn't receive the code?" text with resend button
  - Add "Back to Sign In" link
  - Implement error message container with consistent styling
  - Add loading indicators for async operations
  - _Requirements: 1.2, 1.3, 1.4, 8.1, 8.2, 8.3, 8.4_

- [x] 7. Update SignUpScreen to handle verification flow





  - Check AuthResult.needsConfirmation after successful sign-up
  - Navigate to VerificationScreen when confirmation is needed
  - Pass user's email to VerificationScreen
  - Remove old success message and navigation logic for unverified accounts
  - _Requirements: 1.1_

- [x] 7.1 Write property test for sign-up navigation to verification


  - **Property: Sign-up with needsConfirmation navigates to verification**
  - **Validates: Requirements 1.1**

- [x] 8. Update SignInScreen to handle unverified accounts





  - Add try-catch for UserNotConfirmedException during sign-in
  - Navigate to VerificationScreen when exception is caught
  - Pass user's email to VerificationScreen
  - Set fromSignIn flag to true for appropriate messaging
  - Update error message handling
  - _Requirements: 6.1, 6.2, 6.3_

- [x] 8.1 Write property test for unverified sign-in detection


  - **Property 6: Unverified sign-in detection**
  - **Validates: Requirements 6.1, 6.2**

- [x] 9. Implement navigation and state management





  - Use Navigator.pushReplacement for navigation to VerificationScreen from sign-up
  - Use Navigator.push for navigation from sign-in (allow back)
  - Implement back button to navigate to sign-in screen
  - Clear verification state when navigating back
  - Ensure proper navigation to document list after successful verification
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 9.1 Write property test for state cleanup on navigation back


  - **Property: Navigation back clears verification state**
  - **Validates: Requirements 5.3**

- [x] 10. Add error message mapping and display




  - Create `_getErrorMessage()` method to map AWS errors to user-friendly messages
  - Map CodeMismatchException to "Invalid verification code"
  - Map ExpiredCodeException to "Code has expired" with resend prompt
  - Map LimitExceededException to "Too many attempts"
  - Map UserNotFoundException to "Account not found"
  - Map NotAuthorizedException to "Already verified"
  - Map NetworkException to "Network error"
  - Add generic fallback error message
  - Display errors in styled container matching other auth screens
  - _Requirements: 3.3, 3.4_

- [ ] 11. Checkpoint - Ensure all tests pass




  - Ensure all tests pass, ask the user if questions arise.

- [x] 12. Write integration tests for complete verification flow




  - Test complete sign-up to verification to document list flow
  - Test unverified sign-in to verification flow
  - Test resend code functionality
  - Test error scenarios (invalid code, expired code, network errors)
  - Test navigation back from verification screen
  - _Requirements: All_

- [ ] 13. Write widget tests for VerificationScreen
  - Test email display
  - Test code input field properties
  - Test button states
  - Test error message display
  - Test loading indicators
  - _Requirements: 1.2, 1.3, 1.4, 2.1-2.5, 3.5, 4.5_
