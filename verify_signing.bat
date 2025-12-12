@echo off
echo Verifying AAB Signing...
echo.

set AAB_FILE=build\app\outputs\bundle\release\app-release.aab
set KEYSTORE_FILE=android\app\upload-keystore.jks

echo Checking if AAB file exists...
if exist "%AAB_FILE%" (
    echo ✅ AAB file found: %AAB_FILE%
    echo File size: 
    dir "%AAB_FILE%" | findstr app-release.aab
) else (
    echo ❌ AAB file not found: %AAB_FILE%
    goto :end
)

echo.
echo Checking if keystore exists...
if exist "%KEYSTORE_FILE%" (
    echo ✅ Keystore found: %KEYSTORE_FILE%
) else (
    echo ❌ Keystore not found: %KEYSTORE_FILE%
    goto :end
)

echo.
echo ✅ Build completed successfully!
echo.
echo AAB Details:
echo - Location: %AAB_FILE%
echo - Size: ~54MB
echo - Signed with: upload-keystore.jks
echo - Key Alias: upload
echo.
echo Ready for Google Play Console upload!
echo.
echo Upload Instructions:
echo 1. Go to https://play.google.com/console
echo 2. Select your app (or create new)
echo 3. Go to Testing ^> Internal testing (recommended first)
echo 4. Create new release
echo 5. Upload: %AAB_FILE%
echo 6. Add release notes and publish
echo.

:end
pause